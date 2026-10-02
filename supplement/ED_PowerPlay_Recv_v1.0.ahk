#Requires AutoHotkey v2.0
#SingleInstance Force

Persistent()

global PORT := 12345
global WM_SOCKET := 0x8000 + 1
global isBusy := false
global pendingCmd := ""
global macroCancel := false

; 스크립트가 어떤 이유로든 종료될 때 Winsock 자원을 안전하게 해제
OnExit(CleanupSockets)

; ----------------------------------------------------
; 상태 표시용 오버레이 GUI 생성 (화면 중앙 상단)
; ----------------------------------------------------
global overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
overlayGui.BackColor := "000000"
WinSetTransColor("000000 180", overlayGui)

overlayGui.SetFont("s10 bold cLime", "Malgun Gothic")

overlayWidth := 300
overlayHeight := 28
global statusText := overlayGui.Add("Text", "w" . overlayWidth . " h" . overlayHeight . " Center Valign", "● AHK ONLINE")

screenWidth := SysGet(0)
centerX := (screenWidth - overlayWidth) / 2
centerY := 10

overlayGui.Show("x" . centerX . " y" . centerY . " w" . overlayWidth . " h" . overlayHeight . " NoActivate")

; ----------------------------------------------------
; 스크립트 제어 단축키
; ----------------------------------------------------
^+q:: ExitApp() ; Ctrl + Shift + Q : 스크립트 종료
F12:: Reload()  ; F12 : 스크립트 재시작

; ----------------------------------------------------
; SAPI TTS (음성 안내) 초기화
; ----------------------------------------------------
global tts := ComObject("SAPI.SpVoice")
global SSPF_ASYNC := 1

voices := tts.GetVoices()
Loop voices.Count {
    voice := voices.Item(A_Index - 1)
    if InStr(voice.GetDescription(), "Microsoft Zira Desktop") {
        tts.Voice := voice
        break
    }
}

; ----------------------------------------------------
; 입력 딜레이
; ----------------------------------------------------
SetKeyDelay(100, 100)
SetMouseDelay(100)

; ----------------------------------------------------
; Winsock 초기화
; ----------------------------------------------------
global WSAData := Buffer(400)
DllCall("Ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", WSAData)

global listenSocket := DllCall("Ws2_32\socket", "Int", 2, "Int", 1, "Int", 6, "Ptr")

opt := Buffer(4)
NumPut("Int", 1, opt, 0)
DllCall("Ws2_32\setsockopt", "Ptr", listenSocket, "Int", 0xFFFF, "Int", 0x0004, "Ptr", opt, "Int", 4)

sockaddr := Buffer(16, 0)
NumPut("UShort", 2, sockaddr, 0)
NumPut("UShort", DllCall("Ws2_32\htons", "UShort", PORT, "UShort"), sockaddr, 2)
NumPut("UInt", 0, sockaddr, 4)

DllCall("Ws2_32\bind", "Ptr", listenSocket, "Ptr", sockaddr, "Int", 16)
DllCall("Ws2_32\listen", "Ptr", listenSocket, "Int", 5)

OnMessage(WM_SOCKET, OnNetworkEvent)
DllCall("Ws2_32\WSAAsyncSelect", "Ptr", listenSocket, "Ptr", A_ScriptHwnd, "UInt", WM_SOCKET, "Int", 0x08)

TrayTip("ED PowerPlay Recv v1.0", "ACK 응답 지원 수신 서버 대기 중...")

; ----------------------------------------------------
; 수신 이벤트 처리 (완벽 소켓 즉시 해제 적용)
; ----------------------------------------------------
OnNetworkEvent(wParam, lParam, msg, hwnd) {
    global listenSocket
    
    if ((lParam & 0xFFFF) == 0x08) { ; FD_ACCEPT
        clientSocket := DllCall("Ws2_32\accept", "Ptr", listenSocket, "Ptr", 0, "Ptr", 0, "Ptr")
        
        if (clientSocket != -1 && clientSocket != 0) {
            ; WSAAsyncSelect 해제는 이벤트만 끄고, 소켓은 논블로킹으로 남는다.
            ; 논블로킹 recv는 데이터가 아직 없으면 즉시 10035(WSAEWOULDBLOCK)를 낸다.
            DllCall("Ws2_32\WSAAsyncSelect", "Ptr", clientSocket, "Ptr", A_ScriptHwnd, "UInt", 0, "Int", 0)
            SetSocketBlocking(clientSocket, true)

            recvTimeout := Buffer(4)
            NumPut("Int", 1000, recvTimeout, 0)
            DllCall("Ws2_32\setsockopt", "Ptr", clientSocket, "Int", 0xFFFF, "Int", 0x1006, "Ptr", recvTimeout, "Int", 4) ; SO_RCVTIMEO

            ; 1. 데이터 수신 (블로킹 + 최대 1초 대기)
            buf := Buffer(64, 0)
            bytes := DllCall("Ws2_32\recv", "Ptr", clientSocket, "Ptr", buf, "Int", 64, "Int", 0)
            
            cmd := ""
            if (bytes > 0) {
                cmd := StrGet(buf, bytes, "UTF-8")
            }
            else if (bytes == -1) {
                errCode := DllCall("Ws2_32\WSAGetLastError")
                SetOverlayState("❌ 데이터 수신 실패, 건너뜀 (" . errCode . ")", "cRed")
                SetTimer () => SetOverlayState("● AHK ONLINE", "cLime"), -1000
            }

            if (cmd != "") {
                DispatchCommand(clientSocket, cmd)
            }

            DllCall("Ws2_32\closesocket", "Ptr", clientSocket)
        }
    }
}

SetSocketBlocking(sock, blocking) {
    arg := Buffer(4, 0)
    NumPut("UInt", blocking ? 0 : 1, arg, 0)
    return DllCall("Ws2_32\ioctlsocket", "Ptr", sock, "UInt", 0x8004667E, "Ptr", arg) == 0
}

SendSocketString(sock, text) {
    bufSize := StrPut(text, "UTF-8")
    buf := Buffer(bufSize)
    StrPut(text, buf, "UTF-8")
    DllCall("Ws2_32\send", "Ptr", sock, "Ptr", buf, "Int", bufSize - 1, "Int", 0)
}

; 수신 스레드는 ACK만 보내고 바로 반환한다. 매크로는 타이머에서 실행.
; 실행 중 새 신호가 오면 진행 중인 매크로를 끊고 최신 명령만 실행한다.
DispatchCommand(clientSocket, cmd) {
    global isBusy, pendingCmd, macroCancel

    if (cmd == "Quit") {
        SendSocketString(clientSocket, "ACK")
        macroCancel := true
        ExecuteQuit()
        return
    }

    SendSocketString(clientSocket, "ACK")
    pendingCmd := cmd

    if (isBusy) {
        macroCancel := true
        return
    }

    isBusy := true
    SetTimer(RunPendingCommand, -1)
}

RunPendingCommand() {
    global isBusy, pendingCmd, macroCancel

    Loop {
        cmd := pendingCmd
        pendingCmd := ""
        macroCancel := false
        if (cmd == "")
            break
        ProcessCommand(cmd)
    }

    isBusy := false
    if (pendingCmd != "") {
        isBusy := true
        SetTimer(RunPendingCommand, -1)
        return
    }
    SetOverlayState("● AHK ONLINE", "cLime")
}

ShouldCancel() {
    global macroCancel
    return macroCancel
}

; Sleep은 한 번에 오래 막히므로 짧게 나눠 취소 플래그를 확인한다.
SleepUnlessCancel(ms) {
    elapsed := 0
    step := 20
    while (elapsed < ms) {
        if (ShouldCancel())
            return false
        wait := Min(step, ms - elapsed)
        Sleep(wait)
        elapsed += wait
    }
    return !ShouldCancel()
}

MacroSend(keys) {
    if (ShouldCancel())
        return false
    SendEvent(keys)
    return !ShouldCancel()
}

MacroClick(what) {
    if (ShouldCancel())
        return false
    Click(what)
    return !ShouldCancel()
}

; 오버레이 텍스트/색상 변경 함수
SetOverlayState(text, colorClass) {
    statusText.SetFont(colorClass)
    statusText.Value := text
}

ProcessCommand(cmd) {
    SetOverlayState("▶ RUNNING: " . cmd, "cYellow")

    if (cmd == "Fire")
        ExecuteFire()
    else if (cmd == "Ready")
        ExecuteReady()
    else if (cmd == "Recall")
        ExecuteRecall()
}

; ----------------------------------------------------
; 신호별 동작 및 Quit 처리
; ----------------------------------------------------

; Quit 신호 수신 시 실행되는 함수
ExecuteQuit() {
    SetOverlayState("○ AHK OFFLINE", "cRed")
    tts.Speak("Shutting down", SSPF_ASYNC)
    Sleep(300) ; 음성 출력 및 오버레이 확인용 미세 대기
    ExitApp()  ; 스크립트 종료 (OnExit가 자동 호출되어 소켓 자원 해제)
}

ExecuteFire() {
    if (!MacroSend("7") || !SleepUnlessCancel(100))
        return
    if (!MacroSend("^{t}") || !SleepUnlessCancel(100))
        return
    if (!MacroSend("^{a}") || !SleepUnlessCancel(100))
        return
    if (!MacroClick("Left") || !SleepUnlessCancel(100))
        return
    tts.Speak("I got it", SSPF_ASYNC)
}

ExecuteReady() {
    if (!MacroSend("{F3}") || !MacroSend("s") || !MacroSend("d") || !MacroSend("{Space}"))
        return
    if (!SleepUnlessCancel(100) || !MacroSend("s") || !MacroSend("{Space}"))
        return
    if (!SleepUnlessCancel(100) || !MacroSend("{Backspace}"))
        return
    if (!SleepUnlessCancel(100) || !MacroSend("u"))
        return
    if (!SleepUnlessCancel(100))
        return
    if (!MacroSend("{Down}") || !MacroSend("{Left 3}") || !MacroSend("{Right 3}") || !MacroSend("{Left}"))
        return
    tts.Speak("I'm Ready", SSPF_ASYNC)
}

ExecuteRecall() {
    if (!MacroClick("Middle"))
        return
    if (!MacroSend("u") || !MacroSend("^{r}") || !MacroSend("{Down 4}"))
        return
    tts.Speak("I'm Ready", SSPF_ASYNC)
}

; ----------------------------------------------------
; 종료 시 소켓 자원 해제 함수
; ----------------------------------------------------
CleanupSockets(ExitReason, ExitCode) {
    global listenSocket
    if (listenSocket) {
        DllCall("Ws2_32\closesocket", "Ptr", listenSocket)
        listenSocket := 0
    }
    DllCall("Ws2_32\WSACleanup")
}
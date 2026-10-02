#Requires AutoHotkey v2.0
#SingleInstance Force

Persistent()

global RECEIVER_IPS := ["192.168.0.38", "192.168.0.27"]
global PORT := 12345

global WSAData := Buffer(400)
if (DllCall("Ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", WSAData) != 0) {
    MsgBox("Winsock 초기화 실패")
    ExitApp()
}

OnExit((*) => DllCall("Ws2_32\WSACleanup"))

; ----------------------------------------------------
; 상태 표시용 오버레이 GUI
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
centerY := 0
overlayGui.Show("x" . centerX . " y" . centerY . " w" . overlayWidth . " h" . overlayHeight . " NoActivate")

TrayTip("ED PowerPlay Send v1.0", "ACK 응답 지원 송신 프로그램")

; ----------------------------------------------------
; 단축키 매핑
; ----------------------------------------------------
Joy21:: SendSignalToAllWithACK("Fire")
^+4:: SendSignalToAllWithACK("Ready")
^+5:: SendSignalToAllWithACK("Recall")
^+q:: ExitApp()

; ----------------------------------------------------
; 다중 송신 함수
; ----------------------------------------------------
SendSignalToAllWithACK(command) {
    for ip in RECEIVER_IPS {
        SendSignalWithACK(ip, command)
        Sleep(10)
    }
}


; ----------------------------------------------------
; ACK 확인 송신 함수 (재시도 없음)
; 연결은 500ms 안에 안 되면 꺼진 PC로 보고 즉시 건너뜀
; ----------------------------------------------------
SendSignalWithACK(ipAddress, message) {
    sock := DllCall("Ws2_32\socket", "Int", 2, "Int", 1, "Int", 6, "Ptr")
    if (sock == -1 || sock == 0) {
        ShowFeedback("❌ 소켓 생성 실패 (" . ipAddress . ")")
        return false
    }

    ; 송수신 타임아웃 500ms 설정 (연결 이후 send/recv용)
    timeout := Buffer(4)
    NumPut("Int", 500, timeout, 0)
    DllCall("Ws2_32\setsockopt", "Ptr", sock, "Int", 0xFFFF, "Int", 0x1005, "Ptr", timeout, "Int", 4) ; SO_SNDTIMEO
    DllCall("Ws2_32\setsockopt", "Ptr", sock, "Int", 0xFFFF, "Int", 0x1006, "Ptr", timeout, "Int", 4) ; SO_RCVTIMEO

    sockaddr := Buffer(16, 0)
    NumPut("UShort", 2, sockaddr, 0)
    NumPut("UShort", DllCall("Ws2_32\htons", "UShort", PORT, "UShort"), sockaddr, 2)
    NumPut("UInt", DllCall("Ws2_32\inet_addr", "AStr", ipAddress, "UInt"), sockaddr, 4)

    ; 1. 서버 연결 시도 (논블로킹, 최대 500ms)
    if (!ConnectWithTimeout(sock, sockaddr, 500)) {
        DllCall("Ws2_32\closesocket", "Ptr", sock)
        ShowFeedback("❌ 연결 실패, 건너뜀 (" . ipAddress . ")")
        return false
    }

    bufSize := StrPut(message, "UTF-8")
    buf := Buffer(bufSize)
    StrPut(message, buf, "UTF-8")

    ; 2. 데이터 전송
    DllCall("Ws2_32\send", "Ptr", sock, "Ptr", buf, "Int", bufSize - 1, "Int", 0)

    ; 3. 수신측의 ACK 응답 대기
    ackBuf := Buffer(16, 0)
    bytesReceived := DllCall("Ws2_32\recv", "Ptr", sock, "Ptr", ackBuf, "Int", 16, "Int", 0)

    ackStr := ""
    if (bytesReceived > 0) {
        ackStr := StrGet(ackBuf, bytesReceived, "UTF-8")
    }

    DllCall("Ws2_32\closesocket", "Ptr", sock)

    if (ackStr == "ACK") {
        ShowFeedback("▶ 전송 및 수신확인 성공 (" . message . ")")
        return true
    }

    ShowFeedback("❌ 수신 확인 실패 (전송 누락) " . ipAddress)
    return false
}

MakeFdSet(sock) {
    if (A_PtrSize = 8) {
        fdSet := Buffer(16, 0)
        NumPut("UInt", 1, fdSet, 0)
        NumPut("Ptr", sock, fdSet, 8)
    } else {
        fdSet := Buffer(8, 0)
        NumPut("UInt", 1, fdSet, 0)
        NumPut("UInt", sock, fdSet, 4)
    }
    return fdSet
}

SetSocketBlocking(sock, blocking) {
    arg := Buffer(4, 0)
    NumPut("UInt", blocking ? 0 : 1, arg, 0)
    return DllCall("Ws2_32\ioctlsocket", "Ptr", sock, "UInt", 0x8004667E, "Ptr", arg) == 0
}

ConnectWithTimeout(sock, sockaddr, timeoutMs := 500) {
    if (!SetSocketBlocking(sock, false))
        return false

    result := DllCall("Ws2_32\connect", "Ptr", sock, "Ptr", sockaddr, "Int", 16)
    if (result == 0)
        return SetSocketBlocking(sock, true)

    wsaErr := DllCall("Ws2_32\WSAGetLastError", "Int")
    if (wsaErr != 10035 && wsaErr != 10036) ; WSAEWOULDBLOCK, WSAEINPROGRESS
        return false

    tv := Buffer(8, 0)
    NumPut("Int", timeoutMs // 1000, tv, 0)
    NumPut("Int", Mod(timeoutMs, 1000) * 1000, tv, 4)

    writeSet := MakeFdSet(sock)
    exceptSet := MakeFdSet(sock)
    sel := DllCall("Ws2_32\select", "Int", 0, "Ptr", 0, "Ptr", writeSet, "Ptr", exceptSet, "Ptr", tv, "Int")
    if (sel <= 0)
        return false

    soErrBuf := Buffer(4, 0)
    lenBuf := Buffer(4, 0)
    NumPut("Int", 4, lenBuf, 0)
    DllCall("Ws2_32\getsockopt", "Ptr", sock, "Int", 0xFFFF, "Int", 0x1007, "Ptr", soErrBuf, "Ptr", lenBuf)
    if (NumGet(soErrBuf, 0, "Int") != 0)
        return false

    return SetSocketBlocking(sock, true)
}

ShowFeedback(txt) {
    ToolTip(txt)
    SetTimer () => ToolTip(), -1500
}

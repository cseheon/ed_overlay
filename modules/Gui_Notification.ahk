#Requires AutoHotkey v2.0

class NotificationGui {
    static bgGui := 0
    static textGui := unset
    static lblText := unset
    static hideTimer := ObjBindMethod(NotificationGui, "Hide")

    ; 초기화 (GUI 구조 생성)
    static Init() {
        if (this.bgGui != 0)
            return

        ; 1. 배경 Layer (반투명 검은색 + 둥근 모서리)
        this.bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Notice_BG")
        this.bgGui.BackColor := "000000"
        WinSetTransparent(180, this.bgGui)

        ; 2. 텍스트 Layer (투명 배경)
        this.textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +0x02000000", "ED_Notice_Text")
        this.textGui.BackColor := "000001"
        WinSetTransColor("000001 255", this.textGui)

        ; 텍스트 컨트롤 생성 (Center 옵션으로 가로 중앙 정렬)
        this.textGui.SetFont("s15 w600 Q5 c3bb1ff", "Segoe UI")
        this.lblText := this.textGui.Add("Text", "x0 y0 Center", "")
    }

    ; 알림창 출력 함수
    static Show(message, durationMs := 3000) {
        this.Init()

        ; 기존 타이머가 작동 중이면 초기화
        SetTimer(this.hideTimer, 0)

        paddingX := 40
        paddingY := 20

        ; 1. [textW, textH] 구조 분해 할당을 통해 배열 값 추출 (오류 방지)
        textSize := SetTextAndResize(this.lblText, message)
        textW := textSize[1]
        textH := textSize[2]

        ; 2. 여백(Padding)을 포함한 패널 전체 크기 계산 (최소 너비 240px 보장)
        guiW := Max(240, textW + (paddingX * 2))
        guiH := textH + (paddingY * 2)

        ; 3. 텍스트를 패널 내부 가로/세로 중앙에 배치하기 위한 상대 좌표
        textPosX := (guiW - textW) / 2
        textPosY := (guiH - textH) / 2

        ; 4. 화면 중앙 세로 1/3 지점 좌표 계산
        posX := (A_ScreenWidth - guiW) / 2
        posY := (A_ScreenHeight / 3) - (guiH / 2)

        ; 둥근 모서리 적용 (Radius 12)
        hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", guiW, "Int", guiH, "Int", 12, "Int", 12, "Ptr")
        DllCall("SetWindowRgn", "Ptr", this.bgGui.Hwnd, "Ptr", hRgn, "UInt", true)

        ; 5. 컨트롤 및 GUI 위치 배치
        this.lblText.Move(textPosX, textPosY)

        this.bgGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", posX, posY, guiW, guiH))
        this.textGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", posX, posY, guiW, guiH))

        ; 6. 지정된 시간(ms) 후 자동으로 숨기기 설정
        if (durationMs > 0) {
            SetTimer(this.hideTimer, -durationMs)
        }
    }

    static Hide() {
        SetTimer(this.hideTimer, 0)
        if (this.bgGui != 0) {
            this.bgGui.Hide()
            this.textGui.Hide()
        }
    }
}

; 편리하게 사용할 수 있는 전역 래퍼(Wrapper) 함수
ShowNotice(message, durationMs := 3000) {
    NotificationGui.Show(message, durationMs)
}
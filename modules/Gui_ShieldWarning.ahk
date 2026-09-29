#Requires AutoHotkey v2.0

class ShieldWarningGui {

    static isActive := false

    static _bgGui := unset
    static _textGui := unset
    static _textCtrl := unset

    static _colorA := "d40000" ; 0xd40000
    static _colorB := "550000" ; 0x550000

    static _blinkTimer := ObjBindMethod(ShieldWarningGui, "OnBlinkTimer")
    static _blinkStartTick := 0

    static Init(iniPath) {
        this.guiW := Integer(IniRead(iniPath, "ShieldWarning", "Width", "400"))
        this.guiH := Integer(IniRead(iniPath, "ShieldWarning", "Height", "40"))
        this.posX := Integer(IniRead(iniPath, "ShieldWarning", "X", (A_ScreenWidth - this.guiW) / 2))
        this.posY := Integer(IniRead(iniPath, "ShieldWarning", "Y", A_ScreenWidth / 7))
        this.duration := Integer(IniRead(iniPath, "ShieldWarning", "Duration", "5"))

        ; 배경 GUI 설정 (초기 빨간색)
        this._bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Shield_BG")
        this._bgGui.BackColor := this._colorA
        WinSetTransparent(180, this._bgGui)

        ; 텍스트 GUI 설정
        this._textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +0x02000000", "ED_Shield_Text")
        this._textGui.BackColor := "000001"
        WinSetTransColor("000001 255", this._textGui)

        this._textGui.SetFont("s14 bold Q5", "Consolas")
        this._textCtrl := this._textGui.Add("Text", Format("x0 y{1} w{2} h{3} cWhite Center", (this.guiH - 24) / 2, this.guiW, this.guiH), "⚠️ SHIELDS OFFLINE ⚠️")

        this.colorHexA := ParseColor(this._colorA)
        this.colorHexB := ParseColor(this._colorB)

        this.Hide()
    }

    static Show() {
        if (this.isActive)
            return

        this.isActive := true
        this._blinkStartTick := A_TickCount

        ; 둥근 모서리 적용 (Radius 12)
        hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", this.guiW, "Int", this.guiH, "Int", 12, "Int", 12, "Ptr")
        DllCall("SetWindowRgn", "Ptr", this._bgGui.Hwnd, "Ptr", hRgn, "UInt", true)

        this._bgGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this.posX, this.posY, this.guiW, this.guiH))
        this._textGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this.posX, this.posY, this.guiW, this.guiH))

        this._bgGui.BackColor := this._colorA
        WinRedraw(this._bgGui.Hwnd)

        Voice.Speak("Warning!", 1)
        SetTimer(this._blinkTimer, 16)
    }

    static Hide() {
        this.isActive := false
        this._bgGui.Hide()
        this._textGui.Hide()

        SetTimer(this._blinkTimer, 0)
    }

    ; 주기적으로 방어막 경고 루프
    static OnBlinkTimer() {
        t := (A_TickCount - this._blinkStartTick) / 1000
        this._bgGui.BackColor := PingPongColor(this.colorHexA, this.colorHexB, t * 2)
        WinRedraw(this._bgGui.Hwnd)

        ; 유지시간 경과 시 종료
        if (A_TickCount - this._blinkStartTick >= this.duration * 1000) {
            AppState.isShieldWarningActive := false
            this.Hide()
        }
    }
}
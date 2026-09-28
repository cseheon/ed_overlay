#Requires AutoHotkey v2.0

class ShieldWarningGui {
    static bgGui := unset
    static textGui := unset
    static textCtrl := unset
    static isRedState := false

    static Init(px, py, w, h) {
        ; 배경 GUI 설정 (초기 빨간색)
        this.bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Shield_BG")
        this.bgGui.BackColor := "FF0000"
        WinSetTransparent(180, this.bgGui)

        ; 텍스트 GUI 설정
        this.textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +0x02000000", "ED_Shield_Text")
        this.textGui.BackColor := "000001"
        WinSetTransColor("000001 255", this.textGui)

        this.textGui.SetFont("s16 bold Q5", "Consolas")
        this.textCtrl := this.textGui.Add("Text", Format("x0 y2 w{1} h{2} cWhite Center", w, h), "⚠️⚠️ SHIELDS DOWN ⚠️⚠️")

        ; 좌표 위치 저장 후 숨김
        this.posX := px, this.posY := py, this.guiW := w, this.guiH := h
        this.Hide()
    }

    static Show() {
        this.bgGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this.posX, this.posY, this.guiW, this.guiH))
        this.textGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this.posX, this.posY, this.guiW, this.guiH))
    }

    static Hide() {
        this.bgGui.Hide()
        this.textGui.Hide()
    }

    ; 반짝이는 효과 (0.5초 단위 스위칭)
    static ToggleBlink() {
        this.isRedState := !this.isRedState
        if (this.isRedState) {
            this.bgGui.BackColor := "FF0000" ; 진한 빨간색
            WinSetTransparent(200, this.bgGui)
        } else {
            this.bgGui.BackColor := "550000" ; 어두운 빨간색
            WinSetTransparent(100, this.bgGui)
        }
        WinRedraw(this.bgGui.Hwnd)
    }
}
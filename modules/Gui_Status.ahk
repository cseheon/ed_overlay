#Requires AutoHotkey v2.0

class StatusOverlayGui {
    static bgGui := unset
    static textGui := unset
    static lblSystem := unset
    static valSystem := unset
    static lblStation := unset
    static valStation := unset
    static lblPower := unset
    static valPower := unset
    static lblPowerState := unset
    static valPowerState := unset
    static lblCredits := unset
    static valCredits := unset
    static lblTotalMerits := unset
    static valTotalMerits := unset

    static _posX := 0, _posY := 0, _guiW := 0, _guiH := 0

    static _lastState := ""
    static _lastSystem := ""
    static _lastStation := ""
    static _lastCzBody := ""
    static _lastPower := ""
    static _lastPowerState := ""
    static _lastEnemy := ""
    static _lastTotalMerits := 0
    static _lastCredits := 0

    static Init(posX, posY, guiW, guiH) {
        this._posX := posX
        this._posY := posY
        this._guiW := guiW
        this._guiH := guiH

        this.bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Status_BG")
        this.bgGui.BackColor := "000000"
        WinSetTransparent(140, this.bgGui)

        ; this.textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +0x02000000", "ED_Status_Text")
        this.textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Status_Text")
        this.textGui.BackColor := "000001"
        WinSetTransColor("000001 255", this.textGui)

        ; --- 시스템 정보
        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblSystem := this.textGui.Add("Text", "x15 y11", "SYSTEM")
        this.textGui.SetFont("s11 w700 Q5 cWhite", "Segoe UI")
        this.valSystem := this.textGui.Add("Text", "x+10 y8", "Unknown")

        ; --- 시스템 파워세력 정보
        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblPower := this.textGui.Add("Text", "x+25 y11", "POWER")
        this.textGui.SetFont("s11 w700 Q5 cWhite", "Segoe UI")
        this.valPower := this.textGui.Add("Text", "x+10 y8", "Unknown")

        ; --- 시스템 파워 상태 정보
        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblPowerState := this.textGui.Add("Text", "x+25 y11", "STATE")
        this.textGui.SetFont("s11 w700 Q5 cWhite", "Segoe UI")
        this.valPowerState := this.textGui.Add("Text", "x+10 y8", "Unknown")

        ; --- 도킹 스테이션 정보
        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblStation := this.textGui.Add("Text", "x+25 y11", "DOCKED")
        this.textGui.SetFont("s11 w700 Q5 cWhite", "Segoe UI")
        this.valStation := this.textGui.Add("Text", "x+10 y8", "Unknown")

        ; --- 보유 Merit 정보
        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblTotalMerits := this.textGui.Add("Text", "x+25 y11", "MERITS")
        this.textGui.SetFont("s11 w700 Q5 cWhite", "Segoe UI")
        this.valTotalMerits := this.textGui.Add("Text", "x+10 y8", "0")

        ; --- 보유 Credit 정보
        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblCredits := this.textGui.Add("Text", "x+25 y11", "CREDITS")
        this.textGui.SetFont("s11 w700 Q5 cWhite", "Segoe UI")
        this.valCredits := this.textGui.Add("Text", "x+10 y8", "0")

        SetTimer(() => this.Show(), -1000)
    }

    static Update(state) {
        Critical
        isChanged := false

        if (state.currentState != this._lastState) {
            this._lastState := state.currentState
            isChanged := true
        }

        if (state.starSystem != this._lastSystem) {
            SetTextAndResize(this.valSystem, state.starSystem != "" ? state.starSystem : "Unknown")
            this._lastSystem := state.starSystem
            isChanged := true
        }

        if (state.dockedStationName != this._lastStation) {
            SetTextAndResize(this.valStation, state.dockedStationName != "" ? state.dockedStationName : "Unknown")
            this._lastStation := state.dockedStationName
            isChanged := true
        }

        if (state.systemPower != this._lastPower) {
            SetTextAndResize(this.valPower, state.systemPower != "" ? state.systemPower : "None")
            this._lastPower := state.systemPower
            isChanged := true
        }

        if (state.systemPowerState != this._lastPowerState) {
            SetTextAndResize(this.valPowerState, state.systemPowerState != "" ? state.systemPowerState : "Unoccupied")
            this._lastPowerState := state.systemPowerState
            isChanged := true
        }

        if (state.TotalMerits != this._lastTotalMerits) {
            SetTextAndResize(this.valTotalMerits, FormatNumber(state.TotalMerits))
            this._lastTotalMerits := state.TotalMerits
            isChanged := true
        }

        if (state.totalCredits != this._lastCredits) {
            SetTextAndResize(this.valCredits, FormatNumber(state.totalCredits))
            this._lastCredits := state.totalCredits
            isChanged := true
        }

        if (!isChanged)
            return

        ; --- 좌측 정렬 처리
        baseLeft := 15

        ; --- 시스템 위치
        this.lblSystem.Move(baseLeft)
        this.lblSystem.GetPos(&x, &y, &sw, &h)
        baseLeft += sw + 10
        this.valSystem.Move(baseLeft)
        this.valSystem.GetPos(&x, &y, &sw, &h)
        baseLeft += sw + 25

        ; --- 파워세력 위치
        this.lblPower.Move(baseLeft)
        this.lblPower.GetPos(&x, &y, &sw, &h)
        baseLeft += sw + 10
        this.valPower.Move(baseLeft)
        this.valPower.GetPos(&x, &y, &sw, &h)
        baseLeft += sw + 25

        ; --- 파워 상태 위치
        this.lblPowerState.Move(baseLeft)
        this.lblPowerState.GetPos(&x, &y, &sw, &h)
        baseLeft += sw + 10
        this.valPowerState.Move(baseLeft)
        this.valPowerState.GetPos(&x, &y, &sw, &h)
        baseLeft += sw + 25

        if (state.currentState == "Docked") {
            ; --- 스테이션 위치
            this.lblStation.Move(baseLeft)
            this.lblStation.GetPos(&x, &y, &sw, &h)
            baseLeft += sw + 10
            this.valStation.Move(baseLeft)
            this.valStation.GetPos(&x, &y, &sw, &h)
            baseLeft += sw + 25

            this.lblStation.Visible := true
            this.valStation.Visible := true
        }
        else {
            this.lblStation.Visible := false
            this.valStation.Visible := false
        }


        ; --- 우측 정렬 처리
        right := this._guiW - 15

        this.lblTotalMerits.GetPos(&x, &y, &meritLabelW, &meritLabelH)
        this.valTotalMerits.GetPos(&x, &y, &meritValueW, &meritValueH)

        right -= meritValueW
        this.valTotalMerits.Move(right)
        right -= 10 + meritLabelW
        this.lblTotalMerits.Move(right)
        right -= 25

        ; --- Credit 정보 위치
        this.lblCredits.GetPos(&x, &y, &creditLabelW, &creditLabelH)
        this.valCredits.GetPos(&x, &y, &creditValueW, &creditValueH)

        right -= creditValueW
        this.valCredits.Move(right)
        right -= 10 + creditLabelW
        this.lblCredits.Move(right)
        right -= 25

        WinRedraw(this.textGui.Hwnd)
    }

    static Show() {
        this.bgGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this._posX, this._posY, this._guiW, this._guiH))
        this.textGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this._posX, this._posY, this._guiW, this._guiH))
    }

    static Hide() {
        this.bgGui.Hide()
        this.textGui.Hide()
    }
}
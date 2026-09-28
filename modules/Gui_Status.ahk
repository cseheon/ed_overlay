#Requires AutoHotkey v2.0

class StatusOverlayGui {
    static bgGui := unset
    static textGui := unset
    static ctrlMode := unset
    static lblSystem := unset
    static valSystem := unset
    static lblStation := unset
    static valStation := unset
    static lblTotalMerits := unset
    static valTotalMerits := unset
    static ctrlLine2 := unset

    static Init(posX, posY, guiW, guiH) {
        this.bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Status_BG")
        this.bgGui.BackColor := "000000"
        WinSetTransparent(140, this.bgGui)
        this.bgGui.Show("x" . posX . " y" . posY . " w" . guiW . " h" . guiH . " NoActivate")

        this.textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +0x02000000", "ED_Status_Text")
        this.textGui.BackColor := "010101"
        WinSetTransColor("010101", this.textGui)

        this.textGui.SetFont("s13 w700 Q5 cff7b00", "Consolas")
        this.ctrlMode := this.textGui.Add("Text", "x15 y8 w80", "STATUS")

        ; 라인 1
        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblSystem := this.textGui.Add("Text", "x+25 y11", "SYSTEM")
        this.textGui.SetFont("s11 w700 Q5 cWhite", "Segoe UI")
        this.valSystem := this.textGui.Add("Text", "x+10 y8 w100", "Unknown")

        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblStation := this.textGui.Add("Text", "x+25 y11", "STATION")
        this.textGui.SetFont("s11 w700 Q5 cWhite", "Segoe UI")
        this.valStation := this.textGui.Add("Text", "x+10 y8 w100", "Unknown")

        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblTotalMerits := this.textGui.Add("Text", "x+25 y11", "MERITS")
        this.textGui.SetFont("s11 w700 Q5 cWhite", "Segoe UI")
        this.valTotalMerits := this.textGui.Add("Text", "x+10 y8 w100", "0")

        ; 라인 2
        this.textGui.SetFont("s10 w400 Q5 c00FF00", "Consolas")
        this.ctrlLine2 := this.textGui.Add("Text", "x15 y34 w770", "Searching for log files...")

        this.textGui.Show("x" . posX . " y" . posY . " w" . guiW . " h" . guiH . " NoActivate")
    }

    static Update(state) {
        Critical
        isChanged := false

        if (state.currentState != state.lastState) {
            switch state.currentState {
            case "System":
                this.ctrlMode.Value := "SYSTEM"
                this.lblStation.Value := "STATION"
            case "Docked":
                this.ctrlMode.Value := "DOCKED"
                this.lblStation.Value := "STATION"
            case "PowerCZ":
                this.ctrlMode.Value := "POWER CZ"
                this.lblStation.Value := "BODY"
            }
            isChanged := true
        }

        if (state.starSystem != state.lastSystem) {
            SetTextAndResize(this.valSystem, state.starSystem != "" ? state.starSystem : "Unknown")
            state.lastSystem := state.starSystem
            isChanged := true
        }

        if (state.stationName != state.lastStation) {
            SetTextAndResize(this.valStation, state.stationName != "" ? state.stationName : "Unknown")
            state.lastStation := state.stationName
            isChanged := true
        }

        if (state.currentTotalMerits != state.lastTotalMerits) {
            SetTextAndResize(this.valTotalMerits, FormatNumber(state.currentTotalMerits))
            state.lastTotalMerits := state.currentTotalMerits
            isChanged := true
        }

        if (state.currentState == "PowerCZ" && state.czBodyName != state.lastCzBody) {
            SetTextAndResize(this.valStation, state.czBodyName != "" ? state.czBodyName : "Unknown")
            state.lastCzBody := state.czBodyName
            isChanged := true
        }

        if (state.currentState != state.lastState || state.powerName != state.lastPower || state.powerState != state.lastPowerState || state.enemyFaction != state.lastEnemy) {
            isChanged := true
            state.lastState := state.currentState
            state.lastPower := state.powerName
            state.lastPowerState := state.powerState
            state.lastEnemy := state.enemyFaction

            PowerCzOverlayGui.UpdateDisplay(state)
        }

        if (!isChanged)
            return

        switch state.currentState {
            case "System":
                this.lblStation.Visible := false
                this.valStation.Visible := false

                this.valSystem.GetPos(&vx, &vy, &vw, &vh)
                this.lblTotalMerits.Move(vx + vw + 25, 11)
                this.lblTotalMerits.GetPos(&sx, &sy, &sw, &sh)
                this.valTotalMerits.Move(sx + sw + 10, 8)

                this.lblTotalMerits.Visible := true
                this.valTotalMerits.Visible := true

                this.ctrlLine2.Value := (state.powerName != "") ? Format("POWER: {1} ({2})", state.powerName, state.powerState) : "POWER: None / Unoccupied"

            case "Docked":
                this.valSystem.GetPos(&vx, &vy, &vw, &vh)
                this.lblStation.Move(vx + vw + 25, 11)
                this.lblStation.GetPos(&stx, &sty, &stw, &sth)
                this.valStation.Move(stx + stw + 10, 8)

                this.valStation.GetPos(&vsx, &vsy, &vsw, &vsh)
                this.lblTotalMerits.Move(vsx + vsw + 25, 11)
                this.lblTotalMerits.GetPos(&secx, &secy, &secw, &sech)
                this.valTotalMerits.Move(secx + secw + 10, 8)

                this.lblStation.Visible := true
                this.valStation.Visible := true
                this.lblTotalMerits.Visible := true
                this.valTotalMerits.Visible := true

                this.ctrlLine2.Value := (state.powerName != "") ? Format("POWER: {1} ({2})", state.powerName, state.powerState) : "POWER: None / Unoccupied"

            case "PowerCZ":
                this.valSystem.GetPos(&vx, &vy, &vw, &vh)
                this.lblStation.Move(vx + vw + 25, 11)
                this.lblStation.GetPos(&stx, &sty, &stw, &sth)
                this.valStation.Move(stx + stw + 10, 8)

                this.valStation.GetPos(&vsx, &vsy, &vsw, &vsh)
                this.lblTotalMerits.Move(vsx + vsw + 25, 11)
                this.lblTotalMerits.GetPos(&secx, &secy, &secw, &sech)
                this.valTotalMerits.Move(secx + secw + 10, 8)

                this.lblStation.Visible := true
                this.valStation.Visible := true
                this.lblTotalMerits.Visible := true
                this.valTotalMerits.Visible := true

                this.ctrlLine2.Value := (state.enemyFaction != "") ? Format("VS: {1}", state.enemyFaction) : "VS: [SCANNING TARGET...]"
        }

        WinRedraw(this.textGui.Hwnd)
    }
}
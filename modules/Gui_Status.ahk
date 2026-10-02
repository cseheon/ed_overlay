#Requires AutoHotkey v2.0

class StatusOverlayGui {
    static isShow := false

    static lableGap := 8
    static valueGap := 24

    static _bgGui := unset
    static _textGui := unset
    static _posX := 0, _posY := 0, _guiW := 0, _guiH := 0

    static _timerActive := false
    static _timerControl := 0
    static _lastTickCount := 0

    static _items := []
    static _lastStates := Map()
    static _definitions := [
        { label: "STSTEM", key: "starSystem", value: "Unknown", align: "left", visible:true }, 
        { label: "POPULATION", key: "systemPopulation", value: 0, align: "left", visible: true },
        { label: "SECURITY", key: "systemSecurity", value: "Unknown", align: "left", visible: true },
        { label: "SYSTEM POWER", key: "systemPower", value: "Unknown", align: "left", visible:true }, 
        { label: "POWER STATE", key: "systemPowerState", value: "Unknown", align: "left", visible:true }, 
        { label: "DOCKED", key: "dockedStationName", value: "Unknown", align: "left", visible:true }, 
        { label: "POWER CONFLICT", key: "powerEnemyFaction", value: "Unknown", align: "left", visible:true }, 
        { label: "TIME", key: "", value: "00:00", align: "center", visible:true }, 
        { label: "KILLS", key: "powerKills", value: 0, align: "center", visible:true }, 
        { label: "CZ MERITS", key: "powerMerits", value: 0, align: "center", visible: true },
        { label: "MERITS", key: "totalMerits", value: 0, align: "right", visible:true }, 
        { label: "CREDITS", key: "totalCredits", value: 0, align: "right", visible:true }]

    static Init(posY := 20) {
        this._posX := 0
        this._posY := posY
        this._guiW := A_ScreenWidth
        this._guiH := 38

        this._bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Status_BG")
        this._bgGui.BackColor := "000000"
        WinSetTransparent(140, this._bgGui)

        this._textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Status_Text")
        this._textGui.BackColor := "000001"
        WinSetTransColor("000001 255", this._textGui)

        for index, item in this._definitions {
            this._textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
            labelControl := this._textGui.Add("Text", "x+25 y11", item.label)
            this._textGui.SetFont("s11 w700 Q5 cWhite", "Segoe UI")
            valueControl := this._textGui.Add("Text", "x+10 y8", item.value)

            this._definitions[index].labelControl := labelControl
            this._definitions[index].valueControl := valueControl

            if (item.label == "TIME") {
                this._timerControl := valueControl
            }

            this._items.Push(item)
        }

        ; this.Show()
    }

    static Update(state) {
        Critical
        
        isChanged := this._UpdateContentVisible(state)

        this._UpdatePowerCZ(state)

        for item in this._definitions {
            if (item.key == "")
                continue

            newValue := state.%item.key%
            if (IsInteger(newValue))
                newValue := FormatNumber(newValue)

            if (this._lastStates.Has(item.key) && this._lastStates[item.key] == newValue)
                continue

            this._lastStates[item.key] := newValue
            SetTextAndResize(item.valueControl, newValue != "" ? newValue : "Unknown")

            isChanged := true
        }

        if (isChanged) {
            this._UpdateContentPosition()
            WinRedraw(this._textGui.Hwnd)
        }

        ; 갤럭시 맵 또는 시스템 맵이 열려 있는 경우 GUI를 숨기고, 그렇지 않으면 표시한다.
        if (this.isShow) {
            if (state.isMapOpened) {
                this.Hide()
            }
        }
        else {
            if (!(state.isMapOpened)) {
                this.Show()
            }
        }
    }

    static Show() {
        this.isShow := true
        this._bgGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this._posX, this._posY, this._guiW, this._guiH))
        this._textGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this._posX, this._posY, this._guiW, this._guiH))
    }

    static Hide() {
        this.isShow := false
        this._bgGui.Hide()
        this._textGui.Hide()
    }

    static StartPowerCZTimer(state) {
        if (state.currentState != "PowerCZ")
            return

        if (this._timerActive) {
            this._timerActive := false
        }
        else {
            if (state.powerStartTimeMarker == "")
                state.powerStartTimeMarker := A_NowUTC

            this._timerActive := true
            this._lastTickCount := A_TickCount
        }
    }

    static ResetPowerCZTimer(state) {
        if (this._timerActive) {
            if (state.powerMerits > 0 && state.powerKills > 0 && state.powerLastKillTime > 0)
                Logger.SaveLogToJSON(state)
        }
        this._timerActive := false
        this._lastTickCount := 0
        state.ResetCZMetrics()
    }

    static _UpdatePowerCZ(state) {
        ; Power CZ 가 아니면 타이머를 정지하고 초기화.
        if (state.currentState != "PowerCZ") {
            ; Power CZ 가 아닐때, 타이머가 활성화되어 있으면 타이머를 정지하고, 마지막 TickCount를 초기화
            this.ResetPowerCZTimer(state)
            return
        }

        ; 타이어 작동중에 함선 무기를 접었을때 타이머를 일시 정지한다.
        if (this._timerActive && state.isHardpointsDeployed == false) {
            this._timerActive := false
        }

        ; 아직 타이머가 작동하지 않았을때, 함선무기를 전개하거나 적함선을 파괴하면 타이머를 시작
        if (this._timerActive == false && state.isHardpointsDeployed) {
            this.StartPowerCZTimer(state)
        }

        ; 타이머가 작동중일때 경과시간 업데이트
        if (this._timerActive) {
            if (state.powerStartTimeMarker == "")
                return

            if (this._timerControl == 0)
                return

            state.powerElapsedSeconds += (A_TickCount - this._lastTickCount) / 1000
            this._lastTickCount := A_TickCount

            mins := Floor(state.powerElapsedSeconds / 60)
            secs := Mod(state.powerElapsedSeconds, 60)
            this._timerControl.Value := Format("{1:02d}:{2:02d}", mins, secs)
        }
    }

    static _UpdateContentVisible(state) {
        isChanged := false
        for item in this._definitions {
            switch item.label {
                case "TIME", "KILLS", "CZ MERITS":
                    if (item.visible != this._timerActive) {
                        item.visible := this._timerActive
                        item.labelControl.Visible := item.visible
                        item.valueControl.Visible := item.visible
                        isChanged := true
                    }
                case "DOCKED":
                    docVisible := (state.currentState == "Docked")
                    if (item.visible != docVisible) {
                        item.visible := docVisible
                        item.labelControl.Visible := item.visible
                        item.valueControl.Visible := item.visible
                        isChanged := true
                    }
                case "POWER CONFLICT":
                    czVisible := (state.currentState == "PowerCZ")
                    if (item.visible != czVisible) {
                        item.visible := czVisible
                        item.labelControl.Visible := item.visible
                        item.valueControl.Visible := item.visible
                        isChanged := true
                    }
                case "SYSTEM POWER", "POWER STATE":
                    powerVisible := (state.systemPower != "" && state.systemPower != "Unknown")
                    if (item.visible != powerVisible) {
                        item.visible := powerVisible
                        item.labelControl.Visible := item.visible
                        item.valueControl.Visible := item.visible
                        isChanged := true
                    }
            }
        }
        return isChanged
    }

    static _UpdateContentPosition() {

        leftX := 15
        rightX := this._guiW - 15
        centerW := 0

        ; 가운데 표시되는 항목들의 총 너비를 계산하여 가운데 정렬을 위한 시작 X 좌표를 계산
        for item in this._items {
            if (item.visible == false)
                continue

            if (item.align == "center") {
                item.labelControl.GetPos(&oldX, &oldY, &controlW, &controlH)
                centerW += controlW + this.lableGap
                item.valueControl.GetPos(&oldX2, &oldY2, &controlW2, &controlH2)
                centerW += controlW2 + this.valueGap
            }
        }
        centerW -= this.valueGap
        
        centerX := (this._guiW - centerW) / 2

        for item in this._items {
            if (item.visible == false)
                continue

            if (item.align == "left") {
                item.labelControl.GetPos(&oldX, &oldY, &controlW, &controlH)
                item.labelControl.Move(leftX, oldY)
                leftX += controlW + this.lableGap

                item.valueControl.GetPos(&oldX2, &oldY2, &controlW2, &controlH2)
                item.valueControl.Move(leftX, oldY2)
                leftX += controlW2 + this.valueGap
            } else if (item.align == "center") {
                item.labelControl.GetPos(&oldX, &oldY, &controlW, &controlH)
                item.labelControl.Move(centerX, oldY)
                centerX += controlW + this.lableGap

                item.valueControl.GetPos(&oldX2, &oldY2, &controlW2, &controlH2)
                item.valueControl.Move(centerX, oldY2)
                centerX += controlW2 + this.valueGap
            }
            else if (item.align == "right") {
                item.valueControl.GetPos(&oldX2, &oldY2, &controlW2, &controlH2)
                rightX -= controlW2
                item.valueControl.Move(rightX, oldY2)
                rightX -= this.lableGap

                item.labelControl.GetPos(&oldX, &oldY, &controlW, &controlH)
                rightX -= controlW
                item.labelControl.Move(rightX, oldY)
                rightX -= this.valueGap
            }
        }
    }
}



class Logger {
    static SaveLogToJSON(state) {
        logFilePath := A_ScriptDir . "\PowerCZ_Log.json"
        nowStr := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

        mins := Floor(state.powerLastKillTime / 60)
        secs := Mod(state.powerLastKillTime, 60)
        elapsedStr := Format("{1:02d}:{2:02d}", mins, secs)
        ppm := (state.powerLastKillTime > 0) ? Round((state.powerMerits / state.powerLastKillTime) * 60, 1) : 0.0

        startTotal := (state.powerInitTotalMerits > 0) ? state.powerInitTotalMerits : state.totalMerits
        endTotal := state.totalMerits

        jsonEntry := Format(
            '  {`n' .
            '    "timestamp": "{1}",`n' .
            '    "initial_total_merits": {2},`n' .
            '    "final_total_merits": {3},`n' .
            '    "elapsed_time": "{4}",`n' .
            '    "kill_count": {5},`n' .
            '    "session_merits": {6},`n' .
            '    "ppm": {7}`n' .
            '  }',
            nowStr, startTotal, endTotal, elapsedStr, state.powerKills, state.powerMerits, ppm
        )

        if (!FileExist(logFilePath)) {
            fileContent := "[`n" . jsonEntry . "`n]"
            FileAppend(fileContent, logFilePath, "UTF-8")
        } else {
            existingText := FileRead(logFilePath, "UTF-8")
            existingText := RTrim(existingText, " `r`n]")
            updatedText := existingText . ",`n" . jsonEntry . "`n]"
            f := FileOpen(logFilePath, "w", "UTF-8")
            f.Write(updatedText)
            f.Close()
        }
    }
}
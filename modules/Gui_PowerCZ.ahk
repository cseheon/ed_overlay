#Requires AutoHotkey v2.0

class PowerCzOverlayGui {
    ; static bgGui := unset
    static textGui := unset
    static textCzTitle := unset
    static lblTime := unset
    static valTime := unset
    static lblKills := unset
    static valKills := unset
    static lblMerits := unset
    static valMerits := unset
    static posX := 0, posY := 0, guiW := 0, guiH := 0

    static _visibleiState := ""      ; "" , "title", "counter"
    static _isRunning := false
    static _lastKills := -1
    static _lastMerits := -1
    static _lastTickCount := 0

    static Init(px, py, w, h) {
        w := Max(w, 400)
        this.posX := px, this.posY := py, this.guiW := w, this.guiH := h

        /*
        this.bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Cz_BG")
        this.bgGui.BackColor := "000000"
        WinSetTransparent(140, this.bgGui)
        */

        this.textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +0x02000000", "ED_Cz_Text")
        this.textGui.BackColor := "000001"
        WinSetTransColor("000001 255", this.textGui)

        ; this.textGui.SetFont("s10 w600 Q5", "Segoe UI")
        this.textGui.SetFont("s12 w700 Q5 c00ffff", "Consolas")
        this.textCzTitle := this.textGui.Add("Text", "x0 y10 w" . w . " h" . h . " Center", "POWER CONFLICT ZONE")

        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblTime := this.textGui.Add("Text", "x70 y11", "TIME")
        this.textGui.SetFont("s14 w700 Q5 cWhite", "Segoe UI")
        this.valTime := this.textGui.Add("Text", "x+10 y6", "00:00")

        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblKills := this.textGui.Add("Text", "x170 y11", "KILLS")
        this.textGui.SetFont("s14 w700 Q5 cWhite", "Segoe UI")
        this.valKills := this.textGui.Add("Text", "x+10 y6", "0")
        this.valKills.Value := "0"

        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblMerits := this.textGui.Add("Text", "x250 y11", "MERITS")
        this.textGui.SetFont("s14 w700 Q5 cWhite", "Segoe UI")
        this.valMerits := this.textGui.Add("Text", "x+10 y6", "0")
        this.valMerits.Value := "0"

        this.Hide()
    }

    static CenterMetrics() {
        controls := [
            this.lblTime, this.valTime,
            this.lblKills, this.valKills,
            this.lblMerits, this.valMerits
        ]
        gaps := [8, 24, 8, 24, 8]
        totalW := 0

        for control in controls {
            control.GetPos(&oldX, &oldY, &controlW, &controlH)
            totalW += controlW
        }
        for gap in gaps
            totalW += gap

        x := Floor((this.guiW - totalW) / 2)

        for index, control in controls {
            control.GetPos(&oldX, &oldY, &controlW, &controlH)
            control.Move(x, oldY)
            x += controlW
            if (index <= gaps.Length)
                x += gaps[index]
        }

        WinRedraw(this.textGui.Hwnd)
    }

    static Update(state) {
        ; 1. Power CZ 에서 타이틀 상태일때, 함선무기를 전개하면 미터기를 시작
        if (this._visibleiState == "title" && state.isHardpointsDeployed && this._isRunning == false) {
            this.StartMeritsMeter(state)
        }
        ; 2. 미터기가 작동중일때, Power CZ 를 벗아나면 기록을 저장하고 종료
        else if (this._visibleiState == "counter" && state.currentState != "PowerCZ" && state.powerStartTimeMarker != "") {
            this.ResetMeritsMeter(state)
        }

        if (this._isRunning) {
            if (this._lastTickCount == 0)
                this._lastTickCount := A_TickCount

            state.powerElapsedSeconds += (A_TickCount - this._lastTickCount) / 1000
            this._lastTickCount := A_TickCount
        }

        this.UpdateDisplay(state)
        this.UpdateMetrics(state)
    }

    static UpdateDisplay(state) {
        if (state.currentState == "PowerCZ") {
            this.Show()
            if (state.powerStartTimeMarker == "")
                this.ShowTitleOnly()
            else
                this.ShowCounterOnly()
        }
        ; 2. Power CZ 외부이지만, 타이머가 '실행 중(isRunning)'인 경우에만 유지
        else if (this._isRunning) {
            this.Show()
            this.ShowCounterOnly()
        }
        ; 3. 그 외 (Power CZ 외부 + 타이머 정지/리셋 상태) -> 숨김
        else {
            this.Hide()
        }
    }

    static Show() {

        ; this.bgGui.Show("x" . this.posX . " y" . this.posY . " w" . this.guiW . " h" . this.guiH . " NoActivate")
        this.textGui.Show("x" . this.posX . " y" . this.posY . " w" . this.guiW . " h" . this.guiH . " NoActivate")
    }

    static Hide() {

        if (this._visibleiState != "") {
            ; this.bgGui.Hide()
            this.textGui.Hide()

            this._visibleiState := ""
        }
    }

    static ShowTitleOnly() {
        if (this._visibleiState != "title") {
            this.textCzTitle.Visible := true
            this.lblTime.Visible := false, this.valTime.Visible := false
            this.lblKills.Visible := false, this.valKills.Visible := false
            this.lblMerits.Visible := false, this.valMerits.Visible := false
            WinRedraw(this.textGui.Hwnd)

            this._visibleiState := "title"
        }
    }

    static ShowCounterOnly() {
        if (this._visibleiState != "counter") {
            this.textCzTitle.Visible := false
            this.lblTime.Visible := true, this.valTime.Visible := true
            this.lblKills.Visible := true, this.valKills.Visible := true
            this.lblMerits.Visible := true, this.valMerits.Visible := true
            WinRedraw(this.textGui.Hwnd)

            this._visibleiState := "counter"
        }
    }

    static UpdateMetrics(state) {
        Critical
        if (state.powerStartTimeMarker == "")
            return

        mins := Floor(state.powerElapsedSeconds / 60)
        secs := Mod(state.powerElapsedSeconds, 60)
        this.valTime.Value := Format("{1:02d}:{2:02d}", mins, secs)

        isChanged := false

        if (this._lastKills != state.powerKills) {
            SetTextAndResize(this.valKills, FormatNumber(state.powerKills))
            ; this.valKills.Value := Format("{1}", state.powerKills)
            this._lastKills := state.powerKills
            isChanged := true
        }

        if (this._lastMerits != state.powerMerits) {
            SetTextAndResize(this.valMerits, FormatNumber(state.powerMerits))
            ; this.valMerits.Value := Format("{1}", state.powerMerits)
            this._lastMerits := state.powerMerits
            isChanged := true
        }

        if (isChanged)
            this.CenterMetrics()
    }

    ; --- 메리트 미터기 시작 / 일시정지
    static StartMeritsMeter(state) {
        if (state.currentState != "PowerCZ")
            return

        if (!this._isRunning) {
            if (state.powerStartTimeMarker == "")
                state.powerStartTimeMarker := A_NowUTC
            this._isRunning := true
            SoundBeep(1200, 100)
        } else {
            this._isRunning := false
            SoundBeep(800, 100)
        }
        this.Update(state)
    }

    ; --- 메리트 미터기 리셋
    static ResetMeritsMeter(state) {
        if (state.currentState != "PowerCZ" && state.powerStartTimeMarker == "")
            return

        if (state.powerMerits > 0 && state.powerKills > 0 && state.powerLastKillTime > 0)
            Logger.SaveLogToJSON(state)


        this._isRunning := false
        this._lastKills := -1
        this._lastMerits := -1
        this._lastTickCount := 0

        state.ResetCZMetrics()
        SoundBeep(500, 100)

        this.Update(state)
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
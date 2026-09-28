#Requires AutoHotkey v2.0

class PowerCzOverlayGui {
    static bgGui := unset
    static textGui := unset
    static textCzTitle := unset
    static lblTime := unset
    static valTime := unset
    static lblKills := unset
    static valKills := unset
    static lblMerits := unset
    static valMerits := unset
    static posX := 0, posY := 0, guiW := 0, guiH := 0

    static Init(px, py, w, h) {
        this.posX := px, this.posY := py, this.guiW := w, this.guiH := h

        this.bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Cz_BG")
        this.bgGui.BackColor := "000000"
        WinSetTransparent(140, this.bgGui)

        this.textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +0x02000000", "ED_Cz_Text")
        this.textGui.BackColor := "000001"
        WinSetTransColor("000001 255", this.textGui)

        this.textGui.SetFont("s14 bold Q5", "Consolas")
        this.textCzTitle := this.textGui.Add("Text", "x0 y10 w" . w . " h" . h . " c0xffffff Center", "Power Conflict Zone")

        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblTime := this.textGui.Add("Text", "x70 y13", "TIME")
        this.textGui.SetFont("s14 w700 Q5 cWhite", "Segoe UI")
        this.valTime := this.textGui.Add("Text", "x+10 y8", "00:00")

        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblKills := this.textGui.Add("Text", "x170 y13", "KILLS")
        this.textGui.SetFont("s14 w700 Q5 cWhite", "Segoe UI")
        this.valKills := this.textGui.Add("Text", "x+10 y8", "999")
        this.valKills.Value := "0"

        this.textGui.SetFont("s10 w700 Q5 c00ffff", "Consolas")
        this.lblMerits := this.textGui.Add("Text", "x250 y13", "MERITS")
        this.textGui.SetFont("s14 w700 Q5 cWhite", "Segoe UI")
        this.valMerits := this.textGui.Add("Text", "x+10 y8", "99999")
        this.valMerits.Value := "0"

        this.Hide()
    }

    static UpdateDisplay(state) {
        if (state.currentState == "PowerCZ") {
            this.Show(state)
            if (state.startTimeMarker == "")
                this.ShowTitleOnly()
            else
                this.ShowCounterOnly()
        }
        ; 2. Power CZ 외부이지만, 타이머가 '실행 중(isRunning)'인 경우에만 유지
        else if (state.isRunning) {
            this.Show(state)
            this.ShowCounterOnly()
        }
        ; 3. 그 외 (Power CZ 외부 + 타이머 정지/리셋 상태) -> 숨김
        else {
            this.Hide(state)
        }
    }

    static Show(state := "") {
        if (IsObject(state))
            state.isCzOverlayVisible := true

        this.bgGui.Show("x" . this.posX . " y" . this.posY . " w" . this.guiW . " h" . this.guiH . " NoActivate")
        this.textGui.Show("x" . this.posX . " y" . this.posY . " w" . this.guiW . " h" . this.guiH . " NoActivate")
    }

    static Hide(state := "") {
        if (IsObject(state))
            state.isCzOverlayVisible := false

        this.bgGui.Hide()
        this.textGui.Hide()
    }

    static ShowTitleOnly() {
        this.textCzTitle.Visible := true
        this.lblTime.Visible := false, this.valTime.Visible := false
        this.lblKills.Visible := false, this.valKills.Visible := false
        this.lblMerits.Visible := false, this.valMerits.Visible := false
        WinRedraw(this.textGui.Hwnd)
    }

    static ShowCounterOnly() {
        this.textCzTitle.Visible := false
        this.lblTime.Visible := true, this.valTime.Visible := true
        this.lblKills.Visible := true, this.valKills.Visible := true
        this.lblMerits.Visible := true, this.valMerits.Visible := true
        WinRedraw(this.textGui.Hwnd)
    }

    static UpdateMetrics(state) {
        Critical
        if (state.startTimeMarker == "")
            return

        mins := Floor(state.elapsedSeconds / 60)
        secs := Mod(state.elapsedSeconds, 60)
        this.valTime.Value := Format("{1:02d}:{2:02d}", mins, secs)

        if (state.lastKills != state.totalKills) {
            this.valKills.Value := Format("{1}", state.totalKills)
            state.lastKills := state.totalKills
        }

        if (state.lastMerits != state.totalMerits) {
            this.valMerits.Value := Format("{1}", state.totalMerits)
            state.lastMerits := state.totalMerits
        }
    }
}


class Logger {
    static SaveLogToJSON(state) {
        logFilePath := A_ScriptDir . "\PowerCZ_Log.json"
        nowStr := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

        mins := Floor(state.elapsedSeconds / 60)
        secs := Mod(state.elapsedSeconds, 60)
        elapsedStr := Format("{1:02d}:{2:02d}", mins, secs)
        ppm := (state.elapsedSeconds > 0) ? Round((state.totalMerits / state.elapsedSeconds) * 60, 1) : 0.0

        startTotal := (state.initialTotalMerits > 0) ? state.initialTotalMerits : state.currentTotalMerits
        endTotal := state.currentTotalMerits

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
            nowStr, startTotal, endTotal, elapsedStr, state.totalKills, state.totalMerits, ppm
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
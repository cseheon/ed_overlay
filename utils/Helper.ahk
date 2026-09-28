#Requires AutoHotkey v2.0

FormatNumber(num) {
    return RegExReplace(num, "(\d)(?=(\d{3})+$)", "$1,")
}

ExtractJsonVal(json, key) {
    if RegExMatch(json, '"' . key . '":\s*"([^"]+)"', &m)
        return m[1]
    if RegExMatch(json, '"' . key . '":\s*\[\s*"([^"]+)"', &m)
        return m[1]
    return ""
}

ParseJournalTimestamp(isoStr) {
    cleanStr := RegExReplace(isoStr, "\D", "")
    return cleanStr != "" ? Number(cleanStr) : 0
}

SetTextAndResize(textCtrl, text) {
    Critical
    size := GetTextSize(textCtrl, text)
    ; textCtrl.Move(,, GetTextSize(textCtrl, text)*)
    textCtrl.Move(,, size*)
    textCtrl.Value := text
    WinRedraw(textCtrl.Gui.Hwnd)
    return size

    GetTextSize(textCtrl, text) {
        static WM_GETFONT := 0x0031, DT_CALCRECT := 0x400
        hDC := DllCall('GetDC', 'Ptr', textCtrl.Hwnd, 'Ptr')
        hPrevObj := DllCall('SelectObject', 'Ptr', hDC, 'Ptr', SendMessage(WM_GETFONT,,, textCtrl), 'Ptr')
        height := DllCall('DrawText', 'Ptr', hDC, 'Str', text, 'Int', -1, 'Ptr', buf := Buffer(16), 'UInt', DT_CALCRECT)
        width := NumGet(buf, 8, 'Int') - NumGet(buf, 'Int')
        DllCall('SelectObject', 'Ptr', hDC, 'Ptr', hPrevObj, 'Ptr')
        DllCall('ReleaseDC', 'Ptr', textCtrl.Hwnd, 'Ptr', hDC)
        return [Round(width * 96/A_ScreenDPI), Round(height * 96/A_ScreenDPI)]
    }
}
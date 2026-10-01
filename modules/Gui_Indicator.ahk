#Requires AutoHotkey v2.0

class IndicatorOverlayGui {
    static isShow := false

    static _textGui := unset
    static _items := []
    static _lastStates := Map()
    static _gap := 8
    static _width := 120
    static _height := 28
    static _backgroundAlpha := 140
    static _textDefaultColor := "404040"

    static _definitions := [
        { label: "DOCK", key: "isDocked", activeText: "00F5FF", activeBackground: "00434A" }, 
        { label: "GEAR", key: "isLandingGearDeployed", activeText: "C6FF00", activeBackground: "354A00" }, 
        { label: "SHIELD DOWN", key: "isShieldsDown", activeText: "FF1744", activeBackground: "4A0715" }, 
        { label: "FA OFF", key: "isFlightAssistOff", activeText: "FFFF00", activeBackground: "4A3D00" }, 
        { label: "HARDPOINTS", key: "isHardpointsDeployed", activeText: "FF6D00", activeBackground: "4A1E00" }, 
        { label: "CARGO", key: "isCargoScoopDeployed", activeText: "00B0FF", activeBackground: "00314A" }, 
        { label: "SILENT", key: "isSlientRunning", activeText: "FF00A8", activeBackground: "4A0030" }, 
        { label: "FUEL SCOOP", key: "isScoopingFuel", activeText: "00FF66", activeBackground: "004A25" }, 
        { label: "FSD COOL", key: "isFsdcooldown", activeText: "536DFF", activeBackground: "17245C" }, 
        { label: "LOW FUEL", key: "isLowFuel", activeText: "FF00CC", activeBackground: "4A003B" }, 
        { label: "OVERHEAT", key: "isOverheating", activeText: "FF3D00", activeBackground: "4A1000" }, 
        { label: "NIGHT VISION", key: "isNightVisionActive", activeText: "D4FF00", activeBackground: "394A00" }
    ]

    static Init(posY := 62) {
        screenW := A_ScreenWidth
        itemCount := this._definitions.Length
        itemW := Min(this._width, Floor((screenW - 32 - (itemCount - 1) * this._gap) / itemCount))
        totalW := itemCount * itemW + (itemCount - 1) * this._gap
        startX := Floor((screenW - totalW) / 2)

        this._textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Indicators_Text")
        this._textGui.BackColor := "000001"
        WinSetTransColor("000001 255", this._textGui)

        for index, item in this._definitions {
            x := startX + (index - 1) * (itemW + this._gap)

            bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Indicator_Background")
            bgGui.BackColor := "202020"
            WinSetTransparent(this._backgroundAlpha, bgGui)
            bgGui.Show(Format("x{} y{} w{} h{} NoActivate", x, posY, itemW, this._height))

            textControl := this._textGui.Add(
                "Text",
                Format("x{} y0 w{} h{} Center 0x200 BackgroundTrans", x, itemW, this._height),
                item.label
            )
            textControl.SetFont("s11 w700 Q5 c" . this._textDefaultColor, "Consolas")

            this._items.Push({
                bgGui: bgGui,
                control: textControl,
                key: item.key,
                activeText: item.activeText,
                activeBackground: item.activeBackground
            })
        }

        this._textGui.Show(Format("x0 y{} w{} h{} NoActivate", posY, screenW, this._height))
        this.isShow := true

        DllCall(
            "SetWindowPos",
            "Ptr", this._textGui.Hwnd,
            "Ptr", -1, ; HWND_TOPMOST
            "Int", 0, "Int", 0, "Int", 0, "Int", 0,
            "UInt", 0x13 ; SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOSIZE
        )
    }

    static Update(state) {
        isChanged := false

        for item in this._items {
            isActive := state.%item.key%

            if (this._lastStates.Has(item.key) && this._lastStates[item.key] == isActive)
                continue

            this._lastStates[item.key] := isActive
            foreground := isActive ? item.activeText : this._textDefaultColor
            background := isActive ? item.activeBackground : "000000"

            item.control.SetFont("c" . foreground, "Consolas")
            item.bgGui.BackColor := background
            WinRedraw(item.bgGui.Hwnd)
            isChanged := true
        }

        if (isChanged)
            WinRedraw(this._textGui.Hwnd)
    }

    static Show() {
        this.isShow := true
        for item in this._items {
            item.bgGui.Show("NoActivate")
        }
        this._textGui.Show("NoActivate")
    }

    static Hide() {
        this.isShow := false
        this._textGui.Hide()
        for item in this._items {
            item.bgGui.Hide()
        }
    }

}
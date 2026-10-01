; filepath: c:\Users\cseheon\Documents\AutoHotkey\ed_overlay\modules\Gui_NavRoute2.ahk
#Requires AutoHotkey v2.0

class NavRouteOverlayGui {
    static isShow := false

    static bgGui := unset
    static textGui := unset
    static lblTitle := unset
    static lblLeftJumps := unset
    static valLeftJumps := 0
    static lblFuel := unset
    static valFuel := 0
    static rowCtrls := []
    static posX := 0, posY := 0, guiW := 360, guiH := 0
    static finalDestination := ""

    static _lastJumps := -1
    static _lastFuel := -1

    static Init(w := 340) {
        this.guiW := w
        this.posX := A_ScreenWidth - w - 20

        this.bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Route2_BG")
        this.bgGui.BackColor := "000000"
        WinSetTransparent(160, this.bgGui)

        this.textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +0x02000000", "ED_Route2_Text")
        this.textGui.BackColor := "000001"
        WinSetTransColor("000001 255", this.textGui)

        this.textGui.SetFont("s10 bold Q5 c00ffff", "Consolas")
        this.lblTitle := this.textGui.Add("Text", "x15 y10 w135", "JUMP ROUTE")

        this.textGui.SetFont("s8 w700 Q5 cff7b00", "Consolas")
        this.lblLeftJumps := this.textGui.Add("Text", "x155 y12", "JUMPS LEFT")

        this.textGui.SetFont("s10 bold Q5 cffffff", "Consolas")
        this.valLeftJumps := this.textGui.Add("Text", "x+8 y10 w20", "99")

        this.textGui.SetFont("s8 w700 Q5 cff7b00", "Consolas")
        this.lblFuel := this.textGui.Add("Text", "x+15 y12", "FUEL")

        this.textGui.SetFont("s10 bold Q5 cffffff", "Consolas")
        this.valFuel := this.textGui.Add("Text", "x+8 y10 w20", "100%")

        this.Hide()
    }

    static Update(state) {
        if (!state.isRouteActive || state.navRoute.Length == 0) {
            this.Hide()
            return
        }

        this.finalDestination := state.finalDestination != "" ? state.finalDestination : "Unknown"

        visibleRoute := state.navRoute

        ; 현재 성계가 경로에 있으면 그 성계부터 표시
        currentIndex := 1
        for index, routeItem in state.navRoute {
            if (routeItem.starSystem = state.starSystem) {
                currentIndex := index
                break
            }
        }

        itemCount := visibleRoute.Length
        this.guiH := 38 + (itemCount * 24) + 10
        this.posY := (A_ScreenHeight - this.guiH) / 3

        hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0,
            "Int", this.guiW, "Int", this.guiH, "Int", 12, "Int", 12, "Ptr")
        DllCall("SetWindowRgn", "Ptr", this.bgGui.Hwnd, "Ptr", hRgn, "UInt", true)

        fuel := Round(state.currentFuelPct)
        jumps := Max(0, itemCount - currentIndex)

        if (jumps != this._lastJumps || fuel != this._lastFuel) {
            if (jumps != this._lastJumps)
                SetTextAndResize(this.valLeftJumps, jumps)

            if (fuel != this._lastFuel) {
                SetTextAndResize(this.valFuel, fuel . "%")
                color := LerpColor("cff3c00", "c9dff00", fuel / 100)
                hexColor := Format("c{:X}", color)
                this.valFuel.SetFont(hexColor)
            }

            right := this.guiW - 15

            this.lblFuel.GetPos(&x, &y, &labelW, &h)
            this.valFuel.GetPos(&x, &y, &valueW, &h)

            right -= valueW
            this.valFuel.Move(right)
            right -= 8 + labelW
            this.lblFuel.Move(right)
            right -= 15

            this.lblLeftJumps.GetPos(&x, &y, &labelW, &h)
            this.valLeftJumps.GetPos(&x, &y, &valueW, &h)

            right -= valueW
            this.valLeftJumps.Move(right)
            right -= 8 + labelW
            this.lblLeftJumps.Move(right)
            right -= 15

            this._lastJumps := jumps
            this._lastFuel := fuel
        }

        while (this.rowCtrls.Length < itemCount) {
            idx := this.rowCtrls.Length + 1
            rowY := 38 + ((idx - 1) * 24)

            this.textGui.SetFont("s10 bold Q5 cWhite", "Consolas")
            ctrlSystem := this.textGui.Add("Text", Format("x15 y{1} w245 0x4000", rowY), "")

            this.textGui.SetFont("s10 bold Q5 cWhite", "Consolas")
            ctrlDistance := this.textGui.Add("Text", Format("x240 y{1} w85 Right", rowY), "")

            this.rowCtrls.Push({ system: ctrlSystem, distance: ctrlDistance })
        }

        for index, item in visibleRoute {
            ctrls := this.rowCtrls[index]
            ctrls.system.Visible := true
            ctrls.distance.Visible := true
            ; ctrls.system.Value := (index == currentIndex ? "• " : "  ") . item.starSystem
            marker := index == currentIndex
                ? "• "
                : (this.IsFuelScoopable(item.starClass) ? "F " : "  ")
            ctrls.system.Value := marker . item.starSystem
            ctrls.distance.Value := index == currentIndex
                ? "HERE"
                : Format("{:.1f} ly", item.jumpDistance)

            ; 지나간 경로는 회색, 현재 성계는 노란색, 이후 경로는 흰색
            color := index < currentIndex
                ? "c888888"
                : (index == currentIndex ? "cYellow" : "cWhite")
            ctrls.system.SetFont(color)
            ctrls.distance.SetFont(color)
        }

        Loop (this.rowCtrls.Length - itemCount) {
            idx := itemCount + A_Index
            this.rowCtrls[idx].system.Visible := false
            this.rowCtrls[idx].distance.Visible := false
        }

        if (state.isOverlayVisible) {
            this.Show()
            WinRedraw(this.textGui.Hwnd)
        } else {
            this.Hide()
        }
    }

    static Show() {
        this.isShow := true
        this.bgGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this.posX, this.posY, this.guiW, this.guiH))
        this.textGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this.posX, this.posY, this.guiW, this.guiH))
    }

    static Hide() {
        this.isShow := false
        this.bgGui.Hide()
        this.textGui.Hide()
    }

    static RouteArrived(state) {
        if (this.finalDestination == state.finalDestination) {
            str := Format("[ " . this.finalDestination . " ] Arrived !!")
            ShowNotice(str)
        }
        this.Hide()
    }

    static IsFuelScoopable(starClass) {
        scoopableClasses := "|O|B|A|F|G|K|M|"
        return InStr(scoopableClasses, "|" . StrUpper(Trim(starClass)) . "|") > 0
    }
}
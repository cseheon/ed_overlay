#Requires AutoHotkey v2.0

class NavRouteOverlayGui {
    static bgGui := unset
    static textGui := unset
    static lblTarget := unset
    static lblSteps := unset
    static lblFuel := unset
    static posX := 0, posY := 0, basePosY := 20, guiW := 0, guiH := 0

    static Init(px, py, w, h, radius := 12) {
        this.posX := px, this.posY := py, this.basePosY := py, this.guiW := w, this.guiH := h

        ; 1. 배경 GUI (반투명 검은색 + 둥근 모서리)
        this.bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Nav_BG")
        this.bgGui.BackColor := "000000"
        WinSetTransparent(160, this.bgGui)

        hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", radius, "Int", radius, "Ptr")
        DllCall("SetWindowRgn", "Ptr", this.bgGui.Hwnd, "Ptr", hRgn, "UInt", true)

        ; 2. 텍스트 레이어 GUI
        this.textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +0x02000000", "ED_Nav_Text")
        this.textGui.BackColor := "000001"
        WinSetTransColor("000001 255", this.textGui)

        ; 레이아웃 구성: DEST | SEGMENTS (JUMPS) | FUEL
        this.textGui.SetFont("s10 bold Q5 c00ffff", "Consolas")
        this.textGui.Add("Text", "x15 y10", "DEST")
        this.textGui.SetFont("s11 bold Q5 cWhite", "Segoe UI")
        this.lblTarget := this.textGui.Add("Text", "x+8 y8 w150", "NONE")

        this.textGui.SetFont("s14 bold Q5 cffffff", "Consolas")
        this.lblSteps := this.textGui.Add("Text", "x+2 y8 w260 Center", "⚪ ⚪ ⚪ ⚪ ⚪ (0/0)")

        this.textGui.SetFont("s10 bold Q5 c00ffff", "Consolas")
        this.textGui.Add("Text", "x530 y10", "FUEL")
        this.textGui.SetFont("s12 bold Q5 c00ff00", "Segoe UI")
        this.lblFuel := this.textGui.Add("Text", "x+8 y8 w70", "100%")

        this.Hide()
    }

    static Update(state) {
        if (!state.isRouteActive || state.remainingJumps <= 0) {
            this.Hide()
            return
        }

        ; Power CZ 미터기가 화면에 표출 중이면 CZ 오버레이 아래(20 + 40 + 8 = 68)로 Y 좌표 변경
        targetY := state.isCzOverlayVisible ? (this.basePosY + 48) : this.basePosY

        ; 위치에 변경이 생긴 경우 GUI 이동 처리
        if (this.posY != targetY) {
            this.posY := targetY
        }

        this.Show()

        ; 1. 목적지 업데이트
        this.lblTarget.Value := state.finalDestination != "" ? state.finalDestination : "Unknown"

        ; 2. 세그먼트 스텝 시각화 텍스트 생성
        this.lblSteps.Value := this.BuildSegmentString(state.remainingJumps, state.totalJumps)

        ; 3. 연료 수치 및 경고 색상 적용
        this.lblFuel.Value := Format("{1:d}%", Round(state.currentFuelPct))

        if (state.currentFuelPct <= 25) {
            this.lblFuel.SetFont("cRed")
        } else if (state.currentFuelPct <= 50) {
            this.lblFuel.SetFont("cYellow")
        } else {
            this.lblFuel.SetFont("c00ff00")
        }

        WinRedraw(this.textGui.Hwnd)
    }

    ; 세그먼트 생성 로직
    static BuildSegmentString(remaining, total) {
        if (total <= 0)
            return "⚪ ⚪ ⚪ ⚪ ⚪ (0/0)"

        completed := total - remaining



        ; 총 점프 수가 10개 이하일 경우 시각적 블록 세그먼트 출력
        if (total <= 10) {
            str := ""
            Loop (completed) {
                str .= "⚪ "
            }
            str .= "🔴 "
            Loop remaining {
                str .= "⚪ "
            }

            return RTrim(str) . Format(" ({1}/{2})", remaining, total)
        } else {
            ; 10개 초과 시 단순 프로그레스 바 형태로 축약
            return Format("JUMPS: {1} LEFT ({2}/{3})", remaining, remaining, total)
        }
    }

    static Show() {
        this.bgGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this.posX, this.posY, this.guiW, this.guiH))
        this.textGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this.posX, this.posY, this.guiW, this.guiH))
    }

    static Hide() {
        this.bgGui.Hide()
        this.textGui.Hide()
    }

    static RouteArrived() {
        str := Format("[ " . this.lblTarget.Value . " ] Arrived !!")
        ShowNotice(str)
    }
}
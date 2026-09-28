#Requires AutoHotkey v2.0

class MissionStackOverlayGui {
    static bgGui := unset
    static textGui := unset
    static lblTitle := unset
    static lblTotal := unset
    static itemCtrls := []
    static posX := 0, posY := 0, guiW := 320, guiH := 0

    static Init(px := 0, py := 0, w := 320) {
        this.guiW := w
        ; X 좌표: 지정값이 없으면 화면 우측 끝에서 20px 안쪽
        this.posX := (px != 0) ? px : (A_ScreenWidth - w - 20)

        ; 1. 배경 GUI (반투명 검은색)
        this.bgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ED_Stack_BG")
        this.bgGui.BackColor := "000000"
        WinSetTransparent(160, this.bgGui)

        ; 2. 텍스트 레이어 GUI
        this.textGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +0x02000000", "ED_Stack_Text")
        this.textGui.BackColor := "000001"
        WinSetTransColor("000001 255", this.textGui)

        ; 헤더 컨트롤
        this.textGui.SetFont("s10 bold Q5 c00ffff", "Consolas")
        this.lblTitle := this.textGui.Add("Text", "x15 y10 w160", "MISSION STACK")

        this.textGui.SetFont("s10 bold Q5 cff7b00", "Consolas")
        this.lblTotal := this.textGui.Add("Text", "x180 y10 w125 Right", "TOTAL: 0")

        this.itemCtrls := []
        this.Hide()
    }

    static Update(state) {
        ; 스택 미션 데이터가 없거나 비활성화 시 숨김
        if (!state.isMissionStackActive || state.missionStack.Count == 0) {
            this.Hide()
            return
        }

        ; 1. 스택 데이터를 배열로 추출 및 내림차순 정렬 (남은 처치 수 기준)
        stackList := []
        totalLeft := 0
        maxKillsLeft := -1

        completedCount := 0
        totalCount := state.missionStack.Count

        for faction, data in state.missionStack {
            killsLeft := data.killsLeft
            
            if (killsLeft == 0)
                completedCount++
            
            if (killsLeft > maxKillsLeft)
                maxKillsLeft := killsLeft

            stackList.Push({ faction: faction, killsLeft: killsLeft })
        }

        ; 내림차순 정렬
        SortMissionStack(stackList)

        ; 2. 동적 높이 계산 (헤더 35px + 항목당 24px + 하단 여백 10px)
        itemCount := stackList.Length
        calculatedH := 35 + (itemCount * 24) + 10
        this.guiH := calculatedH
        this.posY := (A_ScreenHeight - calculatedH) / 2 ; 화면 우측 중앙 수직 정렬

        ; 배경 둥근 모서리 적용
        hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", this.guiW, "Int", this.guiH, "Int", 12, "Int", 12, "Ptr")
        DllCall("SetWindowRgn", "Ptr", this.bgGui.Hwnd, "Ptr", hRgn, "UInt", true)

        ; 완료 목록 수 / 총 목록 수 업데이트
        this.lblTotal.Value := Format("STACK: {1}/{2}", completedCount, totalCount)

        ; 3. 기존 라인 컨트롤 재활용 및 부족 시 추가 생성
        while (this.itemCtrls.Length < itemCount) {
            idx := this.itemCtrls.Length + 1
            currY := 35 + ((idx - 1) * 24)

            this.textGui.SetFont("s10 bold Q5 cWhite", "Segoe UI")
            ctrlFaction := this.textGui.Add("Text", Format("x15 y{1} w220 0x4000", currY), "")

            this.textGui.SetFont("s10 bold Q5 cWhite", "Consolas")
            ctrlKills := this.textGui.Add("Text", Format("x240 y{1} w65 Right", currY), "")

            this.itemCtrls.Push({ faction: ctrlFaction, kills: ctrlKills })
        }

        ; 4. 값 및 색상 업데이트
        for index, item in stackList {
            ctrls := this.itemCtrls[index]
            ctrls.faction.Visible := true
            ctrls.kills.Visible := true

            ctrls.faction.Value := "• " . item.faction
            ctrls.kills.Value := item.killsLeft

            ; 색상 적용 규칙
            ; - 0 (완료): 회색 (#888888)
            ; - 가장 많이 남은 수 (>0): 노란색 (#FFFF00)
            ; - 기타 진행 중: 흰색 (#FFFFFF)
            if (item.killsLeft == 0) {
                ctrls.faction.SetFont("c888888")
                ctrls.kills.SetFont("c888888")
            } else if (item.killsLeft == maxKillsLeft && maxKillsLeft > 0) {
                ctrls.faction.SetFont("cYellow")
                ctrls.kills.SetFont("cYellow")
            } else {
                ctrls.faction.SetFont("cWhite")
                ctrls.kills.SetFont("cWhite")
            }
        }

        ; 사용하지 않는 하단 컨트롤 숨김
        Loop (this.itemCtrls.Length - itemCount) {
            idx := itemCount + A_Index
            this.itemCtrls[idx].faction.Visible := false
            this.itemCtrls[idx].kills.Visible := false
        }

        this.Show()
        WinRedraw(this.textGui.Hwnd)
    }

    static Show() {
        this.bgGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this.posX, this.posY, this.guiW, this.guiH))
        this.textGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", this.posX, this.posY, this.guiW, this.guiH))
    }

    static Hide() {
        this.bgGui.Hide()
        this.textGui.Hide()
    }
}

; killsLeft 기준 내림차순 정렬 함수 (버블 정렬 방식)
SortMissionStack(arr) {
    loop arr.Length {
        i := A_Index
        loop arr.Length - i {
            j := A_Index
            if (arr[j].killsLeft < arr[j + 1].killsLeft) {
                temp := arr[j]
                arr[j] := arr[j + 1]
                arr[j + 1] := temp
            }
        }
    }
}
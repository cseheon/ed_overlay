#Requires AutoHotkey v2.0

class JournalParser {
    ; ObjBindMethod를 활용해 메서드의 호출 대상(JournalParser)을 미리 바인딩
    static Handlers := Map(
        "FSDJump", ObjBindMethod(JournalParser, "OnLocationEvent"),
        "Location", ObjBindMethod(JournalParser, "OnLocationEvent"),
        "Docked", ObjBindMethod(JournalParser, "OnDocked"),
        "Undocked", ObjBindMethod(JournalParser, "OnUndocked"),
        "SupercruiseDestinationDrop", ObjBindMethod(JournalParser, "OnSupercruiseDestinationDrop"),
        "SupercruiseExit", ObjBindMethod(JournalParser, "OnSupercruiseExit"),
        "Powerplay", ObjBindMethod(JournalParser, "OnPowerplayEvent"),
        "PowerplayMerits", ObjBindMethod(JournalParser, "OnPowerplayMerits"),
        "FactionKillBond", ObjBindMethod(JournalParser, "OnKillEvent"),
        "Bounty", ObjBindMethod(JournalParser, "OnKillEvent"),
        "Missions", ObjBindMethod(JournalParser, "OnMissions"),
        "MissionAccepted", ObjBindMethod(JournalParser, "OnMissionAccepted"),
        "MissionCompleted", ObjBindMethod(JournalParser, "OnMissionCompleted"),
        "MissionAbandoned", ObjBindMethod(JournalParser, "OnMissionEnded"),
        "ShipTargeted", ObjBindMethod(JournalParser, "OnShipTargeted"),
        "SupercruiseEntry", ObjBindMethod(JournalParser, "OnLeaveCZ"),
        "Died", ObjBindMethod(JournalParser, "OnLeaveCZ"),
        "ShieldState", ObjBindMethod(JournalParser, "OnShieldState"),
        "NavRoute", ObjBindMethod(JournalParser, "OnNavRouteUpdate"),
        "NavRouteClear", ObjBindMethod(JournalParser, "OnNavRouteClear"),
        "ReservoirComp", ObjBindMethod(JournalParser, "OnFuelUpdate")
    )

    static Parse(line, state) {
        ; 1. event 명 추출
        eventName := ExtractJsonVal(line, "event")
        if (eventName == "")
            return

        ; 2. 타임스탬프 파싱 (전투 미터기 카운팅 세션 필터링)
        logTimeNum := 0
        if RegExMatch(line, '"timestamp":"([^"]+)"', &timeMatch) {
            logTimeNum := ParseJournalTimestamp(timeMatch[1])
        }

        ; 3. 바인딩된 핸들러 실행 (정확히 3개의 인자 전달)
        if JournalParser.Handlers.Has(eventName) {
            JournalParser.Handlers[eventName](line, state, logTimeNum)
        }
    }

    ; --- 미션 관련 이벤트 파싱 ---

    ; 최초 미션 목록 수집 (게임 접속 시)
    static OnMissions(line, state, logTimeNum) {
        ; Active 미션 정보를 파싱하여 킬 미션 스택 갱신
        ; 저널의 Active 미션 배열 구조 파싱
        state.missionStack.Clear()

        pos := 1
        while (pos := RegExMatch(line, '\{"MissionID":(\d+),"Name":"([^"]+)".*?"Faction":"([^"]+)"', &m, pos)) {
            missionID := m[1]
            missionName := m[2]
            faction := m[3]
            pos += m.Len

            ; 해적/전투 처치 미션인지 확인
            if (InStr(missionName, "Kill") || InStr(missionName, "Massacre")) {
                kills := 0
                if RegExMatch(line, '"KillCount":(\d+)', &kMatch) {
                    kills := Integer(kMatch[1])
                }
                JournalParser.AddMissionToStack(state, faction, missionID, kills)
            }
        }
    }

    ; 신규 미션 수락
    static OnMissionAccepted(line, state, logTimeNum) {
        name := ExtractJsonVal(line, "Name")
        if (InStr(name, "Kill") || InStr(name, "Massacre") || InStr(line, "KillCount")) {
            faction := ExtractJsonVal(line, "Faction")
            missionID := ExtractJsonVal(line, "MissionID")

            kills := 0
            if RegExMatch(line, '"KillCount":(\d+)', &kMatch)
                kills := Integer(kMatch[1])

            if (faction != "" && missionID != "") {
                JournalParser.AddMissionToStack(state, faction, missionID, kills)
            }
        }
    }

    ; 미션 완료 및 포기 처리
    static OnMissionCompleted(line, state, logTimeNum) {
        JournalParser.OnMissionEnded(line, state, logTimeNum)
    }

    static OnMissionEnded(line, state, logTimeNum) {
        missionID := ExtractJsonVal(line, "MissionID")
        if (missionID == "")
            return

        for faction, data in state.missionStack {
            if data.missions.Has(missionID) {
                data.missions.Delete(missionID)
                JournalParser.RecalculateFactionStack(state, faction)
                break
            }
        }
    }

    ; 적 처치 발생 시 스택 차감 (Bounty 및 FactionKillBond 공유)
    static OnKillEvent(line, state, logTimeNum) {
        ; 기존 FactionKillBond 처리 로직 수행
        if InStr(line, "FactionKillBond") {
            if (state.currentState != "PowerCZ") {
                state.currentState := "PowerCZ"
            }
            if (state.enemyFaction == "") {
                victim := ExtractJsonVal(line, "VictimFaction")
                if (victim != "")
                    state.enemyFaction := victim
            }
            if (state.startTimeMarker != "") {
                startNum := ParseJournalTimestamp(state.startTimeMarker)
                if (logTimeNum >= startNum)
                    state.totalKills++
            }
        }

        ; 미션 스택 처치 수 차감 (각 팩션별로 진행 중인 미션 중 하나에서 1씩 차감)
        for faction, data in state.missionStack {
            if (data.killsLeft > 0) {
                for mID, kLeft in data.missions {
                    if (kLeft > 0) {
                        data.missions[mID] := kLeft - 1
                        JournalParser.RecalculateFactionStack(state, faction)
                        break
                    }
                }
            }
        }
    }

    ; 헬퍼 함수: 미션 추가 및 재계산
    static AddMissionToStack(state, faction, missionID, kills) {
        if (!state.missionStack.Has(faction)) {
            state.missionStack[faction] := { killsLeft: 0, missions: Map() }
        }
        state.missionStack[faction].missions[missionID] := kills
        JournalParser.RecalculateFactionStack(state, faction)
    }

    static RecalculateFactionStack(state, faction) {
        if (!state.missionStack.Has(faction))
            return

        data := state.missionStack[faction]
        maxKills := 0
        ; 미션 스택 정렬 방식: 팩션 내 가장 많이 남은 미션 수량을 해당 팩션의 남아있는 처치 수로 반영
        for mID, kLeft in data.missions {
            if (kLeft > maxKills)
                maxKills := kLeft
        }
        data.killsLeft := maxKills
    }

    ; --- 추가: 방어막 상태 변경 핸들러 ---
    static OnShieldState(line, state, logTimeNum) {
        ; ShieldsUp 값이 true/false 인지 판별
        if RegExMatch(line, '"ShieldsUp":\s*(true|false)', &shieldMatch) {
            isUp := (shieldMatch[1] == "true")

            ; On -> Off 로 전환된 순간에만 경고 작동
            if (state.isShieldUp && !isUp) {
                state.isShieldWarningActive := true
                ShieldWarningGui.Show()
            }

            state.isShieldUp := isUp
        }
    }

    ; --- 이벤트별 독립 핸들러 (순수하게 필요한 3개 인자만 수신) ---

    ; FSD 점프 시 남은 점프 수 차감 및 도착 시 GUI 숨김 처리
    static OnLocationEvent(line, state, logTimeNum) {
        state.starSystem := ExtractJsonVal(line, "StarSystem")
        state.powerName := ExtractJsonVal(line, "Powers")
        state.powerState := ExtractJsonVal(line, "PowerplayState")
        state.stationName := "Unknown"
        state.czBodyName := "Unknown"

        if (state.currentState != "PowerCZ")
            state.currentState := "System"

        ; 점프 성공 시 남은 점프 수 차감
        if (state.isRouteActive && state.remainingJumps > 0) {
            state.remainingJumps--

            ; 목적지 도착 완료 시 경로 UI 종료
            if (state.remainingJumps <= 0) {
                state.isRouteActive := false
                state.remainingJumps := 0

                NavRouteOverlayGui.RouteArrived()
            }
        }

        if RegExMatch(line, '"FuelLevel":([\d\.]+)', &fuelMatch) {
            state.currentFuelPct := Number(fuelMatch[1]) * 100 / 32.0
        }
    }

    ; NavRoute 발생 시 파일 다시 읽어 설정
    static OnNavRouteUpdate(line, state, logTimeNum) {
        JournalReader.ReadNavRouteFile(state)
    }

    ; 경로 명시적 취소 이벤트(NavRouteClear) 감지 시 즉시 숨김
    static OnNavRouteClear(line, state, logTimeNum) {
        state.isRouteActive := false
        state.remainingJumps := 0
        state.finalDestination := "None"
    }

    static OnFuelUpdate(line, state, logTimeNum) {
        if RegExMatch(line, '"FuelMain":([\d\.]+)', &fuelMatch) {
            state.currentFuelPct := (Number(fuelMatch[1]) / 32.0) * 100
        }
    }

    static OnDocked(line, state, logTimeNum) {
        state.stationName := ExtractJsonVal(line, "StationName")
        state.currentState := "Docked"
    }

    static OnUndocked(line, state, logTimeNum) {
        state.currentState := "System"
    }

    static OnSupercruiseDestinationDrop(line, state, logTimeNum) {
        typeStr := ExtractJsonVal(line, "Type")
        if InStr(typeStr, "Warzone") || InStr(typeStr, "Powerplay") || InStr(line, "Power Conflict Zone") {
            state.currentState := "PowerCZ"
            state.enemyFaction := ""
        }
    }

    static OnSupercruiseExit(line, state, logTimeNum) {
        body := ExtractJsonVal(line, "Body")
        if (body != "") {
            state.czBodyName := body
        }

        if (InStr(body, "Conflict") || InStr(line, "ConflictZone") || InStr(line, "Powerplay")) {
            if (state.currentState != "PowerCZ") {
                state.currentState := "PowerCZ"
                state.enemyFaction := ""
            }
        }
    }

    static OnPowerplayMerits(line, state, logTimeNum) {
        if RegExMatch(line, '"TotalMerits":(\d+)', &totalMatch) {
            state.currentTotalMerits := Integer(totalMatch[1])
        }
        if (state.currentState != "PowerCZ") {
            state.currentState := "PowerCZ"
        }

        ; 세션 카운터 반영
        if (state.startTimeMarker != "") {
            startNum := ParseJournalTimestamp(state.startTimeMarker)
            if (logTimeNum >= startNum) {
                if RegExMatch(line, '"MeritsGained":(\d+)', &meritMatch) {
                    state.totalMerits += Integer(meritMatch[1])
                }
                if RegExMatch(line, '"TotalMerits":(\d+)', &totalMatch) {
                    parsedTotal := Integer(totalMatch[1])
                    if (state.initialTotalMerits == 0 && RegExMatch(line, '"MeritsGained":(\d+)', &gainedMatch)) {
                        state.initialTotalMerits := parsedTotal - Integer(gainedMatch[1])
                    }
                }
            }
        }
    }

    static OnPowerplayEvent(line, state, logTimeNum) {
        if RegExMatch(line, '"Merits":(\d+)', &totalMatch) {
            state.currentTotalMerits := Integer(totalMatch[1])
        }
    }

    static OnFactionKillBond(line, state, logTimeNum) {
        if (state.currentState != "PowerCZ") {
            state.currentState := "PowerCZ"
        }

        if (state.enemyFaction == "") {
            victim := ExtractJsonVal(line, "VictimFaction")
            if (victim != "")
                state.enemyFaction := victim
        }

        ; 세션 카운터 반영
        if (state.startTimeMarker != "") {
            startNum := ParseJournalTimestamp(state.startTimeMarker)
            if (logTimeNum >= startNum) {
                state.totalKills++
            }
        }
    }

    static OnShipTargeted(line, state, logTimeNum) {
        if (state.currentState == "PowerCZ" && state.enemyFaction == "") {
            targetFaction := ExtractJsonVal(line, "Faction")
            if (targetFaction != "" && targetFaction != state.powerName)
                state.enemyFaction := targetFaction
        }
    }

    static OnLeaveCZ(line, state, logTimeNum) {
        if (state.currentState == "PowerCZ") {
            state.currentState := "System"
            state.enemyFaction := ""
            state.czBodyName := "Unknown"
        }
    }
}


class JournalReader {
    static fileObj := 0
    static lastSize := 0

    static FindLatestLogFile(logDir, state) {
        latestTime := 0
        latestLog := ""

        Loop Files, logDir . "\Journal.*.log" {
            if (A_LoopFileTimeModified > latestTime) {
                latestTime := A_LoopFileTimeModified
                latestLog := A_LoopFilePath
            }
        }
        if (latestLog != "")
            state.currentLogFile := latestLog
    }

    static ReadTask(logDir, state) {
        if (this.fileObj == 0) {
            if (state.currentLogFile == "")
                this.FindLatestLogFile(logDir, state)
            if (state.currentLogFile != "") {
                this.fileObj := FileOpen(state.currentLogFile, "r-d", "UTF-8")
                if (this.fileObj) {
                    while !this.fileObj.AtEOF {
                        line := this.fileObj.ReadLine()
                        if (line != "")
                            JournalParser.Parse(line, state)
                    }
                    this.lastSize := this.fileObj.Length
                }
            }
            return
        }

        if (this.fileObj.Length > this.lastSize) {
            while !this.fileObj.AtEOF {
                line := this.fileObj.ReadLine()
                if (line != "")
                    JournalParser.Parse(line, state)
            }
            this.lastSize := this.fileObj.Length
        }
    }

    static ReadNavRouteFile(state) {
        navFilePath := RegExReplace(state.currentLogFile, "Journal\..*$", "NavRoute.json")
        if (!FileExist(navFilePath)) {
            state.isRouteActive := false
            state.remainingJumps := 0
            return
        }

        try {
            jsonText := FileRead(navFilePath, "UTF-8")

            ; Route 배열 존재 여부 및 성계 탐색
            if InStr(jsonText, '"Route"') {
                matches := []
                pos := 1
                while (pos := RegExMatch(jsonText, '"StarSystem":"([^"]+)"', &m, pos)) {
                    matches.Push(m[1])
                    pos += m.Len
                }

                ; 경로 성계가 2개 이상일 때만 활성화 (현재 위치 + 최소 1개 이상의 목적지)
                if (matches.Length > 1) {
                    state.finalDestination := matches[matches.Length] ; 배열의 마지막 성계가 최종 목적지
                    state.totalJumps := matches.Length - 1            ; 현재 성계 제외 남은 점프 수
                    state.remainingJumps := state.totalJumps
                    state.isRouteActive := true
                } else {
                    ; 경로 내 성계가 1개 이하이거나 취소된 경우 (경로 삭제)
                    state.isRouteActive := false
                    state.remainingJumps := 0
                    state.finalDestination := "None"
                }
            } else {
                ; Route 항목이 없는 경우
                state.isRouteActive := false
                state.remainingJumps := 0
                state.finalDestination := "None"
            }
        } catch {
            ; 파일 읽기 실패 시 경로 비활성화
            state.isRouteActive := false
            state.remainingJumps := 0
        }
    }
}

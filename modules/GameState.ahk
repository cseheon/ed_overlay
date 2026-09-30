#Requires AutoHotkey v2.0

/*
; --- 시스템 정보  (FSDJump 이벤트) ---
{
  "timestamp": "2026-09-30T00:00:00Z",
  "event": "FSDJump",
  "StarSystem": "Fintamkina",
  "SystemAddress": 3932283483921,
  "StarPos": [ 10.25000, -42.12500, 50.81250 ],
  "SystemAllegiance": "Empire",
  "SystemEconomy": "$economy_Refinery;",
  "SystemSecondEconomy": "$economy_Industrial;",
  "SystemGovernment": "$government_Patronage;",
  "SystemSecurity": "$SYSTEM_SECURITY_medium;",
  "Population": 1284000,
  "PowerplayState": "Unoccupied",
  "Powers": [ "Denton Patreus" ],
  "JumpDist": 14.285
}
*/


class GameState {
    ; --- 시스템 및 저널 상태 ---
    currentLogFile := ""
    currentState := "" ; System / Docked / PowerCZ

    ; --- 시스템 정보 상태 ---
    starSystem := "Unknown"
    systemPower := ""
    systemPowerState := ""
    systemFactionName := ""
    systemFactionState := ""
    systemGovernment := ""
    systemAllegiance := ""
    systemSecurity := ""
    systemEconomy := ""
    systemPopulation := 0
    
    ; --- 현재 상태 정보 ---
    totalCredits := 0                   ; 보유한 총 크레딧 수 (StatusReader에서 갱신)
    totalMerits := 0                    ; 보유한 총 Merit 수 (JournalReader에서 갱신)
    dockedStationName := ""             ; Docked 상태에서 도킹한 스테이션 이름 (JournalReader에서 갱신)
    isHardpointsDeployed := false       ; 함선무기 전개/수납 여부
    currentFuel := 0.0                  ; 현재 주 연료량(톤)
    maxFuel := 0.0                      ; 주 연료탱크 최대 용량(톤)
    currentFuelPct := 0.0               ; 현재 연료 비율(%)

    ; --- 방어막(Shield) 상태 및 경고 타이머 ---
    isShieldUp := true
    isShieldWarningActive := false


    ; --- Power CZ 미터기 상태 ---
    powerStartTimeMarker := ""  ; Power CZ 시작 시간 (UTC 문자열)
    powerElapsedSeconds := 0    ; Power CZ 경과 시간
    powerLastKillTime := 0      ; Power CZ 마지막으로 적을 처치한 시간
    powerBodyName := ""         ; Power CZ 진행 중인 Conflict Zone의 celestial body 이름 (JournalReader에서 갱신)
    powerKills := 0             ; Power CZ 진행 중에 갱신되는 Kills 수 (JournalReader에서 갱신)
    powerMerits := 0            ; Power CZ 진행 중에 갱신되는 Merit 수 (JournalReader에서 갱신)
    powerInitTotalMerits := 0   ; Power CZ 시작 시점의 총 Merit 수 (시작 시점의 TotalMerits)
    powerEnemyFaction := ""     ; Power CZ 상대 세력

    ; --- Mission Stack 상태 추가 ---
    isMissionStackActive := true
    ; Structure: missionStack["FactionName"] := { killsLeft: 12, missions: Map(missionID, kills) }
    missionStack := Map()

    ; --- NavRoute (항로 정보) 상태 ---
    finalDestination := ""
    totalJumps := 0
    remainingJumps := 0
    isRouteActive := false
    navRoute := [] ; [{ starSystem: "", jumpDistance: 0 }, ...]

    ; --- Misstion Stack
    isStackOverlayVisible := true
    totalActiveMissions := 0
    missionStackData := [] ; [{ factionName: "", killsLeft: 0 }, ...]

    ResetCZMetrics() {
        this.powerStartTimeMarker := ""
        this.powerElapsedSeconds := 0
        this.powerLastKillTime := 0
        this.powerBodyName := "Unknown"
        this.powerKills := 0
        this.powerMerits := 0
        this.powerInitTotalMerits := 0
        this.powerEnemyFaction := ""
    }
}
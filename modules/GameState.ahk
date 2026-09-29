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
    
    ; --- 커맨더 상태 정보 ---
    totalCredits := 0                   ; 보유한 총 크레딧 수 (StatusReader에서 갱신)
    totalMerits := 0                    ; 보유한 총 Merit 수 (JournalReader에서 갱신)
    dockedStationName := ""             ; Docked 상태에서 도킹한 스테이션 이름 (JournalReader에서 갱신)

    ; --- 방어막(Shield) 상태 및 경고 타이머 ---
    isShieldUp := true
    isShieldWarningActive := false


    ; --- Power CZ 미터기 상태 ---
    isCzOverlayVisible := false
    isRunning := false
    startTimeMarker := ""
    elapsedSeconds := 0
    powerBodyName := ""         ; Power CZ 진행 중인 Conflict Zone의 celestial body 이름 (JournalReader에서 갱신)
    powerKills := 0             ; Power CZ 진행 중에 갱신되는 Kills 수 (JournalReader에서 갱신)
    powerMerits := 0            ; Power CZ 진행 중에 갱신되는 Merit 수 (JournalReader에서 갱신)
    powerInitTotalMerits := 0   ; Power CZ 시작 시점의 총 Merit 수 (시작 시점의 TotalMerits)
    enemyFaction := ""

    ; --- Mission Stack 상태 추가 ---
    isMissionStackActive := true
    ; Structure: missionStack["FactionName"] := { killsLeft: 12, missions: Map(missionID, kills) }
    missionStack := Map()

    ; --- NavRoute (항로 정보) 상태 ---
    finalDestination := "None"
    totalJumps := 0
    remainingJumps := 0
    currentFuelPct := 100.0
    isRouteActive := false

    ; --- Misstion Stack
    isStackOverlayVisible := true
    totalActiveMissions := 0
    missionStackData := [] ; [{ factionName: "", killsLeft: 0 }, ...]

    ; CZ 미터기 측정 리셋
    ResetCZMetrics() {
        this.isRunning := false
        this.elapsedSeconds := 0
        this.powerBodyName := "Unknown"
        this.powerKills := 0
        this.powerMerits := 0
        this.powerInitTotalMerits := 0
        this.startTimeMarker := ""
    }
}
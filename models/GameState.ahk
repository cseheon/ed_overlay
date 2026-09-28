#Requires AutoHotkey v2.0

class GameState {
    ; --- 시스템 및 저널 상태 ---
    currentLogFile := ""
    currentState := "" ; System / Docked / PowerCZ

    starSystem := "Unknown"
    powerName := ""
    powerState := ""
    stationName := "Unknown"
    enemyFaction := ""
    czBodyName := "Unknown"

    ; --- 방어막(Shield) 상태 및 경고 타이머 ---
    isShieldUp := true
    isShieldWarningActive := false
    shieldWarningTicks := 0

    ; --- Power CZ 미터기 상태 ---
    isRunning := false
    startTimeMarker := ""
    elapsedSeconds := 0
    totalKills := 0
    totalMerits := 0
    initialTotalMerits := 0
    currentTotalMerits := 0

    ; --- Dirty Flag (이전 프레임 비교용) ---
    lastState := ""
    lastSystem := ""
    lastStation := ""
    lastTotalMerits := -1
    lastPower := ""
    lastPowerState := ""
    lastEnemy := ""
    lastCzBody := ""
    lastKills := -1
    lastMerits := -1

    ; --- NavRoute (항로 정보) 상태 ---
    finalDestination := "None"
    totalJumps := 0
    remainingJumps := 0
    currentFuelPct := 100.0
    isRouteActive := false

    ; CZ 미터기 측정 리셋
    ResetCZMetrics() {
        this.isRunning := false
        this.elapsedSeconds := 0
        this.totalKills := 0
        this.totalMerits := 0
        this.initialTotalMerits := 0
        this.currentTotalMerits := 0
        this.startTimeMarker := ""
        this.lastKills := -1
        this.lastMerits := -1
    }
}
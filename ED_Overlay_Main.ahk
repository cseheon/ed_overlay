#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

; --- 모듈 로드 ---
#Include "modules/Helper.ahk"
#Include "modules/Gui_Notification.ahk"
#Include "modules/GameState.ahk"
#Include "modules/StatusReader.ahk"
#Include "modules/Gui_Status.ahk"
#Include "modules/Gui_PowerCZ.ahk"
#Include "modules/Gui_ShieldWarning.ahk"
#Include "modules/Gui_NavRoute.ahk"
#Include "modules/Gui_MissionStack.ahk"
#Include "modules/JournalReader.ahk"


; --- 설정 및 단일 상태 인스턴스 생성 ---
iniPath := A_ScriptDir . "\config.ini"
defaultLogDir := EnvGet("USERPROFILE") . "\Saved Games\Frontier Developments\Elite Dangerous"

global AppState := GameState()
global LogDir := IniRead(iniPath, "Settings", "LogDir", defaultLogDir)
if (LogDir == "")
    LogDir := defaultLogDir

readInterval := Integer(IniRead(iniPath, "Settings", "ReadIntervalMs", "200"))
uiInterval := Integer(IniRead(iniPath, "Settings", "UiIntervalMs", "1000"))

; --- GUI 레이아웃 좌표 초기화 ---
pos1X := 0      ; Integer(IniRead(iniPath, "GuiStatus", "X", "0"))
pos1Y := Integer(IniRead(iniPath, "GuiStatus", "Y", "20"))
gui1W := A_ScreenWidth      ; gui1W := Integer(IniRead(iniPath, "GuiStatus", "Width", "800"))
gui1H := Integer(IniRead(iniPath, "GuiStatus", "Height", "40"))
StatusOverlayGui.Init(pos1X, pos1Y, gui1W, gui1H)

gui2W := Integer(IniRead(iniPath, "GuiPowerCZ", "Width", "400"))
gui2H := Integer(IniRead(iniPath, "GuiPowerCZ", "Height", "40"))
pos2X := (A_ScreenWidth - gui2W) / 2
pos2Y := Integer(IniRead(iniPath, "GuiPowerCZ", "Y", "20"))
PowerCzOverlayGui.Init(pos2X, pos2Y, gui2W, gui2H)

; 방어막 경고 패널 초기화
ShieldWarningGui.Init(iniPath)

; 점프 경로 GUI 위치 및 너비 설정 (상단 중앙) ---
guiNavW := Integer(IniRead(iniPath, "GuiNavRoute", "Width", "620"))
guiNavH := Integer(IniRead(iniPath, "GuiNavRoute", "Height", "38"))
posNavX := (A_ScreenWidth - guiNavW) / 2
posNavY := Integer(IniRead(iniPath, "GuiNavRoute", "Y", "20")) ; 화면 맨 상단 약간 아래
NavRouteOverlayGui.Init(posNavX, posNavY, guiNavW, guiNavH)

; 미션 스택 GUI 초기화 (우측 중앙 자동 배치) ---
MissionStackOverlayGui.Init()

; --- 첫 렌더링 및 저널 스캔 ---
StatusOverlayGui.Update(AppState)
JournalReader.FindLatestLogFile(LogDir, AppState)

Voice.Init()

; --- 타이머 등록 ---
SetTimer(OnLogTimer, readInterval)
SetTimer(OnUiTimer, uiInterval)

OnLogTimer() {
    JournalReader.ReadTask(LogDir, AppState)
    StatusReader.ReadTask(LogDir, AppState)
}

OnUiTimer() {
    if (AppState.isRunning) {
        AppState.elapsedSeconds++
    }

    StatusOverlayGui.Update(AppState)
    
    ; 1. CZ 오버레이 상태 판단 및 표시 여부(isCzOverlayVisible) 먼저 업데이트
    PowerCzOverlayGui.UpdateDisplay(AppState)
    PowerCzOverlayGui.UpdateMetrics(AppState)
    
    ; 2. CZ 표시 상태에 따라 Y 위치를 계산하여 점프 경로 오버레이 업데이트
    NavRouteOverlayGui.Update(AppState)

    MissionStackOverlayGui.Update(AppState)
}


; ==============================================================================
; 단축키 바인딩
; ==============================================================================

; Win + F5 : 시작 / 일시정지
#F5::
{
    if (AppState.currentState != "PowerCZ")
        return

    if (!AppState.isRunning) {
        if (AppState.startTimeMarker == "")
            AppState.startTimeMarker := A_NowUTC
        AppState.isRunning := true
        SoundBeep(1200, 100)
    } else {
        AppState.isRunning := false
        SoundBeep(800, 100)
    }
    PowerCzOverlayGui.UpdateDisplay(AppState)
}

; Win + F6 : 전체 리셋 및 로그 저장
#F6::
{
    if (AppState.currentState != "PowerCZ" && AppState.startTimeMarker == "")
        return
    
    if (AppState.totalMerits > 0)
        Logger.SaveLogToJSON(AppState)

    AppState.ResetCZMetrics()
    SoundBeep(500, 1000)

    ; CZ 오버레이 숨김 처리 후 점프 경로 위치 갱신
    PowerCzOverlayGui.UpdateDisplay(AppState)
    NavRouteOverlayGui.Update(AppState)
}

F7::
{
    ; TEST
    /*
    AppState.isShieldWarningActive := true
    ShieldWarningGui.Show()
    */

    StatusOverlayGui.Show()

    /*
    ; 1. 테스트 데이터 토글 (이미 활성화되어 있으면 초기화 후 숨김)
    if (AppState.missionStack.Count > 0) {
        AppState.missionStack.Clear()
        MissionStackOverlayGui.Update(AppState)
        ShowNotice("Mission Stack Test Cleared", 1500)
        return
    }

    ; 2. 더미 팩션 데이터 및 미션 수량 입력
    ; (노란색: 최대 잔여, 흰색: 진행 중, 회색: 완료/0)
    AppState.missionStack["Alpha Fornaces Co."] := { killsLeft: 12, missions: Map(101, 12) }
    AppState.missionStack["Jet Force Inc."] := { killsLeft: 8, missions: Map(102, 8) }
    AppState.missionStack["Defense Party of LHS 317"] := { killsLeft: 3, missions: Map(103, 3) }
    AppState.missionStack["Purple Mob Co."] := { killsLeft: 0, missions: Map(104, 0) }

    ; 3. GUI 즉시 갱신
    MissionStackOverlayGui.Update(AppState)
    ShowNotice("Mission Stack Test Loaded!", 2000)
    */
}

F8::
{
    ; TEST
    ; ShieldWarningGui.Hide()

    AppState.currentTotalMerits += 300

    ; StatusOverlayGui.Hide()
}

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
gui1H := Integer(IniRead(iniPath, "GuiStatus", "Height", "38"))
StatusOverlayGui.Init(pos1X, pos1Y, gui1W, gui1H)

gui2W := Integer(IniRead(iniPath, "GuiPowerCZ", "Width", "400"))
gui2H := Integer(IniRead(iniPath, "GuiPowerCZ", "Height", "38"))
pos2X := (A_ScreenWidth - gui2W) / 2
pos2Y := Integer(IniRead(iniPath, "GuiPowerCZ", "Y", "20"))
PowerCzOverlayGui.Init(pos2X, pos2Y, gui2W, gui2H)

; 방어막 경고 패널 초기화
guiW := Integer(IniRead(iniPath, "ShieldWarning", "Width", "400"))
guiH := Integer(IniRead(iniPath, "ShieldWarning", "Height", "40"))
posX := Integer(IniRead(iniPath, "ShieldWarning", "X", (A_ScreenWidth - guiW) / 2))
posY := Integer(IniRead(iniPath, "ShieldWarning", "Y", A_ScreenWidth / 7))
duration := Integer(IniRead(iniPath, "ShieldWarning", "Duration", "5"))
ShieldWarningGui.Init(posX, posY, guiW, guiH, duration)

; 점프 경로 GUI 위치 및 너비 설정 (우측 중앙 자동 배치) ---
NavRouteOverlayGui.Init()

; 미션 스택 GUI 초기화 (좌측 중앙 자동 배치) ---
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
    StatusOverlayGui.Update(AppState)
    PowerCzOverlayGui.Update(AppState)
    NavRouteOverlayGui.Update(AppState)
    MissionStackOverlayGui.Update(AppState)
}


; ==============================================================================
; 단축키 바인딩
; ==============================================================================

; Win + F5 : Power CZ 시작 / 일시정지
#F5::
{
    ; Power CZ 오버레이 시작 / 일시정지
    PowerCzOverlayGui.StartMeritsMeter(AppState)
}

; Win + F6 : PowerCZ 전체 리셋 
#F6::
{
    ; Power CZ 오버레이 리셋
    PowerCzOverlayGui.ResetMeritsMeter(AppState)
}


F7::
{
    ; --- TEST: 미션 스택 오버레이 테스트 데이터 로드 ---
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
}

F8::
{
    ; --- TEST: 점프 경로 오버레이 테스트 데이터 로드 ---
    if (AppState.isRouteActive) {
        AppState.isRouteActive := false
        AppState.remainingJumps := 0
        AppState.finalDestination := "None"

        NavRouteOverlayGui.Update(AppState)
        ShowNotice("Jump Route Test Cleared", 1500)
        return
    }

    AppState.starSystem := "Wolf 359"
    AppState.totalJumps := 7
    AppState.isRouteActive := true
    AppState.finalDestination := "Ross 154"

    AppState.navRoute := [
        { starSystem: "Sol", jumpDistance: 0 },
        { starSystem: "Alpha Centauri", jumpDistance: 4.3 },
        { starSystem: "Barnard's Star", jumpDistance: 5.96 },
        { starSystem: "Wolf 359", jumpDistance: 7.78 },
        { starSystem: "Lalande 21185", jumpDistance: 8.31 },
        { starSystem: "Sirius", jumpDistance: 8.6 },
        { starSystem: "Luyten 726-8", jumpDistance: 8.73 },
        { starSystem: "Ross 154", jumpDistance: 9.68 }
    ]
    NavRouteOverlayGui.Update(AppState)
    ShowNotice("Jump Route Test Loaded", 2000)
}

F9:: 
{
    ; --- TEST: Power CZ 메리트 미터기 
    ; AppState.currentState := "PowerCZ"

    ShieldWarningGui.Show()
}

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

; --- 모듈 로드 ---
#Include "modules/Helper.ahk"
#Include "modules/Gui_Notification.ahk"
#Include "modules/GameState.ahk"
#Include "modules/Gui_Status.ahk"
#Include "modules/Gui_NavRoute.ahk"
#Include "modules/Gui_MissionStack.ahk"
#Include "modules/Gui_Indicator.ahk"
#Include "modules/JournalReader.ahk"

; --- 설정 및 단일 상태 인스턴스 생성 ---
iniPath := A_ScriptDir . "\config.ini"
defaultLogDir := EnvGet("USERPROFILE") . "\Saved Games\Frontier Developments\Elite Dangerous"

global AppState := GameState()
global LogDir := IniRead(iniPath, "Settings", "LogDir", defaultLogDir)
if (LogDir == "")
    LogDir := defaultLogDir

readInterval := Integer(IniRead(iniPath, "Settings", "ReadIntervalMs", "200"))
uiInterval := Integer(IniRead(iniPath, "Settings", "UiIntervalMs", "500"))

; 메인 상태정보 GUI 초기화 (화면 상단)
StatusOverlayGui.Init(20)
; 점프 경로 오버레이 GUI 초기화 (우측 중앙 자동 배치)
NavRouteOverlayGui.Init()
; 미션 스택 GUI 초기화 (좌측 중앙 자동 배치)
MissionStackOverlayGui.Init()
; 인디케이터 GUI 초기화 (화면 하단)
IndicatorOverlayGui.Init(A_ScreenHeight - 40)
; 음성 모듈 초기화
Voice.Init()

; --- 첫 렌더링 및 저널 스캔 ---

JournalReader.FindLatestLogFile(LogDir, AppState)
StatusOverlayGui.Update(AppState)
StatusOverlayGui.Show()

; --- 타이머 등록 ---
OnLogTimer()
SetTimer(OnLogTimer, readInterval)

OnUiTimer()
SetTimer(OnUiTimer, uiInterval)

OnLogTimer() {
    JournalReader.ReadTask(LogDir, AppState)
    StatusReader.ReadTask(LogDir, AppState)
}

OnUiTimer() {
    StatusOverlayGui.Update(AppState)
    NavRouteOverlayGui.Update(AppState)
    MissionStackOverlayGui.Update(AppState)
    IndicatorOverlayGui.Update(AppState)
}


; ==============================================================================
; 단축키 바인딩
; ==============================================================================

; Win + F5 : Power CZ 시작 / 일시정지
#F5::
{
    ; Power CZ 오버레이 시작 / 일시정지
    StatusOverlayGui.StartPowerCZTimer(AppState)
}

; Win + F6 : PowerCZ 전체 리셋 
#F6::
{
    ; Power CZ 오버레이 리셋
    StatusOverlayGui.ResetPowerCZTimer(AppState)
}


F7::
{
    ; --- TEST: 미션 스택 오버레이 테스트 데이터 로드 ---
    ; 1. 테스트 데이터 토글 (이미 활성화되어 있으면 초기화 후 숨김)
    if (AppState.missionStack.Count > 0) {
        AppState.missionStack.Clear()
        MissionStackOverlayGui.Update(AppState)
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
}

F8::
{
    ; --- TEST: 점프 경로 오버레이 테스트 데이터 로드 ---
    if (AppState.isRouteActive) {
        AppState.isRouteActive := false
        AppState.remainingJumps := 0
        AppState.finalDestination := "None"

        NavRouteOverlayGui.Update(AppState)
        return
    }

    AppState.starSystem := "Wolf 359"
    AppState.totalJumps := 7
    AppState.isRouteActive := true
    AppState.finalDestination := "Ross 154"

    AppState.navRoute := [
        { starSystem: "Sol", jumpDistance: 0, starClass: "A" },
        { starSystem: "Alpha Centauri", jumpDistance: 4.3, starClass: "G" },
        { starSystem: "Barnard's Star", jumpDistance: 5.96, starClass: "M" },
        { starSystem: "Wolf 359", jumpDistance: 7.78, starClass: "M" },
        { starSystem: "Lalande 21185", jumpDistance: 8.31, starClass: "M" },
        { starSystem: "Sirius", jumpDistance: 8.6, starClass: "A" },
        { starSystem: "Luyten 726-8", jumpDistance: 8.73, starClass: "M" },
        { starSystem: "Ross 154", jumpDistance: 9.68, starClass: "M" }
    ]
    NavRouteOverlayGui.Update(AppState)
}

F9:: 
{
   ShowWarning("Under Attack !", 1000, "함장님. 이 성계는 적세력이 점령중입니다. 주의가 필요합니다.")
}

F10::
{
    ; Voice.SpeakVoicesPeriodically()
}

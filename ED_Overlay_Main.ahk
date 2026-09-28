#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

; --- 모듈 로드 ---
#Include "utils/Helper.ahk"
#Include "modules/Gui_Notification.ahk"
#Include "models/GameState.ahk"
#Include "modules/Logger.ahk"
#Include "modules/Gui_Status.ahk"
#Include "modules/Gui_PowerCZ.ahk"
#Include "modules/Gui_ShieldWarning.ahk"
#Include "modules/Gui_NavRoute.ahk"
#Include "modules/Parser.ahk"
#Include "modules/JournalReader.ahk"
#Include "modules/Voice.ahk"


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
pos1X := Integer(IniRead(iniPath, "GuiStatus", "X", "20"))
pos1Y := Integer(IniRead(iniPath, "GuiStatus", "Y", "20"))
gui1W := Integer(IniRead(iniPath, "GuiStatus", "Width", "800"))
gui1H := Integer(IniRead(iniPath, "GuiStatus", "Height", "55"))
StatusOverlayGui.Init(pos1X, pos1Y, gui1W, gui1H)

gui2W := Integer(IniRead(iniPath, "GuiPowerCZ", "Width", "400"))
gui2H := Integer(IniRead(iniPath, "GuiPowerCZ", "Height", "40"))
pos2X := (A_ScreenWidth - gui2W) / 2
pos2Y := Integer(IniRead(iniPath, "GuiPowerCZ", "Y", "20"))
PowerCzOverlayGui.Init(pos2X, pos2Y, gui2W, gui2H)

; 경고 패널 위치 (화면 상단 중앙, 얇고 넓게)
guiWarnW := Integer(IniRead(iniPath, "GuiShieldWarning", "Width", "400"))
guiWarnH := Integer(IniRead(iniPath, "GuiShieldWarning", "Height", "32"))
posWarnX := (A_ScreenWidth - guiWarnW) / 2
posWarnY := (A_ScreenWidth / 7) ; Integer(IniRead(iniPath, "GuiShieldWarning", "Y", A_ScreenWidth / 7))
ShieldWarningGui.Init(posWarnX, posWarnY, guiWarnW, guiWarnH)

; 점프 경로 GUI 위치 및 너비 설정 (상단 중앙) ---
guiNavW := 620
guiNavH := 38
posNavX := (A_ScreenWidth - guiNavW) / 2
posNavY := 20 ; 화면 맨 상단 약간 아래
NavRouteOverlayGui.Init(posNavX, posNavY, guiNavW, guiNavH)

; --- 첫 렌더링 및 저널 스캔 ---
StatusOverlayGui.Update(AppState)
JournalReader.FindLatestLogFile(LogDir, AppState)

Voice.Init()

; --- 타이머 등록 ---
SetTimer(() => JournalReader.ReadTask(LogDir, AppState), readInterval)
SetTimer(OnUiTimer, uiInterval)
SetTimer(OnBlinkTimer, 500)

OnUiTimer() {
    if (AppState.isRunning) {
        AppState.elapsedSeconds++
    }
    StatusOverlayGui.Update(AppState)
    PowerCzOverlayGui.UpdateMetrics(AppState)
    NavRouteOverlayGui.Update(AppState)
}

; 0.5초 주기의 방어막 경고 루프
OnBlinkTimer() {
    if (AppState.isShieldWarningActive) {
        ShieldWarningGui.ToggleBlink()

        ; 1초마다 Beep 음 출력 (2회 깜빡일 때마다 1번)
        if (AppState.shieldWarningTicks < 18 && Mod(AppState.shieldWarningTicks, 4) == 0) {
            Voice.Speak("Warning", 2)
        }

        AppState.shieldWarningTicks--

        ; 10초 (20 틱) 경과 시 종료
        if (AppState.shieldWarningTicks <= 0) {
            AppState.isShieldWarningActive := false
            ShieldWarningGui.Hide()
        }
    }
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
    SoundBeep(500, 200)
    PowerCzOverlayGui.UpdateDisplay(AppState)
}

F7::
{
    Voice.Speak("Shields offline!")

    AppState.isShieldWarningActive := true
    AppState.shieldWarningTicks := 20 ; 0.5초 간격 x 20회 = 10초간 지속
    ShieldWarningGui.Show()
}

#Requires AutoHotkey v2.0

/*
`Status.json`의`Flags`는 함선과 이동 상태를 비트마스크로 표현합니다.각 비트가 하나의 상태를 뜻하며, 해당 비트가 켜져 있는지는`flags & (1 << 비트번호)`로 확인합니다.예를 들어`HardpointsDeployed`는 ** 6번 비트 **, 값으로는`64`입니다.

주요`Flags`항목은 다음과 같습니다.
| 비트 | 상태 |
    | ---: | --- |
    | 0–5 | 도킹, 착륙, 랜딩 기어, 실드, 슈퍼크루즈, Flight Assist 해제 |
    | 6–11 | 무기 전개, 윙 소속, 조명, 화물 수납고, Silent Running, 연료 스쿠핑 |
    | 12–15 | SRV 핸드브레이크·포탑 시점·포탑 수납·주행 보조 |
    | 16–18 | FSD 질량 잠금, 충전 중, 쿨다운 |
    | 19–23 | 연료 부족, 과열, 좌표 정보 있음, 위험 상태, 인터딕션 중 |
    | 24–26 | 주 함선·전투기·SRV 탑승 |
    | 27–31 | 분석 HUD, 나이트 비전, 고도 기준, FSD 점프, SRV 상향등 |


`Flags2`에는 온풋, 택시, 멀티크루 등 추가 상태가 들어갈 수 있습니다.
또한`Status.json`에는`Flags`비트 외에도 연료량, 좌표, 현재 선택된 UI 등 별도 필드가 있으므로 모든 상태가 비트마스크에 들어가는 것은 아닙니다.
공식[Elite Dangerous Journal 문서](https://elite-journal.readthedocs.io/en/latest/Status%20File.html) 에서 Status 파일 항목을 확인할 수 있습니다.

현재 코드의`state.isHardpointsDeployed := (flags & 64) != 0`은 이 중 ** 무기 전개 상태만 ** 읽습니다.
다른 항목도 필요하면 해당 비트 번호를 같은 방식으로 확인하면 됩니다.
*/

class StatusReader {
    static ReadTask(logDir, state) {

        statusPath := logDir . "\Status.json"

        if !FileExist(statusPath)
            return false

        try {
            json := FileRead(statusPath, "UTF-8")
        } catch {
            return false
        }

        hasData := false

        if RegExMatch(json, '"Balance"\s*:\s*(\d+)', &match) {
            state.totalCredits := Integer(match[1])
            hasData := true
        }

        ; --- Flags에서 상태 정보 읽기 ---
        if RegExMatch(json, '"Flags"\s*:\s*(\d+)', &match) {
            flags := Integer(match[1])

            state.isDocked := (flags & (1 << 0)) != 0
            state.isLandingGearDeployed := (flags & (1 << 2)) != 0
            state.isShieldsDown := (flags & (1 << 3)) == 0
            state.isFlightAssistOff := (flags & (1 << 5)) != 0
            state.isHardpointsDeployed := (flags & (1 << 6)) != 0
            state.isCargoScoopDeployed := (flags & (1 << 9)) != 0
            state.isSlientRunning := (flags & (1 << 10)) != 0
            state.isScoopingFuel := (flags & (1 << 11)) != 0
            state.isFsdcooldown := (flags & (1 << 18)) != 0
            state.isLowFuel := (flags & (1 << 19)) != 0
            state.isOverheating := (flags & (1 << 20)) != 0
            state.isNightVisionActive := (flags & (1 << 28)) != 0

            hasData := true
        }

        return hasData
    }
}
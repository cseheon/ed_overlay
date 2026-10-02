#Requires AutoHotkey v2.0

class Voice {
    static tts := unset
    static SSPF_ASYNC := 1

    /*
    Microsoft Ana Online (Natural) - English (United States)-- -----------------------------아이 목소리
    Microsoft AvaMultilingual Online (Natural) - English (United States)-- -------------------약간 까불이 느낌이 살짝
    Microsoft EmmaMultilingual Online (Natural) - English (United States)-- ----------------볼륨이 크고 또렷한
    Microsoft Emma Online (Natural) - English (United States)-- -------------------------위와 비슷
    Microsoft HyunsuMultilingual Online (Natural) - Korean (Korea)-- -----------자연스러움
    Microsoft InJoon Online (Natural) - Korean (Korea)-- ------------자연스럽고 약간 진지함
    Microsoft SunHi Online (Natural) - Korean (Korea)
    */

    static Init(voiceName := "AvaMultilingual Online") {
        this.tts := ComObject("SAPI.SpVoice")
        voices := this.tts.GetVoices()
        Loop voices.Count {
            voice := voices.Item(A_Index - 1)
            if InStr(voice.GetDescription(), voiceName) {
                this.tts.Voice := voice
                break
            }
        }
    }

    static Speak(talk, rate := 0) {
        clampedRate := Max(-10, Min(10, rate))
        this.tts.Rate := clampedRate
        this.tts.Speak(talk, this.SSPF_ASYNC)
    }
}


FormatNumber(num) {
    return RegExReplace(num, "(\d)(?=(\d{3})+$)", "$1,")
}

ExtractJsonVal(json, key) {
    if RegExMatch(json, '"' . key . '":\s*"([^"]+)"', &m)
        return m[1]
    if RegExMatch(json, '"' . key . '":\s*\[\s*"([^"]+)"', &m)
        return m[1]
    return ""
}

ExtractJournalEnumVal(json, key) {
    value := ExtractJsonVal(json, key)
    if (value == "")
        return ""

    value := RegExReplace(value, "^\$")
    value := RegExReplace(value, ";$")
    value := RegExReplace(value, "^.*_")
    return StrUpper(value)
}

ParseJournalTimestamp(isoStr) {
    cleanStr := RegExReplace(isoStr, "\D", "")
    return cleanStr != "" ? Number(cleanStr) : 0
}

SetTextAndResize(textCtrl, text) {
    Critical
    size := GetTextSize(textCtrl, text)
    textCtrl.Move(, , size*)
    ; textCtrl.Move(, , GetTextSize(textCtrl, text)*)
    textCtrl.Value := text
    ; WinRedraw(textCtrl.Gui.Hwnd)
    return size

    GetTextSize(textCtrl, text) {
        static WM_GETFONT := 0x0031, DT_CALCRECT := 0x400
        hDC := DllCall('GetDC', 'Ptr', textCtrl.Hwnd, 'Ptr')
        hPrevObj := DllCall('SelectObject', 'Ptr', hDC, 'Ptr', SendMessage(WM_GETFONT, , , textCtrl), 'Ptr')
        height := DllCall('DrawText', 'Ptr', hDC, 'Str', text, 'Int', -1, 'Ptr', buf := Buffer(16), 'UInt', DT_CALCRECT)
        width := NumGet(buf, 8, 'Int') - NumGet(buf, 'Int')
        DllCall('SelectObject', 'Ptr', hDC, 'Ptr', hPrevObj, 'Ptr')
        DllCall('ReleaseDC', 'Ptr', textCtrl.Hwnd, 'Ptr', hDC)
        return [Round(width * 96 / A_ScreenDPI), Round(height * 96 / A_ScreenDPI)]
    }
}


/**
 * 정수 Hex 값(0xD40000)이나 문자열("d40000", "#d40000", "0xd40000")을 
 * AHK 수치형 24비트 정수로 변환합니다.
 */
ParseColor(color) {
    if (Type(color) != "String" && IsInteger(color)) {
        return color
    }

    ; 문자열인 경우 공백 제거 및 '#' 문자 제거
    strColor := Trim(String(color))
    strColor := RegExReplace(strColor, "^#", "")

    ; '0x' 또는 '0X' 접두사가 없다면 붙여서 16진수로 명시적 변환
    if (!RegExMatch(strColor, "i)^0x")) {
        strColor := "0x" . strColor
    }

    return Integer(strColor)
}


/**
 * 두 RGB 색상 사이의 선형 보간(Lerp) 색상을 반환합니다.
 * @param colorA 시작 색상 (예: 0xFF0000)
 * @param colorB 종료 색상 (예: 0x0000FF)
 * @param t 비율 (0.0 ~ 1.0)
 * @returns {Number} 보간된 RGB 색상 값 (Hex)
 */
LerpColor(colorA, colorB, t) {

    ; 문자열/숫자 모두 정수 24비트 Hex로 통일
    cA := ParseColor(colorA)
    cB := ParseColor(colorB)

    ; 보간 비율을 0~1로 제한
    t := Max(0, Min(1, Number(t)))

    ; RGB 채널 분리 (비트 시프트 및 AND 연산)
    rA := (cA >> 16) & 0xFF, gA := (cA >> 8) & 0xFF, bA := cA & 0xFF
    rB := (cB >> 16) & 0xFF, gB := (cB >> 8) & 0xFF, bB := cB & 0xFF

    ; 채널별 선형 보간 계산
    r := Round(rA + (rB - rA) * t)
    g := Round(gA + (gB - gA) * t)
    b := Round(bA + (bB - bA) * t)

    ; RGB 채널을 다시 하나의 24비트 Hex 값으로 결합
    return (r << 16) | (g << 8) | b
}

/**
 * t 값에 따라 A 색상과 B 색상 사이를 왕복(Ping-Pong)하는 보간 색상을 반환합니다.
 * @param colorA 시작 색상 (t = 0, 2, 4... 일 때의 색상)
 * @param colorB 왕복 지점 색상 (t = 1, 3, 5... 일 때의 색상)
 * @param t 시간 또는 진행 비율 (양수로 지속적으로 증가하는 값)
 * @returns {Number} 보간된 RGB 색상 값 (Hex)
 */
PingPongColor(colorA, colorB, t) {
    ; 문자열/숫자 모두 정수 24비트 Hex로 통일
    cA := ParseColor(colorA)
    cB := ParseColor(colorB)

    pingt := 1.0 - Abs(Mod(t, 2.0) - 1.0)

    ; RGB 채널 분리
    rA := (cA >> 16) & 0xFF, gA := (cA >> 8) & 0xFF, bA := cA & 0xFF
    rB := (cB >> 16) & 0xFF, gB := (cB >> 8) & 0xFF, bB := cB & 0xFF

    ; 채널별 선형 보간 계산
    r := Round(rA + (rB - rA) * pingt)
    g := Round(gA + (gB - gA) * pingt)
    b := Round(bA + (bB - bA) * pingt)

    ; RGB 채널 결합
    return (r << 16) | (g << 8) | b
}
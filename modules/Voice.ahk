#Requires AutoHotkey v2.0

; Microsoft David Desktop
; Microsoft Zira Desktop
; Microsoft ZHeami Desktop

class Voice {
    static tts := unset
    static SSPF_ASYNC := 1

    static Init() {
        this.tts := ComObject("SAPI.SpVoice")
        voices := this.tts.GetVoices()
        Loop voices.Count {
            voice := voices.Item(A_Index - 1)
            if InStr(voice.GetDescription(), "Microsoft Zira Desktop") {
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

#Requires AutoHotkey v2.0

class JournalReader {
    static fileObj := 0
    static lastSize := 0

    static FindLatestLogFile(logDir, state) {
        latestTime := 0
        latestLog := ""

        Loop Files, logDir . "\Journal.*.log" {
            if (A_LoopFileTimeModified > latestTime) {
                latestTime := A_LoopFileTimeModified
                latestLog := A_LoopFilePath
            }
        }
        if (latestLog != "")
            state.currentLogFile := latestLog
    }

    static ReadTask(logDir, state) {
        if (this.fileObj == 0) {
            if (state.currentLogFile == "")
                this.FindLatestLogFile(logDir, state)
            if (state.currentLogFile != "") {
                this.fileObj := FileOpen(state.currentLogFile, "r-d", "UTF-8")
                if (this.fileObj) {
                    while !this.fileObj.AtEOF {
                        line := this.fileObj.ReadLine()
                        if (line != "")
                            JournalParser.Parse(line, state)
                    }
                    this.lastSize := this.fileObj.Length
                }
            }
            return
        }

        if (this.fileObj.Length > this.lastSize) {
            while !this.fileObj.AtEOF {
                line := this.fileObj.ReadLine()
                if (line != "")
                    JournalParser.Parse(line, state)
            }
            this.lastSize := this.fileObj.Length
        }
    }

    static ReadNavRouteFile(state) {
        navFilePath := RegExReplace(state.currentLogFile, "Journal\..*$", "NavRoute.json")
        if (!FileExist(navFilePath)) {
            state.isRouteActive := false
            state.remainingJumps := 0
            return
        }

        try {
            jsonText := FileRead(navFilePath, "UTF-8")
            
            ; Route 배열 존재 여부 및 성계 탐색
            if InStr(jsonText, '"Route"') {
                matches := []
                pos := 1
                while (pos := RegExMatch(jsonText, '"StarSystem":"([^"]+)"', &m, pos)) {
                    matches.Push(m[1])
                    pos += m.Len
                }

                ; 경로 성계가 2개 이상일 때만 활성화 (현재 위치 + 최소 1개 이상의 목적지)
                if (matches.Length > 1) {
                    state.finalDestination := matches[matches.Length] ; 배열의 마지막 성계가 최종 목적지
                    state.totalJumps := matches.Length - 1            ; 현재 성계 제외 남은 점프 수
                    state.remainingJumps := state.totalJumps
                    state.isRouteActive := true
                } else {
                    ; 경로 내 성계가 1개 이하이거나 취소된 경우 (경로 삭제)
                    state.isRouteActive := false
                    state.remainingJumps := 0
                    state.finalDestination := "None"
                }
            } else {
                ; Route 항목이 없는 경우
                state.isRouteActive := false
                state.remainingJumps := 0
                state.finalDestination := "None"
            }
        } catch {
            ; 파일 읽기 실패 시 경로 비활성화
            state.isRouteActive := false
            state.remainingJumps := 0
        }
    }
}
#Requires AutoHotkey v2.0

class StatusReader {
    static ReadTask(logDir, state) {

         statusPath :=  logDir . "\Status.json"

        if !FileExist(statusPath)
            return false

        try {
            json := FileRead(statusPath, "UTF-8")
        } catch {
            return false
        }

        if RegExMatch(json, '"Balance"\s*:\s*(\d+)', &match) {
            state.totalCredits := Integer(match[1])
            return true
        }

        return false
    }
}

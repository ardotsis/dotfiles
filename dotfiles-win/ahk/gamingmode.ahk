targetExePaths := [
    "E:\SteamLibrary\steamapps\common\Grand Theft Auto V Enhanced\GTA5_Enhanced.exe",
    "C:\Users\owner\AppData\Roaming\ModrinthApp\meta\java_versions\zulu21.42.19-ca-jre21.0.7-win_x64\bin\javaw.exe",
	"C:\Users\owner\.lunarclient\jre\56e53accb20696f802d92bd011174126b5e3154e\zulu21.30.15-ca-jre21.0.1-win_x64\bin\javaw.exe"
]
isTargetRunning := false

SetTimer(CheckTargetProcess, 500)

CheckTargetProcess(*) {
    global isTargetRunning, targetExePaths
    try {
        hWnd := WinGetID("A")
        pid := WinGetPID(hWnd)
        path := ProcessGetPath(pid)

        isTargetRunning := false
        for gamePath in targetExePaths {
            if (path != "" && path = gamePath) {
                isTargetRunning := true
                break
            }
        }
    } catch {
        isTargetRunning := false
    }
}

#HotIf isTargetRunning
!F4::return
LWin::return
RWin::return
^!z::return
#HotIf

#Requires AutoHotkey v2.0

global enabled := false
targetPath := "C:\Users\owner\AppData\Roaming\ModrinthApp\meta\java_versions\zulu21.42.19-ca-jre21.0.7-win_x64\bin\javaw.exe"

; F8 で有効/無効を切り替え
F8:: {
    global enabled
    enabled := !enabled
    ToolTip(enabled ? "右クリック連打 有効" : "右クリック連打 無効")
    SetTimer(() => ToolTip(""), -1000)
}

; 右クリックを押している間だけ連打（有効時のみ）
~RButton::
{
    global enabled, targetPath
    if !enabled
        return

    ; 押し始めたときに一度だけアクティブウィンドウのパスを取得
    win := WinActive("A")
    exePath := win ? WinGetProcessPath(win) : ""

    ; 対象アプリじゃなければ何もしない
    if (exePath != targetPath)
        return

    ; ここから押してる間だけ連打
    Loop {
        if !GetKeyState("RButton", "P")
            break

        Click("Right")
        Sleep(3) ; クリック間隔
    }
}

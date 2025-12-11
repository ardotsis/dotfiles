#Requires AutoHotkey v2.0

Space::
{
    ; ここで連打回数と間隔を設定
    repeatCount := 5       ; 連打回数
    interval := 50         ; ミリ秒単位の間隔

    Loop repeatCount
    {
        Send "{Space}"
        Sleep interval
    }
    return
}

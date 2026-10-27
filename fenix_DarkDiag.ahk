#Requires AutoHotkey v2.0
#SingleInstance Force
#Include FindText.ahk
; fenix_DarkDiag.ahk - one-shot diagnostic, read-only.
; HOW TO USE:
;   1. Go to the desktop where the status icon is DARK and the game window is visible.
;   2. Double-click this file. Do NOT start the main polling script.
;   3. Wait for the "Done" message, then send back fenix_DarkDiag_Result.txt
;      (same folder). It presses no keys and clicks nothing.
; WHAT IT CHECKS (full screen, no recorded-position narrowing):
;   A. Dark pattern at tolerance 0.1 (same as the main script) and at 0.2.
;   B. Bright pattern and Unknown pattern at tolerance 0.1.
;   C. The same 5x5 brightness grid at every found center.
; HOW TO READ THE RESULT:
;   - Dark found at 0.1 + brightness dark  -> pattern and brightness are fine;
;     the main script probably searches around a stale recorded position, or an
;     old version is still running. Restart the main script from a fresh pull.
;   - Dark found only at 0.2              -> pattern is too strict now
;     (e.g. the number inside the icon changed). Raise FindErr1/FindErr0 to 0.2.
;   - Dark found at 0.1 but brightness says bright -> the brightness gate
;     rejects it (center sits on bright digits/edge). Needs a grid/pattern fix.
;   - Dark not found at 0.1 or 0.2        -> pattern no longer matches the
;     current dark icon at all. Send a fresh screenshot of the dark icon so
;     the DarkText pattern can be rebuilt from it.

CoordMode("Pixel", "Screen")
ResultFile := A_ScriptDir "\fenix_DarkDiag_Result.txt"
FindErr1 := 0.1
FindErr0 := 0.1
BrightText := "|<Bright>*120$42.U000001000000000000000000000003zk00003zk10401zU20430z0k041UV1U040kS30040MA6E040A0A004060M004030k00001VU00400H0004000000400M000400Q000000S000000n000001VU000030k0000200000040A000000400000040000E06000000000000000000000000400080000000000000000000001U"
DarkText := "|<Dark>*120$42.U000001DzzzzzxTvzzzryTszzz7yTsTzy7yTwDzwDyTw7zsDyTz7zszyTzXVlzyTzlSXzyTzsy7zyTzwyDzyTzyETzyTzzAzzyTzzgzzyTzzGzzyTzzVzzyTzzvzzzTzzzzzzTzzzzzyTjzzzxyTjzzzxzTrvzzvzTzu1VzzTzqzSzzTz6zQzzTz63QzzTzrxSzzzzjxSzzzzjxSzzzzixSzzzzj1VzzzzTzzzzzTTzzyzzjzzzxzU"
UnknownText := "|<Unknown>*82$46.zzzzzzzvzzzzzzzjzzzzzzzk000000yTzzzzztdzTzzyzqjwzzznzSzszzwTxfzVzzVzqjz3zwDzOzzDznzxfzwTyDzqjzszlzzOzznzDzxfzzbtzzqjzzDDzzOzzytzzxvzzxjzzrjzztzzzSzzzrzzxfzzzzzzqjzzzzzzOzzzzzzxfzzzzzzqjrzzzyzOzzzzzzxfzzzzzzqjzzzzzzOzyTztzxfztzzbzqjzzzzzzOzzzzzzxfzzzzzzqjzzzzzzOzzzPzzxfzzzzzzyjjzzzzTTzzzzzzzi000000SzzzzzzzvzzzzLzzz"
ProjectorText := "|<projector>*79$46.s000000TDzzzzzwwzzzzzzurzzzzzzfTzVzzzyhzw3zzzurzm7zzzfTy0Nzzyhzt3y3zurzk7sLzfTzEQBTyhzx7koTurzm711zfTz8SOTyhzUXs7zurw0AgTzfTU00kTyhy03k/Turl07k5zfTY030DyhyG00Svurxj007zfTszk7zyhzkzkTzurzUzszzfTyET7zyhztkATzurznsDzzfTzbwTzyhzzbzzzurzzbzxzfTzzbzzyhzzznzzurzzzzzzfzzzzzzzj000000D"

Out := ""
Out .= "fenix dark-icon diagnostic - " A_YYYY "-" A_MM "-" A_DD " " A_Hour ":" A_Min ":" A_Sec "`n"
Out .= "Screen: " A_ScreenWidth "x" A_ScreenHeight "`n`n"

; Full-screen FindText search. Returns true and sets CX/CY to the pattern center.
FindPattern(Text, Err1, Err0, &CX, &CY) {
    CX := 0
    CY := 0
    FX := 0
    FY := 0
    try {
        if (FindText(&FX, &FY, 0, 0, A_ScreenWidth, A_ScreenHeight, Err1, Err0, Text).Length) {
            CX := FX
            CY := FY
            return true
        }
    } catch {
    }
    return false
}

; Same 5x5 brightness grid as the main script: bright point = gray > 120,
; bright if more than half of the 25 points are bright.
IconBright(CX, CY, &Frac) {
    Bright := 0
    N := 0
    for DY in [-10, -5, 0, 5, 10] {
        for DX in [-16, -8, 0, 8, 16] {
            try {
                C := PixelGetColor(CX + DX, CY + DY)
                R := (C >> 16) & 0xFF
                G := (C >> 8) & 0xFF
                B := C & 0xFF
                if ((R * 38 + G * 75 + B * 15) // 128 > 120) {
                    Bright++
                }
                N++
            } catch {
            }
        }
    }
    if (N = 0) {
        Frac := 0
        return false
    }
    Frac := Bright / N
    return (Frac > 0.5)
}

CheckOne(Label, Text, Err1, Err0) {
    global Out
    CX := 0
    CY := 0
    Found := FindPattern(Text, Err1, Err0, &CX, &CY)
    if (!Found) {
        Out .= Label " at err " Err1 ": NOT FOUND`n"
        return
    }
    Frac := 0
    IsBright := IconBright(CX, CY, &Frac)
    Out .= Label " at err " Err1 ": FOUND at (" CX "," CY "), brightness bright points = " Round(Frac, 2) " -> " (IsBright ? "BRIGHT" : "DARK") "`n"
}

Out .= "[Dark pattern]`n"
CheckOne("Dark", DarkText, 0.1, 0.1)
CheckOne("Dark", DarkText, 0.2, 0.2)
Out .= "`n[Other patterns at err 0.1]`n"
CheckOne("Bright", BrightText, 0.1, 0.1)
CheckOne("Unknown", UnknownText, 0.1, 0.1)
CheckOne("Projector", ProjectorText, 0.1, 0.1)
Out .= "`nDone. Send this file back as-is.`n"

try {
    FileDelete(ResultFile)
} catch {
}
FileAppend(Out, ResultFile, "UTF-8")
MsgBox("Done. Result saved to fenix_DarkDiag_Result.txt in the same folder.")
ExitApp()

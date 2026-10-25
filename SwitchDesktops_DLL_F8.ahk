#Requires AutoHotkey v2.0

; ============================================================
; Desktop Cycler + G key (DLL version)
; Uses VirtualDesktopAccessor.dll to switch desktops DIRECTLY
; by number. No simulated arrow keys. The DLL calls the same
; internal Windows interface that Task View itself uses.
;
; What it does, looping forever, on every desktop:
;   switch to the desktop -> wait 1s -> left mouse click ->
;   wait 1s -> press G -> wait 1s -> switch to next desktop ...
;   after the last desktop it goes back to Desktop 1.
; (If you have more or fewer desktops it uses the real count
;  reported by the DLL.)
;
; SETUP: Put VirtualDesktopAccessor.dll in the SAME folder
; as this script. For Windows 10 (build 19041-19045) use the
; "Windows 10 binary, final" release from:
; https://github.com/Ciantic/VirtualDesktopAccessor
;
; F8 = Start / Pause
; F9 = Exit
; ============================================================

; ===== Settings (edit these) =====
WaitMs := 1000   ; wait between every step (milliseconds)
KeyToPress := "g"  ; key pressed once on every desktop

; ===== Load DLL =====
DllPath := A_ScriptDir "\VirtualDesktopAccessor.dll"
hDll := DllCall("LoadLibrary", "Str", DllPath, "Ptr")
if (!hDll) {
    MsgBox("VirtualDesktopAccessor.dll could not be loaded.`nPut the DLL in the same folder as this script,`nand make sure its build matches your Windows build.")
    ExitApp()
}

GoToDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "GoToDesktopNumber", "Ptr")
GetDesktopCountProc   := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "GetDesktopCount", "Ptr")

DesktopCount := DllCall(GetDesktopCountProc, "Int")
if (DesktopCount < 1) {
    MsgBox("The DLL answered " DesktopCount " desktops, which is wrong.`nThis DLL build does not match your Windows build.")
    ExitApp()
}

; ===== State =====
Running := false
NextIndex := 0       ; zero-based: next desktop to visit (starts at Desktop 1)
Phase := "switch"    ; cycles "switch" -> "click" -> "press" -> "switch" ...

F8::ToggleRun()
F9::ExitApp()

ToggleRun() {
    global Running, Phase
    Running := !Running
    if (Running) {
        Phase := "switch"
        StepCycle()                 ; first switch happens immediately
        SetTimer(StepCycle, WaitMs)
    } else {
        SetTimer(StepCycle, 0)
        ToolTip("Desktop cycler: OFF")
        SetTimer(HideTip, -1200)
    }
}

StepCycle() {
    global NextIndex, Phase
    if (Phase = "switch") {
        DllCall(GoToDesktopNumberProc, "Int", NextIndex)
        ToolTip("Desktop " (NextIndex + 1) " / " DesktopCount)
        NextIndex := Mod(NextIndex + 1, DesktopCount)
        Phase := "click"
    } else if (Phase = "click") {
        Click()
        Phase := "press"
    } else {
        Send(KeyToPress)
        Phase := "switch"
    }
}

HideTip() {
    ToolTip()
}

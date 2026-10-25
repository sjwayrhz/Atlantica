#Requires AutoHotkey v2.0

; ============================================================
; Two-Point Click Loop
; Loops forever:
;   move mouse to (700, 450), left click, wait 1 second,
;   move mouse to (822, 450), left click, wait 2 seconds,
;   then back to the first point.
;
; F8 = Start / Pause the two-point click loop
; F7 = Start / Pause the right-click loop
;      (moves to (980, 593), then right clicks there every 2.5 seconds)
; F9 = Exit
; ============================================================

CoordMode("Mouse", "Screen")

; ===== Settings (edit these) =====
Point1X := 700
Point1Y := 450
Point2X := 822
Point2Y := 450
WaitAfterFirst := 1000   ; milliseconds after the first click
WaitAfterSecond := 2000  ; milliseconds after the second click
RightClickInterval := 3500  ; milliseconds between right clicks
RightX := 980   ; F7 right-click loop position
RightY := 593

; ===== State =====
Running := false
Phase := 0   ; 0 = click point 1 next, 1 = click point 2 next
RightRunning := false

F8::ToggleRun()
F7::ToggleRight()
F9::ExitApp()

ToggleRun() {
    global Running, Phase
    Running := !Running
    if (Running) {
        Phase := 0
        StepClick()   ; first click happens immediately
    } else {
        SetTimer(StepClick, 0)
        ToolTip("Click loop: OFF")
        SetTimer(HideTip, -1200)
    }
}

StepClick() {
    global Phase
    if (Phase = 0) {
        Click(Point1X, Point1Y)
        ToolTip("Clicked point 1 (" Point1X ", " Point1Y ")")
        Phase := 1
        SetTimer(StepClick, WaitAfterFirst)
    } else {
        Click(Point2X, Point2Y)
        ToolTip("Clicked point 2 (" Point2X ", " Point2Y ")")
        Phase := 0
        SetTimer(StepClick, WaitAfterSecond)
    }
}

ToggleRight() {
    global RightRunning
    RightRunning := !RightRunning
    if (RightRunning) {
        RightClickStep()   ; first right click happens immediately
        SetTimer(RightClickStep, RightClickInterval)
    } else {
        SetTimer(RightClickStep, 0)
        ToolTip("Right-click loop: OFF")
        SetTimer(HideTip, -1200)
    }
}

RightClickStep() {
    Click(RightX, RightY, "Right")   ; move to (980, 593) and right click there
    ToolTip("Right click at (" RightX ", " RightY ")")
}

HideTip() {
    ToolTip()
}

#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Atlantica 功能菜单（图形界面版，AHK v2）
; 原来的两个脚本已经合并到这一个窗口里，
; 不会出现两个脚本都抢 F8 的冲突。
;
; 功能：
;   1. 桌面轮询：
;      切桌面 -> 停 0.5 秒 -> 左键点 (212,57) -> 停 0.5 秒
;      -> 点击 -> 按 G -> 下一个桌面，循环
;   2. 开箱子（两点点击 + 右键点击合并）：
;      左边按钮：两种点击同时操作
;        两点点击：(700,450) 点一下 -> (822,450) 点一下，循环
;        右键点击：同时在 (980,593) 定时右键
;      右边按钮：只做右键点击
;        只在 (980,593) 定时右键，两点点击不启动
;      两个按钮互斥：点另一个会先停掉当前模式再启动新模式；
;      再点一次正在运行的按钮就是停止。
;
; 使用：双击运行本脚本，点按钮或按快捷键即可。
;       F11 开关桌面轮询，F12 开关开箱子，F9 统一暂停（不退出）。
;       关窗口或点“退出”即全部停止并退出。
; 注意：功能 1 需要 VirtualDesktopAccessor.dll 放在本脚本同目录，
;       且 DLL 版本要和你的 Windows 版本匹配，否则该功能会被禁用。
; ============================================================

CoordMode("Mouse", "Screen")

; ===== 功能 1 的 DLL（先加载，失败也不影响功能 2）=====
DllPath := A_ScriptDir "\VirtualDesktopAccessor.dll"
hDll := DllCall("LoadLibrary", "Str", DllPath, "Ptr")
GoToDesktopNumberProc := 0
GetDesktopCountProc := 0
DesktopCount := 0
if (hDll) {
    GoToDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "GoToDesktopNumber", "Ptr")
    GetDesktopCountProc := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "GetDesktopCount", "Ptr")
    DesktopCount := DllCall(GetDesktopCountProc, "Int")
}

; ===== 状态 =====
DesktopRunning := false
DesktopNext := 0        ; 下一个要去的桌面（从 0 开始，即桌面 1）
DesktopPhase := "switch"
DesktopWaitMs := 1000
DesktopKey := "g"
SwitchClickX := 212     ; 每次切换后要点的固定位置
SwitchClickY := 57

ClickMode := ""         ; "" = 未运行，"both" = 两种同时，"right" = 仅右键
TwoRunning := false
TwoPhase := 0
Point1X := 700
Point1Y := 450
Point2X := 822
Point2Y := 450
WaitAfterFirst := 1000
WaitAfterSecond := 2000

RightRunning := false
RightX := 980
RightY := 593
RightClickInterval := 3500

; ===== 图形界面 =====
MyGui := Gui(, "Atlantica 功能菜单")
MyGui.SetFont("s10")

MyGui.Add("Text", "x10 y10 w360", "打开后点下面的功能按钮即可开始，再点一次停止。")

; ---- 功能 1：桌面轮询 ----
MyGui.Add("Text", "x10 y40 w360", "1. 桌面轮询 (F11)")
MyGui.Add("Text", "x10 y65 w70", "每步间隔(ms):")
edtDesktopWait := MyGui.Add("Edit", "x85 y62 w70", "1000")
MyGui.Add("Text", "x165 y65 w40", "按键:")
edtDesktopKey := MyGui.Add("Edit", "x205 y62 w50", "g")
MyGui.Add("Text", "x10 y95 w90", "切换后点击 X:")
edtSwitchX := MyGui.Add("Edit", "x100 y92 w60", "212")
MyGui.Add("Text", "x170 y95 w15", "Y:")
edtSwitchY := MyGui.Add("Edit", "x185 y92 w60", "57")
btnDesktop := MyGui.Add("Button", "x10 y125 w360 h30", "开始：桌面轮询")
btnDesktop.OnEvent("Click", ToggleDesktop)
txtDesktopStatus := MyGui.Add("Text", "x10 y160 w360", "状态：未运行")

; ---- 功能 2：开箱子（两点点击 + 右键点击）----
MyGui.Add("Text", "x10 y190 w360", "2. 开箱子 (F12)")
MyGui.Add("Text", "x10 y215 w50", "点 1 X:")
edtP1X := MyGui.Add("Edit", "x60 y212 w55", "700")
MyGui.Add("Text", "x125 y215 w15", "Y:")
edtP1Y := MyGui.Add("Edit", "x140 y212 w55", "450")
MyGui.Add("Text", "x205 y215 w50", "点 2 X:")
edtP2X := MyGui.Add("Edit", "x255 y212 w55", "822")
MyGui.Add("Text", "x320 y215 w15", "Y:")
edtP2Y := MyGui.Add("Edit", "x335 y212 w35", "450")
MyGui.Add("Text", "x10 y242 w80", "点 1 后等(ms):")
edtWait1 := MyGui.Add("Edit", "x95 y239 w60", "1000")
MyGui.Add("Text", "x165 y242 w80", "点 2 后等(ms):")
edtWait2 := MyGui.Add("Edit", "x250 y239 w60", "2000")
MyGui.Add("Text", "x10 y272 w50", "右键 X:")
edtRightX := MyGui.Add("Edit", "x60 y269 w60", "980")
MyGui.Add("Text", "x130 y272 w15", "Y:")
edtRightY := MyGui.Add("Edit", "x145 y269 w60", "593")
MyGui.Add("Text", "x215 y272 w60", "间隔(ms):")
edtRightInterval := MyGui.Add("Edit", "x280 y269 w70", "3500")
btnBoth := MyGui.Add("Button", "x10 y300 w175 h30", "两种点击同时操作")
btnBoth.OnEvent("Click", ToggleBoth)
btnRightOnly := MyGui.Add("Button", "x195 y300 w175 h30", "只做右键点击")
btnRightOnly.OnEvent("Click", ToggleRightOnly)
txtClickStatus := MyGui.Add("Text", "x10 y335 w360", "状态：未运行")

; ---- 底部 ----
btnStopAll := MyGui.Add("Button", "x10 y365 w175 h30", "全部停止")
btnStopAll.OnEvent("Click", StopAll)
btnExit := MyGui.Add("Button", "x195 y365 w175 h30", "退出")
btnExit.OnEvent("Click", (*) => ExitApp())
MyGui.Add("Text", "x10 y405 w360 h50", "提示：F11 桌面轮询，F12 开箱子，F9 统一暂停（不退出）。功能 1 需要同目录下的 VirtualDesktopAccessor.dll，版本须匹配 Windows。")
MyGui.OnEvent("Close", (*) => ExitApp())

; DLL 没加载成功时，禁用功能 1，不影响功能 2
if (DesktopCount < 1) {
    btnDesktop.Enabled := false
    txtDesktopStatus.Text := "状态：不可用（DLL 加载失败，请检查同目录的 VirtualDesktopAccessor.dll）"
}

MyGui.Show("w380 h460")

; ===== 功能 1：桌面轮询 =====
ToggleDesktop(*) {
    global DesktopRunning, DesktopPhase, DesktopWaitMs, DesktopKey, SwitchClickX, SwitchClickY
    global btnDesktop, txtDesktopStatus, edtDesktopWait, edtDesktopKey, edtSwitchX, edtSwitchY
    if (DesktopRunning) {
        DesktopRunning := false
        SetTimer(StepDesktop, 0)
        btnDesktop.Text := "开始：桌面轮询"
        txtDesktopStatus.Text := "状态：已停止"
        ToolTip()
        return
    }
    if (!IsNumber(edtDesktopWait.Value) || !IsNumber(edtSwitchX.Value) || !IsNumber(edtSwitchY.Value)) {
        MsgBox("桌面轮询的间隔和切换后点击的坐标请都填数字。")
        return
    }
    DesktopWaitMs := Integer(edtDesktopWait.Value)
    DesktopKey := edtDesktopKey.Value
    SwitchClickX := Integer(edtSwitchX.Value)
    SwitchClickY := Integer(edtSwitchY.Value)
    DesktopRunning := true
    DesktopPhase := "switch"
    DesktopNext := 0
    btnDesktop.Text := "停止：桌面轮询"
    txtDesktopStatus.Text := "状态：运行中（切换后点 " SwitchClickX "," SwitchClickY "，前后各停 0.5 秒）"
    StepDesktop()
}

StepDesktop() {
    global DesktopNext, DesktopPhase, DesktopCount, DesktopKey, GoToDesktopNumberProc
    global DesktopWaitMs, SwitchClickX, SwitchClickY
    if (DesktopPhase = "switch") {
        DllCall(GoToDesktopNumberProc, "Int", DesktopNext)
        ToolTip("桌面 " (DesktopNext + 1) " / " DesktopCount)
        DesktopNext := Mod(DesktopNext + 1, DesktopCount)
        DesktopPhase := "click212"
        SetTimer(StepDesktop, 500)   ; 切换后先停 0.5 秒
    } else if (DesktopPhase = "click212") {
        Click(SwitchClickX, SwitchClickY)
        ToolTip("切换后点了 (" SwitchClickX ", " SwitchClickY ")")
        DesktopPhase := "click"
        SetTimer(StepDesktop, 500)   ; 点完再停 0.5 秒
    } else if (DesktopPhase = "click") {
        Click()
        DesktopPhase := "press"
        SetTimer(StepDesktop, DesktopWaitMs)
    } else {
        Send(DesktopKey)
        DesktopPhase := "switch"
        SetTimer(StepDesktop, DesktopWaitMs)
    }
}

; ===== 功能 2：开箱子 =====
UpdateClickButtons() {
    global ClickMode, btnBoth, btnRightOnly, txtClickStatus
    if (ClickMode = "both") {
        btnBoth.Text := "停止：两种点击同时操作"
        btnRightOnly.Text := "只做右键点击"
        txtClickStatus.Text := "状态：运行中（开箱子：两种点击同时）"
    } else if (ClickMode = "right") {
        btnBoth.Text := "两种点击同时操作"
        btnRightOnly.Text := "停止：只做右键点击"
        txtClickStatus.Text := "状态：运行中（仅右键点击）"
    } else {
        btnBoth.Text := "两种点击同时操作"
        btnRightOnly.Text := "只做右键点击"
        txtClickStatus.Text := "状态：未运行"
    }
}

StopClickLoops() {
    global TwoRunning, RightRunning, ClickMode
    TwoRunning := false
    RightRunning := false
    SetTimer(StepTwo, 0)
    SetTimer(StepRight, 0)
    ClickMode := ""
    UpdateClickButtons()
}

ToggleBoth(*) {
    global ClickMode, TwoRunning, TwoPhase, Point1X, Point1Y, Point2X, Point2Y
    global WaitAfterFirst, WaitAfterSecond, RightRunning, RightX, RightY, RightClickInterval
    global edtP1X, edtP1Y, edtP2X, edtP2Y, edtWait1, edtWait2, edtRightX, edtRightY, edtRightInterval
    if (ClickMode = "both") {
        StopClickLoops()
        ToolTip()
        return
    }
    ; 先校验，校验不过就保持当前模式不动
    for ctrl in [edtP1X, edtP1Y, edtP2X, edtP2Y, edtWait1, edtWait2, edtRightX, edtRightY, edtRightInterval] {
        if (!IsNumber(ctrl.Value)) {
            MsgBox("开箱子的坐标和间隔请都填数字。")
            return
        }
    }
    StopClickLoops()
    Point1X := Integer(edtP1X.Value)
    Point1Y := Integer(edtP1Y.Value)
    Point2X := Integer(edtP2X.Value)
    Point2Y := Integer(edtP2Y.Value)
    WaitAfterFirst := Integer(edtWait1.Value)
    WaitAfterSecond := Integer(edtWait2.Value)
    RightX := Integer(edtRightX.Value)
    RightY := Integer(edtRightY.Value)
    RightClickInterval := Integer(edtRightInterval.Value)
    TwoRunning := true
    TwoPhase := 0
    RightRunning := true
    ClickMode := "both"
    UpdateClickButtons()
    StepTwo()
    StepRight()
    SetTimer(StepRight, RightClickInterval)
}

ToggleRightOnly(*) {
    global ClickMode, RightRunning, RightX, RightY, RightClickInterval
    global edtRightX, edtRightY, edtRightInterval
    if (ClickMode = "right") {
        StopClickLoops()
        ToolTip()
        return
    }
    for ctrl in [edtRightX, edtRightY, edtRightInterval] {
        if (!IsNumber(ctrl.Value)) {
            MsgBox("右键点击的坐标和间隔请都填数字。")
            return
        }
    }
    StopClickLoops()
    RightX := Integer(edtRightX.Value)
    RightY := Integer(edtRightY.Value)
    RightClickInterval := Integer(edtRightInterval.Value)
    RightRunning := true
    ClickMode := "right"
    UpdateClickButtons()
    StepRight()
    SetTimer(StepRight, RightClickInterval)
}

StepTwo() {
    global TwoPhase, Point1X, Point1Y, Point2X, Point2Y, WaitAfterFirst, WaitAfterSecond
    if (TwoPhase = 0) {
        Click(Point1X, Point1Y)
        ToolTip("点了点 1 (" Point1X ", " Point1Y ")")
        TwoPhase := 1
        SetTimer(StepTwo, WaitAfterFirst)
    } else {
        Click(Point2X, Point2Y)
        ToolTip("点了点 2 (" Point2X ", " Point2Y ")")
        TwoPhase := 0
        SetTimer(StepTwo, WaitAfterSecond)
    }
}

StepRight() {
    global RightX, RightY
    Click(RightX, RightY, "Right")
    ToolTip("右键点了 (" RightX ", " RightY ")")
}

; ===== 全部停止 =====
StopAll(*) {
    global DesktopRunning, btnDesktop, txtDesktopStatus
    if (DesktopRunning) {
        DesktopRunning := false
        SetTimer(StepDesktop, 0)
        btnDesktop.Text := "开始：桌面轮询"
        txtDesktopStatus.Text := "状态：已停止"
    }
    StopClickLoops()
    ToolTip()
}

; F12 用的开关：未运行时启动两种点击同时模式，
; 运行中（无论是两种同时还是仅右键）则暂停。
ToggleClickHotkey(*) {
    global ClickMode
    if (ClickMode != "") {
        StopClickLoops()
        ToolTip()
    } else {
        ToggleBoth()
    }
}

; ===== 快捷键 =====
; F11 = 桌面轮询 开启 / 暂停
; F12 = 开箱子 开启 / 暂停
; F9  = 统一暂停（全部停止，不退出程序，窗口还在，可再启动）
F11::ToggleDesktop()
F12::ToggleClickHotkey()
F9::StopAll()

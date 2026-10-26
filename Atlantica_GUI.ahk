#Requires AutoHotkey v2.0
#SingleInstance Force
#Include FindText.ahk

; ============================================================
; Atlantica 功能菜单（图形界面版，AHK v2）
; 原来的两个脚本已经合并到这一个窗口里，
; 不会出现两个脚本都抢 F8 的冲突。
;
; 功能：
;   1. 桌面轮询（F11）：按 F11 或点按钮启动后，一直重复下面
;      的循环，停掉之前不会自己停。轮询时每轮按 G，约 0.05 秒
;      后看一眼屏幕：只有看到等待图标、没看到状态按钮时才
;      按 X（空闲阶段除外，只按 X、不按 G，同样只有看到等待
;      图标时才按）。
;      第 1 步 校准 2 分钟：
;        轮询按 G、X，同时在每个桌面找等待图标和状态按钮，
;        确认位置正常并记下两个点的坐标，光标旁会提示。
;      第 2 步 转亮 2 分钟：
;        继续轮询，在 2 分钟内把各桌面的状态按钮都点成亮色；
;        点一下就检查一次，确认变亮才算完成；已经亮了的
;        桌面不再点；等待图标还在时不点，等它走了再试。
;      第 3 步 空闲 40 分钟：
;        切回桌面 1，继续轮询，但只按 X 不按 G；光标旁一直
;        显示 40 分钟倒计时；这 40 分钟里一直检查状态按钮，
;        不是亮色的就点成亮色。
;      第 4 步 转暗 2 分钟：
;        在 2 分钟内把各桌面的状态按钮都点成暗色并确认成功；
;        这 2 分钟里照样轮询按 G、X。
;      第 5 步 轮询 15 分钟：
;        只做轮询按 G、X，不判断等待图标和状态按钮的颜色；
;        15 分钟结束后把三个桌面的状态按钮都点成亮色。
;      然后重复第 3、4、5 步（空闲 40 分钟 -> 转暗 -> 轮询
;      15 分钟 -> 转亮），一直循环。
;      暂停：没有单独的暂停按钮，暂停是自动的——只要你动了
;      鼠标或键盘，轮询和开箱子都会马上停下；等你 3 秒没再
;      动鼠标键盘，就自动从停下的地方继续，阶段计时也跟着停
;      （比如空闲 40 分钟的倒计时，暂停多久就往后顺延多久）。
;      脚本自己发的按键和点击不算，不会把自己暂停。想手动
;      暂停就按 F8，再按一次 F8 继续；F11 是停止（再启动会
;      从校准重新开始），F9 是全部停止。
;   2. 开箱子（两点点击 + 右键点击合并）：
;      左边按钮：两种点击同时操作
;        两点点击：(700,450) 点一下 -> (822,450) 点一下，循环
;        右键点击：同时在 (980,593) 定时右键
;      中间按钮：抽奖（只做右键点击）
;        只在 (980,593) 定时右键，两点点击不启动
;      右边按钮：合成（只做点击移动点击，即两点点击）
;        只做两点点击，右键点击不启动
;      三个按钮互斥：点另一个会先停掉当前模式再启动新模式；
;      再点一次正在运行的按钮就是停止。
;
; 使用：双击运行本脚本，点按钮或按快捷键即可。
;       F11 开关桌面轮询，F12 开关开箱子，F9 统一暂停（不退出）。
;       点“保存配置”会把界面里当前填的坐标、间隔、按键存到
;       同目录的 Atlantica_Config.ini，下次打开自动恢复。
;       关窗口或点“退出”即全部停止并退出。
; 注意：功能 1 需要 VirtualDesktopAccessor.dll 和 FindText.ahk
;       都放在本脚本同目录，DLL 版本要和你的 Windows 版本
;       匹配，否则该功能会被禁用。
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
DesktopKey2 := "x"      ; 每次按 G 后再按的第二个键
KeyGapMs := 50          ; 按 G 和按 X 之间相隔的毫秒数（约 0.05 秒）
SwitchClickX := 212     ; 每次切换后要点的固定位置
SwitchClickY := 57

; ===== 轮询循环（功能 1）的阶段和计时 =====
; CyclePhase：calibrate 校准 2 分钟 -> toBright 转亮 2 分钟
;   -> idle 空闲 40 分钟 -> toDark 转暗 2 分钟
;   -> poll 轮询 15 分钟 -> toBright 转亮 2 分钟 -> idle ...
; DesktopPhase 是每一步的小阶段：switch 切桌面、click212 点
; 切换后坐标、click 原地点击、press 按 G、pressX 约 0.05 秒后
; 检查图标再决定按不按 X（空闲阶段不按 G，只按 X，同样先
; 检查），另加 calibCheck 校准检查、toggleCheck 亮暗检查、
; toggleVerify 点完验证。
CyclePhase := ""
CycleStart := 0
CycleCount := 0
CurrentDesktop := 0
CalibrateMinutes := 2
ToggleMinutes := 2
IdleMinutes := 40
PollMinutes := 15
VerifyMs := 800         ; 点完状态按钮后等多久再检查是否变色
CenterOffsetY := 20     ; 状态按钮顶部条带中心到圆盘中心的距离
ResumeIdleMs := 3000    ; 停止操作多久后自动继续（毫秒）
ManualPaused := false   ; F8 手动暂停的开关
PauseStartTick := 0     ; 本次暂停开始的时间，0 表示没在暂停
; 校准时记下的坐标（下标从 1 开始，对应桌面 1、2、3……）
; 0 表示该桌面还没找到这个点。
CalWaitX := []
CalWaitY := []
CalStatusX := []
CalStatusY := []
CalOK := []
DoneBright := []        ; 转亮阶段：这个桌面是否已完成
DoneDark := []          ; 转暗阶段：这个桌面是否已完成
VerifyDesktop := -1     ; 正在验证的桌面（从 0 开始），-1 表示没有
VerifyTarget := ""      ; 正在验证的目标："bright" 或 "dark"

; ===== FindText 图案（功能 1 用）=====
; 等待图标：FindText_Icon_Check 那个图标（紫底银色物，45x41）。
; 它在的时候，亮暗状态按钮还没出来，不能点，只能等它走。
TextBlocker := "|<icon>*77$45.Tzzzzzzvzzzzzzzzzzzzzzz0000003Hzzzzzz+Tzzzzzxrzzzzzzizz3zzzxLzk7zzzizyEzzzxrzU6TzzizwUw1zxLzU7sHzizyUsGzxLzoT3Fzezy0s8DxLzm76bzizkFw3zxrw0AYTziz001UTxLs0D0Bzey80y0jxrl00k1jiz900CRxrxb007zizlz0Dzxrz3z1zzizs7z7zxLzY7lzzizws6DzxrznsDzzizzDszzxrzyTzzzizzwzzjxrzztzzzizzztzzxrzzzzzzjzzzzzzzw000000w"
; 状态按钮：圆形金框圆盘的顶部条带（45x10，没有数字，也没有
; 截图四角的游戏背景），亮版和暗版各一个图案，哪个找到就是哪个。
TextBright := "|<bright_top>*138$45.zzz0zzzzzw00Dzzzy7zsTzzz3U1kzzzVU01lzzsU0037zyM0006Tza0000Nzt00001byE03U06TU"
TextDark := "|<dark_top>*110$45.zzzU1zzzzz001zzzzU001zzzk7zs3zzw7zzwDzz3zzzszzkzzzzXzwTzzzzDz7zzzzwzlzzzzznU"
FindErr1 := 0.1         ; FindText 容错，图标像素（0.1 = 10%）
FindErr0 := 0.1         ; FindText 容错，背景像素（0.1 = 10%）

ClickMode := ""         ; "" = 未运行，"both" = 两种同时，"right" = 仅右键（抽奖），"two" = 仅两点点击（合成）
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

; ===== 配置文件（保存配置按钮用，下次打开自动恢复）=====
; 文件不存在时用下面这些默认值，保存过一次后就用保存过的值。
ConfigFile := A_ScriptDir "\Atlantica_Config.ini"
CfgDesktopWait := IniRead(ConfigFile, "Desktop", "WaitMs", "1000")
CfgDesktopKey := IniRead(ConfigFile, "Desktop", "Key", "g")
CfgSwitchX := IniRead(ConfigFile, "Desktop", "SwitchX", "212")
CfgSwitchY := IniRead(ConfigFile, "Desktop", "SwitchY", "57")
CfgPoint1X := IniRead(ConfigFile, "Click", "Point1X", "700")
CfgPoint1Y := IniRead(ConfigFile, "Click", "Point1Y", "450")
CfgPoint2X := IniRead(ConfigFile, "Click", "Point2X", "822")
CfgPoint2Y := IniRead(ConfigFile, "Click", "Point2Y", "450")
CfgWaitAfterFirst := IniRead(ConfigFile, "Click", "WaitAfterFirst", "1000")
CfgWaitAfterSecond := IniRead(ConfigFile, "Click", "WaitAfterSecond", "2000")
CfgRightX := IniRead(ConfigFile, "Click", "RightX", "980")
CfgRightY := IniRead(ConfigFile, "Click", "RightY", "593")
CfgRightInterval := IniRead(ConfigFile, "Click", "RightInterval", "3500")

; ===== 图形界面 =====
MyGui := Gui(, "Atlantica 功能菜单")
MyGui.SetFont("s10")

MyGui.Add("Text", "x10 y10 w360", "打开后点下面的功能按钮即可开始，再点一次停止。")

; ---- 功能 1：桌面轮询 ----
MyGui.Add("Text", "x10 y40 w360", "1. 桌面轮询 (F11)")
MyGui.Add("Text", "x10 y65 w70", "每步间隔(ms):")
edtDesktopWait := MyGui.Add("Edit", "x85 y62 w70", CfgDesktopWait)
MyGui.Add("Text", "x165 y65 w40", "按键:")
edtDesktopKey := MyGui.Add("Edit", "x205 y62 w50", CfgDesktopKey)
MyGui.Add("Text", "x10 y95 w90", "切换后点击 X:")
edtSwitchX := MyGui.Add("Edit", "x100 y92 w60", CfgSwitchX)
MyGui.Add("Text", "x170 y95 w15", "Y:")
edtSwitchY := MyGui.Add("Edit", "x185 y92 w60", CfgSwitchY)
btnDesktop := MyGui.Add("Button", "x10 y125 w360 h30", "开始：桌面轮询")
btnDesktop.OnEvent("Click", ToggleDesktop)
txtDesktopStatus := MyGui.Add("Text", "x10 y160 w360", "状态：未运行")

; ---- 功能 2：开箱子（两点点击 + 右键点击）----
MyGui.Add("Text", "x10 y190 w360", "2. 开箱子 (F12)")
MyGui.Add("Text", "x10 y215 w50", "点 1 X:")
edtP1X := MyGui.Add("Edit", "x60 y212 w55", CfgPoint1X)
MyGui.Add("Text", "x125 y215 w15", "Y:")
edtP1Y := MyGui.Add("Edit", "x140 y212 w55", CfgPoint1Y)
MyGui.Add("Text", "x205 y215 w50", "点 2 X:")
edtP2X := MyGui.Add("Edit", "x255 y212 w55", CfgPoint2X)
MyGui.Add("Text", "x320 y215 w15", "Y:")
edtP2Y := MyGui.Add("Edit", "x335 y212 w35", CfgPoint2Y)
MyGui.Add("Text", "x10 y242 w80", "点 1 后等(ms):")
edtWait1 := MyGui.Add("Edit", "x95 y239 w60", CfgWaitAfterFirst)
MyGui.Add("Text", "x165 y242 w80", "点 2 后等(ms):")
edtWait2 := MyGui.Add("Edit", "x250 y239 w60", CfgWaitAfterSecond)
MyGui.Add("Text", "x10 y272 w50", "右键 X:")
edtRightX := MyGui.Add("Edit", "x60 y269 w60", CfgRightX)
MyGui.Add("Text", "x130 y272 w15", "Y:")
edtRightY := MyGui.Add("Edit", "x145 y269 w60", CfgRightY)
MyGui.Add("Text", "x215 y272 w60", "间隔(ms):")
edtRightInterval := MyGui.Add("Edit", "x280 y269 w70", CfgRightInterval)
btnBoth := MyGui.Add("Button", "x10 y300 w150 h30", "两种点击同时操作")
btnBoth.OnEvent("Click", ToggleBoth)
btnRightOnly := MyGui.Add("Button", "x165 y300 w100 h30", "抽奖")
btnRightOnly.OnEvent("Click", ToggleRightOnly)
btnSynth := MyGui.Add("Button", "x270 y300 w100 h30", "合成")
btnSynth.OnEvent("Click", ToggleSynth)
txtClickStatus := MyGui.Add("Text", "x10 y335 w360", "状态：未运行")

; ---- 底部 ----
btnStopAll := MyGui.Add("Button", "x10 y365 w115 h30", "全部停止")
btnStopAll.OnEvent("Click", StopAll)
btnSaveConfig := MyGui.Add("Button", "x132 y365 w115 h30", "保存配置")
btnSaveConfig.OnEvent("Click", SaveConfig)
btnExit := MyGui.Add("Button", "x254 y365 w115 h30", "退出")
btnExit.OnEvent("Click", (*) => ExitApp())
MyGui.Add("Text", "x10 y405 w360 h50", "提示：F11 桌面轮询（循环：校准 2 分钟 -> 转亮 2 分钟 -> 空闲 40 分钟 -> 转暗 2 分钟 -> 轮询 15 分钟 -> 转亮，一直重复），F12 开箱子，F9 全部停止（不退出）。动鼠标/键盘会自动暂停，3 秒无操作后自动继续；F8 手动暂停/继续。功能 1 需要同目录下的 VirtualDesktopAccessor.dll 和 FindText.ahk，DLL 版本须匹配 Windows。")
MyGui.OnEvent("Close", (*) => ExitApp())

; DLL 没加载成功时，禁用功能 1，不影响功能 2
if (DesktopCount < 1) {
    btnDesktop.Enabled := false
    txtDesktopStatus.Text := "状态：不可用（DLL 加载失败，请检查同目录的 VirtualDesktopAccessor.dll）"
}

MyGui.Show("w380 h460")

; ===== 功能 1：桌面轮询（循环版）=====
; F11 或点按钮启动：校准 2 分钟 -> 转亮 2 分钟 -> 空闲 40 分钟
; -> 转暗 2 分钟 -> 轮询 15 分钟 -> 转亮 2 分钟 -> 空闲 40 分钟
; -> ……一直重复，直到再按 F11 或 F9 停掉。
ToggleDesktop(*) {
    global DesktopRunning, DesktopPhase, DesktopWaitMs, DesktopKey, SwitchClickX, SwitchClickY
    global btnDesktop, txtDesktopStatus, edtDesktopWait, edtDesktopKey, edtSwitchX, edtSwitchY
    global CyclePhase, CycleStart, CycleCount, DesktopNext, CurrentDesktop, DesktopCount
    global CalWaitX, CalWaitY, CalStatusX, CalStatusY, CalOK, DoneBright, DoneDark
    if (DesktopRunning) {
        DesktopRunning := false
        CyclePhase := ""
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
    CycleCount++
    ; 校准记录清零，下标从 1 开始，对应桌面 1、2、3……
    CalWaitX := []
    CalWaitY := []
    CalStatusX := []
    CalStatusY := []
    CalOK := []
    DoneBright := []
    DoneDark := []
    Loop DesktopCount {
        CalWaitX.Push(0)
        CalWaitY.Push(0)
        CalStatusX.Push(0)
        CalStatusY.Push(0)
        CalOK.Push(false)
        DoneBright.Push(false)
        DoneDark.Push(false)
    }
    DesktopNext := 0
    CurrentDesktop := 0
    StartCyclePhase("calibrate")
    btnDesktop.Text := "停止：桌面轮询"
    StepDesktop()
}

; 切到一个新阶段：记下开始时间，从桌面 1 重新开始轮询。
StartCyclePhase(NewPhase) {
    global CyclePhase, CycleStart, DesktopPhase, DesktopNext, CurrentDesktop
    global DoneBright, DoneDark, DesktopCount, txtDesktopStatus, GoToDesktopNumberProc
    CyclePhase := NewPhase
    CycleStart := A_TickCount
    DesktopPhase := "switch"
    DesktopNext := 0
    CurrentDesktop := 0
    ToolTip()
    if (NewPhase = "calibrate") {
        txtDesktopStatus.Text := "状态：校准 2 分钟（轮询按 G，同时记录等待图标和状态按钮坐标）"
    } else if (NewPhase = "toBright") {
        DoneBright := []
        Loop DesktopCount {
            DoneBright.Push(false)
        }
        txtDesktopStatus.Text := "状态：转亮 2 分钟（继续轮询，把状态按钮点成亮色）"
    } else if (NewPhase = "idle") {
        ; 空闲也要一直检查是否亮色，所以完成记录清零，重新检查。
        DoneBright := []
        Loop DesktopCount {
            DoneBright.Push(false)
        }
        DllCall(GoToDesktopNumberProc, "Int", 0)
        txtDesktopStatus.Text := "状态：空闲 40 分钟（桌面 1，只按 X，继续检查转亮）"
    } else if (NewPhase = "toDark") {
        DoneDark := []
        Loop DesktopCount {
            DoneDark.Push(false)
        }
        txtDesktopStatus.Text := "状态：转暗 2 分钟（继续轮询按 G，把状态按钮点成暗色）"
    } else if (NewPhase = "poll") {
        txtDesktopStatus.Text := "状态：轮询 15 分钟（只按 G，不判断图标颜色）"
    }
}

; 检查当前阶段是否该结束了，结束了就切到下一阶段，返回 true。
CheckPhaseEnd() {
    global CyclePhase, CycleStart, CalibrateMinutes, ToggleMinutes, IdleMinutes, PollMinutes
    global DoneBright, DoneDark
    Elapsed := A_TickCount - CycleStart
    if (CyclePhase = "calibrate") {
        if (Elapsed >= CalibrateMinutes * 60000) {
            StartCyclePhase("toBright")
            return true
        }
    } else if (CyclePhase = "toBright") {
        if (AllDone(DoneBright) || Elapsed >= ToggleMinutes * 60000) {
            StartCyclePhase("idle")
            return true
        }
    } else if (CyclePhase = "idle") {
        if (Elapsed >= IdleMinutes * 60000) {
            StartCyclePhase("toDark")
            return true
        }
    } else if (CyclePhase = "toDark") {
        if (AllDone(DoneDark) || Elapsed >= ToggleMinutes * 60000) {
            StartCyclePhase("poll")
            return true
        }
    } else if (CyclePhase = "poll") {
        if (Elapsed >= PollMinutes * 60000) {
            StartCyclePhase("toBright")
            return true
        }
    }
    return false
}

; 毫秒转 MM:SS（倒计时显示用）。
FormatMMSS(Ms) {
    if (Ms < 0) {
        Ms := 0
    }
    M := Ms // 60000
    S := Mod(Ms // 1000, 60)
    return Format("{:02d}:{:02d}", M, S)
}

; 空闲阶段时在光标提示前面加倒计时，其他阶段返回空串。
IdlePrefix() {
    global CyclePhase, CycleStart, IdleMinutes
    if (CyclePhase != "idle") {
        return ""
    }
    Left := IdleMinutes * 60000 - (A_TickCount - CycleStart)
    return "Idle " . FormatMMSS(Left) . " - "
}

; 用户是不是正在用电脑：手动暂停了，或者 ResumeIdleMs 毫秒内
; 有过鼠标/键盘操作。A_TimeIdlePhysical 只算真实的物理操作，
; 脚本自己发的按键和点击不算，所以脚本不会把自己暂停。
UserBusy() {
    global ManualPaused, ResumeIdleMs
    return ManualPaused || (A_TimeIdlePhysical < ResumeIdleMs)
}

; 轮询的暂停检查：暂停返回 true，恢复返回 false。
; 暂停期间阶段计时跟着停，恢复时把暂停的时间补回 CycleStart，
; 比如空闲倒计时暂停多久就往后顺延多久。
CheckPaused() {
    global ManualPaused, PauseStartTick, CycleStart, ResumeIdleMs
    if (!ManualPaused && A_TimeIdlePhysical >= ResumeIdleMs) {
        if (PauseStartTick != 0) {
            CycleStart += (A_TickCount - PauseStartTick)
            PauseStartTick := 0
        }
        return false
    }
    if (PauseStartTick = 0) {
        PauseStartTick := A_TickCount
    }
    return true
}

; 全屏找一个 FindText 图案，找到返回 true，OutX/OutY 是图案中心。
FindOne(Text, &OutX, &OutY) {
    global FindErr1, FindErr0
    OutX := 0
    OutY := 0
    try {
        ok := FindText(&OutX, &OutY, 0, 0, A_ScreenWidth, A_ScreenHeight, FindErr1, FindErr0, Text)
    } catch {
        return false
    }
    return (ok.Length > 0)
}

IsBlockerPresent() {
    global TextBlocker
    X := 0
    Y := 0
    return FindOne(TextBlocker, &X, &Y)
}

IsBrightPresent(&OutX, &OutY) {
    global TextBright
    return FindOne(TextBright, &OutX, &OutY)
}

IsDarkPresent(&OutX, &OutY) {
    global TextDark
    return FindOne(TextDark, &OutX, &OutY)
}

; 决定要不要按 X：只有看到等待图标、没看到状态按钮时才按。
; 等待图标在，状态按钮一般不在；如果状态按钮在，就不按 X；
; 两个都没看到，也不按 X。
ShouldPressX() {
    if (!IsBlockerPresent()) {
        return false
    }
    BX := 0
    BY := 0
    if (IsBrightPresent(&BX, &BY)) {
        return false
    }
    DX := 0
    DY := 0
    if (IsDarkPresent(&DX, &DY)) {
        return false
    }
    return true
}

CountDone(DoneList) {
    global DesktopCount
    N := 0
    Loop DesktopCount {
        if (DoneList[A_Index]) {
            N++
        }
    }
    return N
}

AllDone(DoneList) {
    global DesktopCount
    if (DesktopCount < 1) {
        return true
    }
    return (CountDone(DoneList) >= DesktopCount)
}

; 校准进度，如 "D1 OK D2 OK D3 -- "。
CalibSummary() {
    global DesktopCount, CalOK
    S := ""
    Loop DesktopCount {
        if (CalOK[A_Index]) {
            S .= "D" . A_Index . " OK "
        } else {
            S .= "D" . A_Index . " -- "
        }
    }
    return S
}

; 轮询主循环：一个定时器驱动的状态机，每步做完再约下一步。
StepDesktop() {
    global DesktopRunning, CyclePhase, CycleStart, DesktopPhase, DesktopNext, CurrentDesktop
    global DesktopCount, DesktopKey, DesktopKey2, KeyGapMs, GoToDesktopNumberProc, DesktopWaitMs, SwitchClickX, SwitchClickY
    global CalibrateMinutes, ToggleMinutes, IdleMinutes, PollMinutes, txtDesktopStatus
    if (!DesktopRunning) {
        return
    }
    ; 暂停：你动了鼠标/键盘，或按了 F8 手动暂停，就停在这里，
    ; 什么都不做；3 秒没再动就自动从停下的地方继续。
    if (CheckPaused()) {
        ToolTip("Paused - using mouse/keyboard, auto resume after 3s idle (F8 to resume)")
        txtDesktopStatus.Text := "状态：已暂停（检测到鼠标/键盘操作，3 秒无操作后自动继续；F8 手动继续）"
        SetTimer(StepDesktop, 250)
        return
    }
    ; 先看阶段是否结束（空闲 40 分钟到时间就切到转暗）。
    if (CheckPhaseEnd()) {
        SetTimer(StepDesktop, 250)
        return
    }
    ; 空闲阶段：状态栏显示倒计时，其他和轮询一样，只是按 X 不按 G。
    if (CyclePhase = "idle") {
        Left := IdleMinutes * 60000 - (A_TickCount - CycleStart)
        txtDesktopStatus.Text := "状态：空闲 40 分钟，剩余 " FormatMMSS(Left) "（只按 X，继续检查转亮）"
    }
    if (DesktopPhase = "switch") {
        CurrentDesktop := DesktopNext
        DllCall(GoToDesktopNumberProc, "Int", CurrentDesktop)
        DesktopNext := Mod(DesktopNext + 1, DesktopCount)
        if (CyclePhase = "idle") {
            Left := IdleMinutes * 60000 - (A_TickCount - CycleStart)
            ToolTip("Idle " FormatMMSS(Left) " left - Desktop " (CurrentDesktop + 1))
        }
        DesktopPhase := "click212"
        SetTimer(StepDesktop, 500)   ; 切换后先停 0.5 秒
    } else if (DesktopPhase = "click212") {
        Click(SwitchClickX, SwitchClickY)
        DesktopPhase := "click"
        SetTimer(StepDesktop, 500)   ; 点完再停 0.5 秒
    } else if (DesktopPhase = "click") {
        Click()
        DesktopPhase := "press"
        SetTimer(StepDesktop, DesktopWaitMs)
    } else if (DesktopPhase = "press") {
        if (CyclePhase = "idle") {
            ; 空闲只按 X，不按 G；而且只有看到等待图标时才按 X。
            if (ShouldPressX()) {
                Send(DesktopKey2)
            }
            DesktopPhase := "toggleCheck"
            SetTimer(StepDesktop, 300)
        } else {
            Send(DesktopKey)    ; 先按 G
            DesktopPhase := "pressX"
            SetTimer(StepDesktop, KeyGapMs)   ; 约 0.05 秒后检查再按 X
        }
    } else if (DesktopPhase = "pressX") {
        ; 只有看到等待图标、没看到状态按钮时才按 X。
        if (ShouldPressX()) {
            Send(DesktopKey2)
        }
        if (CyclePhase = "calibrate") {
            DesktopPhase := "calibCheck"
            SetTimer(StepDesktop, 300)
        } else if (CyclePhase = "toBright" || CyclePhase = "toDark") {
            DesktopPhase := "toggleCheck"
            SetTimer(StepDesktop, 300)
        } else {
            ; poll 阶段：只轮询，不检查图标。
            DesktopPhase := "switch"
            SetTimer(StepDesktop, DesktopWaitMs)
        }
    } else if (DesktopPhase = "calibCheck") {
        CalibCheckStep()
    } else if (DesktopPhase = "toggleCheck") {
        ToggleCheckStep()
    } else if (DesktopPhase = "toggleVerify") {
        ToggleVerifyStep()
    }
}

; 校准检查：每轮到一个桌面就找一次等待图标和状态按钮，
; 找到就记下坐标，光标旁提示找到的位置。
CalibCheckStep() {
    global CurrentDesktop, DesktopPhase, DesktopWaitMs, txtDesktopStatus
    global CalWaitX, CalWaitY, CalStatusX, CalStatusY, CalOK, TextBlocker
    global CycleStart, CalibrateMinutes, CenterOffsetY
    Idx := CurrentDesktop + 1
    WX := 0
    WY := 0
    WaitFound := FindOne(TextBlocker, &WX, &WY)
    if (WaitFound) {
        CalWaitX[Idx] := WX
        CalWaitY[Idx] := WY
    }
    BX := 0
    BY := 0
    StatusFound := false
    StatusState := ""
    if (IsBrightPresent(&BX, &BY)) {
        CalStatusX[Idx] := BX
        CalStatusY[Idx] := BY + CenterOffsetY
        StatusFound := true
        StatusState := "bright"
    } else {
        DX := 0
        DY := 0
        if (IsDarkPresent(&DX, &DY)) {
            CalStatusX[Idx] := DX
            CalStatusY[Idx] := DY + CenterOffsetY
            StatusFound := true
            StatusState := "dark"
        }
    }
    CalOK[Idx] := (CalWaitX[Idx] != 0) && (CalStatusX[Idx] != 0)
    Left := CalibrateMinutes * 60000 - (A_TickCount - CycleStart)
    if (WaitFound && StatusFound) {
        ToolTip("Desktop " Idx ": Wait (" CalWaitX[Idx] ", " CalWaitY[Idx] ") Status (" CalStatusX[Idx] ", " CalStatusY[Idx] ") " StatusState " OK")
    } else if (StatusFound) {
        ToolTip("Desktop " Idx ": Wait not found, Status (" CalStatusX[Idx] ", " CalStatusY[Idx] ") " StatusState)
    } else if (WaitFound) {
        ToolTip("Desktop " Idx ": Wait (" CalWaitX[Idx] ", " CalWaitY[Idx] ") Status not found")
    } else {
        ToolTip("Desktop " Idx ": Wait not found, Status not found")
    }
    txtDesktopStatus.Text := "状态：校准 2 分钟，剩余 " FormatMMSS(Left) " - " CalibSummary()
    DesktopPhase := "switch"
    SetTimer(StepDesktop, DesktopWaitMs)
}

; 亮暗检查：每轮到一个桌面就检查一次，决定要不要点。
; 空闲阶段目标也是亮色，但不跳过已完成的桌面，每轮都重新检查。
ToggleCheckStep() {
    global CurrentDesktop, DesktopPhase, DesktopWaitMs, CyclePhase, VerifyDesktop, VerifyTarget
    global DoneBright, DoneDark, CalStatusX, CalStatusY, CenterOffsetY, VerifyMs
    Idx := CurrentDesktop + 1
    Prefix := IdlePrefix()
    Target := (CyclePhase = "toDark") ? "dark" : "bright"
    DoneList := (Target = "bright") ? DoneBright : DoneDark
    ; 转亮 / 转暗阶段：这个桌面本阶段已完成就跳过，不点。
    ; 空闲阶段不跳过，每轮都重新检查是不是亮色。
    if (CyclePhase != "idle" && DoneList[Idx]) {
        ToolTip(Prefix "Desktop " Idx ": already " Target)
        DesktopPhase := "switch"
        SetTimer(StepDesktop, DesktopWaitMs)
        return
    }
    ; 等待图标还在：状态按钮没出来，不点，下一轮再试。
    if (IsBlockerPresent()) {
        ToolTip(Prefix "Desktop " Idx ": Wait icon present, skip this pass")
        DesktopPhase := "switch"
        SetTimer(StepDesktop, DesktopWaitMs)
        return
    }
    if (Target = "bright") {
        BX := 0
        BY := 0
        if (IsBrightPresent(&BX, &BY)) {
            DoneBright[Idx] := true
            ToolTip(Prefix "Desktop " Idx ": already bright")
            DesktopPhase := "switch"
            SetTimer(StepDesktop, DesktopWaitMs)
            return
        }
        DX := 0
        DY := 0
        if (IsDarkPresent(&DX, &DY)) {
            ; 优先点校准时记下的坐标，没有才点这次找到的位置。
            if (CalStatusX[Idx] != 0) {
                Click(CalStatusX[Idx], CalStatusY[Idx])
            } else {
                Click(DX, DY + CenterOffsetY)
            }
            VerifyDesktop := CurrentDesktop
            VerifyTarget := "bright"
            DesktopPhase := "toggleVerify"
            SetTimer(StepDesktop, VerifyMs)
            ToolTip(Prefix "Desktop " Idx ": clicked dark, verifying")
            return
        }
        ToolTip(Prefix "Desktop " Idx ": no status icon found, retry later")
        DesktopPhase := "switch"
        SetTimer(StepDesktop, DesktopWaitMs)
        return
    }
    ; Target = dark
    DX := 0
    DY := 0
    if (IsDarkPresent(&DX, &DY)) {
        DoneDark[Idx] := true
        ToolTip(Prefix "Desktop " Idx ": already dark")
        DesktopPhase := "switch"
        SetTimer(StepDesktop, DesktopWaitMs)
        return
    }
    BX := 0
    BY := 0
    if (IsBrightPresent(&BX, &BY)) {
        if (CalStatusX[Idx] != 0) {
            Click(CalStatusX[Idx], CalStatusY[Idx])
        } else {
            Click(BX, BY + CenterOffsetY)
        }
        VerifyDesktop := CurrentDesktop
        VerifyTarget := "dark"
        DesktopPhase := "toggleVerify"
        SetTimer(StepDesktop, VerifyMs)
        ToolTip(Prefix "Desktop " Idx ": clicked bright, verifying")
        return
    }
    ToolTip(Prefix "Desktop " Idx ": no status icon found, retry later")
    DesktopPhase := "switch"
    SetTimer(StepDesktop, DesktopWaitMs)
}

; 点完验证：等 0.8 秒后再找一次目标颜色，找到了才算完成。
ToggleVerifyStep() {
    global VerifyDesktop, VerifyTarget, DoneBright, DoneDark, DesktopPhase, DesktopWaitMs
    Idx := VerifyDesktop + 1
    Prefix := IdlePrefix()
    if (VerifyTarget = "bright") {
        BX := 0
        BY := 0
        if (IsBrightPresent(&BX, &BY)) {
            DoneBright[Idx] := true
            ToolTip(Prefix "Desktop " Idx ": now bright")
        } else {
            ToolTip(Prefix "Desktop " Idx ": not bright yet, will retry")
        }
    } else {
        DX := 0
        DY := 0
        if (IsDarkPresent(&DX, &DY)) {
            DoneDark[Idx] := true
            ToolTip(Prefix "Desktop " Idx ": now dark")
        } else {
            ToolTip(Prefix "Desktop " Idx ": not dark yet, will retry")
        }
    }
    DesktopPhase := "switch"
    SetTimer(StepDesktop, DesktopWaitMs)
}

; ===== 功能 2：开箱子 =====
UpdateClickButtons() {
    global ClickMode, btnBoth, btnRightOnly, btnSynth, txtClickStatus
    if (ClickMode = "both") {
        btnBoth.Text := "停止：两种点击同时操作"
        btnRightOnly.Text := "抽奖"
        btnSynth.Text := "合成"
        txtClickStatus.Text := "状态：运行中（开箱子：两种点击同时）"
    } else if (ClickMode = "right") {
        btnBoth.Text := "两种点击同时操作"
        btnRightOnly.Text := "停止：抽奖"
        btnSynth.Text := "合成"
        txtClickStatus.Text := "状态：运行中（抽奖）"
    } else if (ClickMode = "two") {
        btnBoth.Text := "两种点击同时操作"
        btnRightOnly.Text := "抽奖"
        btnSynth.Text := "停止：合成"
        txtClickStatus.Text := "状态：运行中（合成：两点点击）"
    } else {
        btnBoth.Text := "两种点击同时操作"
        btnRightOnly.Text := "抽奖"
        btnSynth.Text := "合成"
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

ToggleSynth(*) {
    global ClickMode, TwoRunning, TwoPhase, Point1X, Point1Y, Point2X, Point2Y, WaitAfterFirst, WaitAfterSecond
    global edtP1X, edtP1Y, edtP2X, edtP2Y, edtWait1, edtWait2
    if (ClickMode = "two") {
        StopClickLoops()
        ToolTip()
        return
    }
    for ctrl in [edtP1X, edtP1Y, edtP2X, edtP2Y, edtWait1, edtWait2] {
        if (!IsNumber(ctrl.Value)) {
            MsgBox("合成的坐标和间隔请都填数字。")
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
    TwoRunning := true
    TwoPhase := 0
    ClickMode := "two"
    UpdateClickButtons()
    StepTwo()
}

StepTwo() {
    global TwoPhase, Point1X, Point1Y, Point2X, Point2Y, WaitAfterFirst, WaitAfterSecond
    ; 你动了鼠标/键盘就暂停，不点，等 3 秒无操作后再继续。
    if (UserBusy()) {
        SetTimer(StepTwo, 500)
        return
    }
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
    ; 你动了鼠标/键盘就暂停，不点，下次定时到了再试。
    if (UserBusy()) {
        return
    }
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

; ===== 保存配置 =====
; 保存的是界面里当前填的值（不是正在运行的那份旧值），
; 存到脚本同目录的 Atlantica_Config.ini，下次打开自动恢复。
; 正在运行时点保存也不会停掉正在跑的功能。
SaveConfig(*) {
    global ConfigFile
    global edtDesktopWait, edtDesktopKey, edtSwitchX, edtSwitchY
    global edtP1X, edtP1Y, edtP2X, edtP2Y, edtWait1, edtWait2, edtRightX, edtRightY, edtRightInterval
    for ctrl in [edtDesktopWait, edtSwitchX, edtSwitchY, edtP1X, edtP1Y, edtP2X, edtP2Y, edtWait1, edtWait2, edtRightX, edtRightY, edtRightInterval] {
        if (!IsNumber(ctrl.Value)) {
            MsgBox("有坐标或间隔不是数字，配置没有保存，请先改成数字再点保存配置。")
            return
        }
    }
    if (edtDesktopKey.Value = "") {
        MsgBox("桌面轮询按键不能为空，配置没有保存。")
        return
    }
    IniWrite(edtDesktopWait.Value, ConfigFile, "Desktop", "WaitMs")
    IniWrite(edtDesktopKey.Value, ConfigFile, "Desktop", "Key")
    IniWrite(edtSwitchX.Value, ConfigFile, "Desktop", "SwitchX")
    IniWrite(edtSwitchY.Value, ConfigFile, "Desktop", "SwitchY")
    IniWrite(edtP1X.Value, ConfigFile, "Click", "Point1X")
    IniWrite(edtP1Y.Value, ConfigFile, "Click", "Point1Y")
    IniWrite(edtP2X.Value, ConfigFile, "Click", "Point2X")
    IniWrite(edtP2Y.Value, ConfigFile, "Click", "Point2Y")
    IniWrite(edtWait1.Value, ConfigFile, "Click", "WaitAfterFirst")
    IniWrite(edtWait2.Value, ConfigFile, "Click", "WaitAfterSecond")
    IniWrite(edtRightX.Value, ConfigFile, "Click", "RightX")
    IniWrite(edtRightY.Value, ConfigFile, "Click", "RightY")
    IniWrite(edtRightInterval.Value, ConfigFile, "Click", "RightInterval")
    MsgBox("配置已保存到：`n" ConfigFile "`n下次打开脚本会自动恢复这些坐标和间隔。")
}

; F12 用的开关：未运行时启动两种点击同时模式，
; 运行中（无论哪种模式）则暂停。
ToggleClickHotkey(*) {
    global ClickMode
    if (ClickMode != "") {
        StopClickLoops()
        ToolTip()
    } else {
        ToggleBoth()
    }
}

; F8 = 手动暂停 / 继续（轮询和开箱子都停，再按一次继续，
; 阶段计时跟着停；不用 F8 也行，动鼠标/键盘会自动暂停，
; 3 秒无操作后自动继续）。
ToggleManualPause(*) {
    global ManualPaused
    ManualPaused := !ManualPaused
    if (ManualPaused) {
        ToolTip("Paused manually (F8), press F8 again to resume")
    } else {
        ToolTip()
    }
}

; ===== 快捷键 =====
; F8  = 手动暂停 / 继续
; F11 = 桌面轮询 开启 / 停止（再启动会从校准重新开始）
; F12 = 开箱子 开启 / 暂停
; F9  = 统一暂停（全部停止，不退出程序，窗口还在，可再启动）
F8::ToggleManualPause()
F11::ToggleDesktop()
F12::ToggleClickHotkey()
F9::StopAll()

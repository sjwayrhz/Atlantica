#Requires AutoHotkey v2.0
#SingleInstance Force
#Include FindText.ahk

; ============================================================
; fenix 功能菜单（图形界面版，AHK v2）
; 原来的两个脚本已经合并到这一个窗口里，
; 不会出现两个脚本都抢 F8 的冲突。
;
; 功能：
;   1. 桌面轮询（F11）：按 F11 或点按钮启动后，三个桌面一直
;      轮询切换，停掉之前不会自己停。先检测 15 秒，再一直轮询。
;      切到每个桌面后，先激活游戏窗口（窗口是窗口模式跑的，
;      不激活的话按 G/X 进不去游戏；以前要手动点一下窗口，
;      现在脚本自己激活，不用手动点了）。先按窗口标题找：
;      标题是 "Atlantica Online Fenix"，三个桌面标题都一样，
;      但每个桌面只有一个游戏窗口，用 DLL 的
;      IsWindowOnCurrentVirtualDesktop 挑出当前桌面上的那一个
;      激活它，不会切到别的桌面去。标题找不到时再用图标位置
;      找（图标在当前桌面上，图标位置的窗口就是当前这个桌面的
;      游戏窗口）。
;      轮询时先看放映机图标和状态图标：放映机图标在、并且是
;      非暗色，就只按 X、不按 G；其他情况按 G，放映机图标在才
;      在约 0.05 秒后按 X。
;      状态图标是交叉双剑的方形图标：亮版底色浅蓝、暗版底色
;      深紫，图标里的数字会变，只认图案不看数字。只判断暗色：
;      找到暗版图案就是暗色，没找到就当非暗色（亮色），不单
;      独判断亮色。放映机图标是附件里那张放映机截图（45x39），
;      它在才说明能按 X、能点状态图标。
;      用 FindText 找图标：暗版一个 42x35 的黑白图案（阈值 120，
;      从你发的截图转出来的），暗版是深底浅剑；亮版图案只用来
;      定位亮色图标的位置、记下坐标，不参与亮暗判断。放映机图标一个
;      45x39 的图案（阈值 68）。暗版图案找到后，还要在图标中心
;      附近取一个 5x5 网格验亮度（亮点不到一半才是真暗色），因为
;      亮版图标底色浅、亮点多，图案万一认错亮版，亮度能把它拦下来。
;      记下位置后只在记录位置附近（中心 ±60/±50）找，范围收
;      小了，屏幕别处的暗色误匹配进不来。
;      之前用的 ImageSearch 模板图里带了会变的数字和游戏背景角，
;      数字一变、背景一换就整张对不上，所以完全找不到；FindText
;      只比图案本身的明暗形状，容错 0.1，数字变了也不影响。
;      记下图标中心后，只在记录位置附近找。
;      第 1 步 检测 15 秒：
;        同时在每个桌面找放映机图标和状态图标，记下各自中心
;        的坐标，光标旁会提示找到没有；这 15 秒只检测、不点
;        图标，按 G 还是按 X 和轮询一样。
;      第 2 步 一直轮询：
;        每轮到一个桌面：先看放映机图标和状态图标；放映机图标
;        在、并且是非暗色，就只按 X、不按 G；其他情况按 G，放映
;        机图标在才在约 0.05 秒后按 X；放映机图标在、并且状态
;        图标是暗色，才点状态图标一下，尝试帮它变亮色。放映
;        机图标不在，就只按 G，不按 X、不点。一直重复。
;      暂停：按 F8 手动暂停（轮询和开箱子都停），再按一次
;      F8 继续；检测 15 秒的计时暂停时也跟着停（暂停多久
;      就往后顺延多久）。F11 是停止（再启动会从检测重新
;      开始），F9 是全部停止。
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
;       同目录的 fenix_Config.ini，下次打开自动恢复。
;       关窗口或点“退出”即全部停止并退出。
; 注意：功能 1 需要 VirtualDesktopAccessor.dll 和 FindText.ahk
;       都放在本脚本同目录，DLL 版本要和你的
;       Windows 版本匹配，否则该功能会被禁用。
; ============================================================

CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")

; ===== 功能 1 的 DLL（先加载，失败也不影响功能 2）=====
DllPath := A_ScriptDir "\VirtualDesktopAccessor.dll"
hDll := DllCall("LoadLibrary", "Str", DllPath, "Ptr")
GoToDesktopNumberProc := 0
GetDesktopCountProc := 0
IsWindowOnCurrentVirtualDesktopProc := 0
DesktopCount := 0
if (hDll) {
    GoToDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "GoToDesktopNumber", "Ptr")
    GetDesktopCountProc := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "GetDesktopCount", "Ptr")
    IsWindowOnCurrentVirtualDesktopProc := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "IsWindowOnCurrentVirtualDesktop", "Ptr")
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
GameTitle := "Atlantica Online Fenix"  ; 游戏窗口标题（截图里看到的；三个桌面都一样，但每个桌面只有一个，用 DLL 挑当前桌面上的那一个）

; ===== 轮询循环（功能 1）的阶段和计时 =====
; CyclePhase：detect 检测 15 秒 -> main 一直轮询。
; DesktopPhase 是每一步的小阶段：switch 切桌面、activate 激活游戏窗口
; （先按标题找，找不到再用图标位置）、click212 点切换后坐标、click 原地点击、
; check 检查放映机图标和状态图标（决定按 G 还是只按 X、点不点
; 状态图标）、pressX 按 X 和点图标。
CyclePhase := ""
CycleStart := 0
CycleCount := 0
CurrentDesktop := 0
DetectSeconds := 15     ; 开头检测多少秒
ManualPaused := false   ; F8 手动暂停的开关
PauseStartTick := 0     ; 本次暂停开始的时间，0 表示没在暂停
; 检测时记下的图标中心坐标（下标从 1 开始，对应桌面 1、2、3……）
; 0 表示该桌面还没找到这个点。
CalStatusX := []        ; 状态图标（双剑）中心
CalStatusY := []
CalProjX := []          ; 放映机图标中心
CalProjY := []
CalOK := []
CheckProjFound := false ; 这轮检查：放映机图标在不在（check 步记下，pressX 步用）

; ===== 图标图案（功能 1 用，FindText）=====
; 状态图标：交叉双剑的方形图标，亮版底色浅蓝、暗版底色深紫，
; 图标里的数字会变，只认图案不看数字。亮版和暗版图案都是
; 42x35，阈值 120，从你发的两张截图裁出来的图标方形转的
; （亮版取 y 7-41、暗版取 y 2-36，都是 x 3-44）。亮版是浅底
; 深剑（暗像素只占约 9%），暗版是深底浅剑（暗像素约 83%），
; 两个图案几乎是反的，互相认不到对方。亮暗判断只看暗版图案：
; 找到暗版就是暗色，没找到就当非暗色（亮色）；亮版图案只用来
; 定位亮色图标的位置、记下坐标，不参与亮暗判断。
; 放映机图标：附件里那张放映机截图，45x39，阈值 68，整个图
; 标转的图案，里面没有会变的数字。它在不在，决定按不按 X、
; 点不点状态图标。
; FindText 返回的是图案中心，点图标中心用的就是这个坐标。
; 游戏里图标尺寸变了图案就对不上，到时把游戏实屏截图发我，
; 按实际尺寸重做图案。
; FindErr1/FindErr0 是 FindText 的容错（0.1 = 10%）：找不到
; 就调高，认错别的图标就调低。
FindErr1 := 0.1
FindErr0 := 0.1
BrightText := "|<Bright>*120$42.U000001000000000000000000000003zk00003zk10401zU20430z0k041UV1U040kS30040MA6E040A0A004060M004030k00001VU00400H0004000000400M000400Q000000S000000n000001VU000030k0000200000040A000000400000040000E06000000000000000000000000400080000000000000000000001U"
DarkText := "|<Dark>*120$42.U000001DzzzzzxTvzzzryTszzz7yTsTzy7yTwDzwDyTw7zsDyTz7zszyTzXVlzyTzlSXzyTzsy7zyTzwyDzyTzyETzyTzzAzzyTzzgzzyTzzGzzyTzzVzzyTzzvzzzTzzzzzzTzzzzzyTjzzzxyTjzzzxzTrvzzvzTzu1VzzTzqzSzzTz6zQzzTz63QzzTzrxSzzzzjxSzzzzjxSzzzzixSzzzzj1VzzzzTzzzzzTTzzyzzjzzzxzU"
ProjectorText := "|<projector>*68$45.Tzzzzzzv0000003Hzzzzzz+TzzzzzxLzwLzzzezz1zzzxLzk7zzzezy0zzzxLzU6T3zezw0s1zxLzU3EHzezw0sERxLzo701zezy0s0DxLzm764rezk0k1axLw084Srez001UCxLk0601zey80y0jxLl00k1jez8006NxLt0007jezUz07zxLz3z0zzezs3y7zxLzU7lzrezwM6DyxLzVs7zzezz7szzxLzwDzzzezzsTzbxLzzszbzezzzkXzxLzzzzzzfTzzzzzzQ000000vzzzzzzzSnk0008I"

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
ConfigFile := A_ScriptDir "\fenix_Config.ini"
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
MyGui := Gui(, "fenix 功能菜单")
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
MyGui.Add("Text", "x10 y405 w360 h50", "提示：F11 桌面轮询（先检测 15 秒，再一直轮询；放映机图标在才按 X、才点暗色的状态图标），F12 开箱子，F9 全部停止（不退出）。F8 手动暂停/继续。功能 1 需要同目录下的 VirtualDesktopAccessor.dll 和 FindText.ahk，DLL 版本须匹配 Windows。")
MyGui.OnEvent("Close", (*) => ExitApp())

; DLL 没加载成功时，禁用功能 1，不影响功能 2
if (DesktopCount < 1) {
    btnDesktop.Enabled := false
    txtDesktopStatus.Text := "状态：不可用（DLL 加载失败，请检查同目录的 VirtualDesktopAccessor.dll）"
}

MyGui.Show("w380 h460")

; ===== 功能 1：桌面轮询 =====
; F11 或点按钮启动：先检测 15 秒（轮询按 G，记录放映机图标
; 和状态图标的位置），再一直轮询，直到再按 F11 或 F9 停掉。
; 轮询时每轮按 G；放映机图标在，才按 X；放映机图标在、
; 并且状态图标是暗色，才点状态图标一下，尝试变亮色。
ToggleDesktop(*) {
    global DesktopRunning, DesktopPhase, DesktopWaitMs, DesktopKey, SwitchClickX, SwitchClickY
    global btnDesktop, txtDesktopStatus, edtDesktopWait, edtDesktopKey, edtSwitchX, edtSwitchY
    global CyclePhase, CycleStart, CycleCount, DesktopNext, CurrentDesktop, DesktopCount
    global CalStatusX, CalStatusY, CalProjX, CalProjY, CalOK
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
    ; 检测记录清零，下标从 1 开始，对应桌面 1、2、3……
    CalStatusX := []
    CalStatusY := []
    CalProjX := []
    CalProjY := []
    CalOK := []
    Loop DesktopCount {
        CalStatusX.Push(0)
        CalStatusY.Push(0)
        CalProjX.Push(0)
        CalProjY.Push(0)
        CalOK.Push(false)
    }
    DesktopNext := 0
    CurrentDesktop := 0
    StartCyclePhase("detect")
    btnDesktop.Text := "停止：桌面轮询"
    StepDesktop()
}

; 切到一个新阶段：记下开始时间，从桌面 1 重新开始轮询。
StartCyclePhase(NewPhase) {
    global CyclePhase, CycleStart, DesktopPhase, DesktopNext, CurrentDesktop
    global txtDesktopStatus
    CyclePhase := NewPhase
    CycleStart := A_TickCount
    DesktopPhase := "switch"
    DesktopNext := 0
    CurrentDesktop := 0
    ToolTip()
    if (NewPhase = "detect") {
        txtDesktopStatus.Text := "状态：检测 15 秒（轮询按 G，记录放映机图标和状态图标位置）"
    } else if (NewPhase = "main") {
        txtDesktopStatus.Text := "状态：轮询中（放映机图标在才按 X，暗色才点状态图标）"
    }
}
; 检查当前阶段是否该结束了，结束了就切到下一阶段，返回 true。
; 检查检测阶段是否结束（15 秒到了就切到一直轮询），返回 true。
CheckPhaseEnd() {
    global CyclePhase, CycleStart, DetectSeconds
    if (CyclePhase = "detect") {
        if (A_TickCount - CycleStart >= DetectSeconds * 1000) {
            StartCyclePhase("main")
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



; 是不是手动暂停了（F8）：轮询和开箱子都用这个判断。
UserBusy() {
    global ManualPaused
    return ManualPaused
}

; 轮询的暂停检查（只认 F8 手动暂停）：暂停返回 true，恢复返回 false。
; 暂停期间检测计时跟着停，恢复时把暂停的时间补回 CycleStart。
CheckPaused() {
    global ManualPaused, PauseStartTick, CycleStart
    if (!ManualPaused) {
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

; 把一次找到的结果记到脚本同目录的 fenix_Find_Log.txt，
; 方便查为什么会认错（坐标和找到哪个图案都在里面）。
LogFind(Msg) {
    try {
        FileAppend(Format("{:02d}:{:02d}:{:02d} ", A_Hour, A_Min, A_Sec) . Msg . "`n", A_ScriptDir . "\fenix_Find_Log.txt", "UTF-8")
    } catch {
    }
}

; 在指定矩形里用 FindText 找一个图案：找到返回 true，CX/CY 是
; 图案中心（FindText 直接返回图案中心，点图标用的就是这个
; 坐标）；没找到返回 false。坐标会夹到屏幕内，FindText 报错
; （如图案写错）时当没找到处理。
FindPattern(Text, X1, Y1, X2, Y2, &CX, &CY) {
    global FindErr1, FindErr0
    CX := 0
    CY := 0
    if (X1 < 0) {
        X1 := 0
    }
    if (Y1 < 0) {
        Y1 := 0
    }
    if (X2 > A_ScreenWidth) {
        X2 := A_ScreenWidth
    }
    if (Y2 > A_ScreenHeight) {
        Y2 := A_ScreenHeight
    }
    FX := 0
    FY := 0
    try {
        if (FindText(&FX, &FY, X1, Y1, X2, Y2, FindErr1, FindErr0, Text).Length) {
            CX := FX
            CY := FY
            return true
        }
    } catch {
    }
    return false
}

; 在当前桌面找一个图标：有记录时只在记录位置附近找（中心
; ±60/±50），这样屏幕别处的误匹配就进不来；没记录时才全屏
; 找。找到返回 true，OutX/OutY 是图标中心。
FindIcon(Pattern, RecX, RecY, &OutX, &OutY) {
    OutX := 0
    OutY := 0
    if (RecX != 0) {
        return FindPattern(Pattern, RecX - 60, RecY - 50, RecX + 60, RecY + 50, &OutX, &OutY)
    }
    return FindPattern(Pattern, 0, 0, A_ScreenWidth, A_ScreenHeight, &OutX, &OutY)
}

; 找放映机图标（Idx 是桌面序号，从 1 开始）。
FindProjector(Idx, &OutX, &OutY) {
    global ProjectorText, CalProjX, CalProjY
    RX := (Idx >= 1 && Idx <= CalProjX.Length) ? CalProjX[Idx] : 0
    RY := (Idx >= 1 && Idx <= CalProjY.Length) ? CalProjY[Idx] : 0
    Found := FindIcon(ProjectorText, RX, RY, &OutX, &OutY)
    if (Found) {
        LogFind("D" . Idx . " projector FOUND (" . OutX . "," . OutY . ")")
    }
    return Found
}

; 在图标中心附近取一个 5x5 网格点的亮度，亮点（灰度>120）占一半
; 以上才是真亮色。亮版底色是浅蓝（亮点约 88%），暗版底色是
; 深紫（亮点约 16%，顶上有亮边的那张约 32%）。用亮点比例而
; 不用平均值，单个点落在剑上、数字上、亮边上都不会翻盘。
IconBright(CX, CY) {
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
        return false
    }
    Frac := Bright / N
    LogFind("brightness at (" CX "," CY ") bright " Bright "/" N " = " Round(Frac, 2))
    return (Frac > 0.5)
}

; 找亮版状态图标（只用来定位亮色图标的位置、记下坐标，不参与
; 亮暗判断）：找到亮版图案，还要用背景亮度再确认一次是真亮色
; （亮版底色浅蓝，暗版底色深紫）。图案认错的时候（比如暗版图标
; 顶上有亮边），亮度会把它拦下来，当没找到。
FindBright(Idx, &OutX, &OutY) {
    global BrightText, CalStatusX, CalStatusY
    RX := (Idx >= 1 && Idx <= CalStatusX.Length) ? CalStatusX[Idx] : 0
    RY := (Idx >= 1 && Idx <= CalStatusY.Length) ? CalStatusY[Idx] : 0
    Found := FindIcon(BrightText, RX, RY, &OutX, &OutY)
    if (!Found) {
        return false
    }
    if (!IconBright(OutX, OutY)) {
        LogFind("D" . Idx . " icon bright pattern found at (" . OutX . "," . OutY . ") but brightness says dark, treat as not found")
        return false
    }
    LogFind("D" . Idx . " icon bright FOUND (" . OutX . "," . OutY . ")")
    return true
}

; 找暗版状态图标（判断暗色用）：找到暗版图案，还要用背景亮度
; 再确认一次是真暗色（暗版底色深紫，亮版底色浅蓝）。图案认错
; 的时候，亮度会把它拦下来，当非暗色（亮色）。
FindDark(Idx, &OutX, &OutY) {
    global DarkText, CalStatusX, CalStatusY
    RX := (Idx >= 1 && Idx <= CalStatusX.Length) ? CalStatusX[Idx] : 0
    RY := (Idx >= 1 && Idx <= CalStatusY.Length) ? CalStatusY[Idx] : 0
    Found := FindIcon(DarkText, RX, RY, &OutX, &OutY)
    if (!Found) {
        return false
    }
    if (IconBright(OutX, OutY)) {
        LogFind("D" . Idx . " icon dark pattern found at (" . OutX . "," . OutY . ") but brightness says bright, treat as non-dark")
        return false
    }
    LogFind("D" . Idx . " icon dark FOUND (" . OutX . "," . OutY . ")")
    return true
}

; 按窗口标题激活当前桌面上的游戏窗口：标题是 "Atlantica Online Fenix"，
; 三个桌面标题都一样，但每个桌面只有一个游戏窗口；用 DLL 的
; IsWindowOnCurrentVirtualDesktop 挑出当前桌面上的那一个激活它，
; 不会切到别的桌面去。找到就返回 true，没找到返回 false。
ActivateGameByTitle() {
    global GameTitle, IsWindowOnCurrentVirtualDesktopProc
    if (!IsWindowOnCurrentVirtualDesktopProc) {
        return false
    }
    try {
        WinList := WinGetList(GameTitle)
    } catch {
        return false
    }
    for hWnd in WinList {
        try {
            OnCurrent := DllCall(IsWindowOnCurrentVirtualDesktopProc, "Ptr", hWnd, "Int")
        } catch {
            continue
        }
        if (OnCurrent) {
            try {
                WinActivate("ahk_id " hWnd)
                LogFind("activated game window by title, hwnd=" hWnd)
                return true
            } catch {
                return false
            }
        }
    }
    return false
}

; 在当前桌面找一个游戏图标（只为激活窗口定位用，标题找不到时才用）：
; 先试放映机图标，再试暗版状态图标，最后试亮版状态图标。
; 找到返回 true，OutX/OutY 是图标中心。
; 哪个图标都行，只要在游戏窗口上，能定位到窗口就行。
FindGameIcon(Idx, &OutX, &OutY) {
    if (FindProjector(Idx, &OutX, &OutY)) {
        return true
    }
    if (FindDark(Idx, &OutX, &OutY)) {
        return true
    }
    if (FindBright(Idx, &OutX, &OutY)) {
        return true
    }
    return false
}

; 把图标所在位置的窗口激活（标题找不到时才用这个办法）。
; 做法：鼠标移到图标上，取鼠标下的窗口，激活它。
; 图标在当前桌面上，所以图标位置的窗口一定是当前这个桌面的游戏窗口。
; 找到窗口就返回 true，没找到返回 false（找不到就照旧用点击来聚焦）。
ActivateGameWindow(IconX, IconY) {
    if (IconX = 0 || IconY = 0) {
        return false
    }
    WinID := 0
    try {
        MouseMove(IconX, IconY)
        Sleep(50)
        MouseGetPos(, , &WinID)
        if (WinID) {
            WinActivate("ahk_id " WinID)
            LogFind("activated game window at (" IconX "," IconY ") hwnd=" WinID)
            return true
        }
    } catch {
    }
    return false
}


; 检测进度，如 "D1 OK D2 OK D3 -- "。
DetectSummary() {
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
; 每轮：切桌面 -> 停 0.5 秒 -> 激活游戏窗口（先按标题找，找不到再用图标位置） -> 点 (212,57) -> 停 0.5 秒
; -> 原地点一下 -> 等 1000 毫秒 -> 检查放映机图标和状态图标
; （放映机图标在、并且是非暗色，就只按 X、不按 G；其他情况
; 按 G，放映机图标在才在约 0.05 秒后按 X；放映机图标在、
; 状态图标是暗色，才点状态图标）。检测阶段只记录位置和按
; G/X，不点图标。
StepDesktop() {
    global DesktopRunning, CyclePhase, CycleStart, DesktopPhase, DesktopNext, CurrentDesktop
    global DesktopCount, DesktopKey, KeyGapMs, GoToDesktopNumberProc, DesktopWaitMs, SwitchClickX, SwitchClickY
    global DetectSeconds, txtDesktopStatus
    if (!DesktopRunning) {
        return
    }
    ; 暂停：按了 F8 手动暂停，就停在这里，什么都不做；
    ; 再按一次 F8 继续。
    if (CheckPaused()) {
        ToolTip("Paused manually (F8), press F8 again to resume")
        txtDesktopStatus.Text := "状态：已暂停（F8 手动暂停，再按一次 F8 继续）"
        SetTimer(StepDesktop, 250)
        return
    }
    ; 先看检测阶段是否结束（15 秒到了就切到一直轮询）。
    if (CheckPhaseEnd()) {
        SetTimer(StepDesktop, 250)
        return
    }
    ; 检测阶段：状态栏显示倒计时。
    if (CyclePhase = "detect") {
        Left := DetectSeconds * 1000 - (A_TickCount - CycleStart)
        txtDesktopStatus.Text := "状态：检测 15 秒，剩余 " FormatMMSS(Left) "（记录图标位置）"
    }
    if (DesktopPhase = "switch") {
        CurrentDesktop := DesktopNext
        DllCall(GoToDesktopNumberProc, "Int", CurrentDesktop)
        DesktopNext := Mod(DesktopNext + 1, DesktopCount)
        if (CyclePhase = "detect") {
            Left := DetectSeconds * 1000 - (A_TickCount - CycleStart)
            ToolTip("Detect " FormatMMSS(Left) " left - Desktop " (CurrentDesktop + 1))
        }
        DesktopPhase := "activate"
        SetTimer(StepDesktop, 500)   ; 切换后先停 0.5 秒
    } else if (DesktopPhase = "activate") {
        ; 切完桌面先激活游戏窗口，这样后面的点击和按 G/X 才进游戏，
        ; 不用再手动点窗口。先按标题找（每个桌面只有一个游戏窗口，
        ; 用 DLL 挑出当前桌面上的那一个），找不到再用图标位置找；
        ; 两个都找不到就跳过，照旧用点击来聚焦。
        if (!ActivateGameByTitle()) {
            Idx := CurrentDesktop + 1
            IX := 0
            IY := 0
            if (FindGameIcon(Idx, &IX, &IY)) {
                ActivateGameWindow(IX, IY)
            } else {
                LogFind("D" Idx " activate: no window found by title or icon, skip activation")
            }
        }
        DesktopPhase := "click212"
        SetTimer(StepDesktop, 100)   ; 激活后稍停一下再点
    } else if (DesktopPhase = "click212") {
        Click(SwitchClickX, SwitchClickY)
        DesktopPhase := "click"
        SetTimer(StepDesktop, 500)   ; 点完再停 0.5 秒
    } else if (DesktopPhase = "click") {
        Click()
        DesktopPhase := "check"
        SetTimer(StepDesktop, DesktopWaitMs)
    } else if (DesktopPhase = "check") {
        if (CyclePhase = "detect") {
            DetectStep()
        } else {
            MainCheckStep()
        }
    } else if (DesktopPhase = "pressX") {
        PressXStep()
    }
}

; 检测检查：每轮到一个桌面就找一次放映机图标和状态图标，
; 找到就记下各自中心坐标，光标旁提示找到没有。这 15 秒
; 只检测、不点图标；按 G 还是按 X 和轮询一样（放映机图标
; 在、并且是非暗色就只按 X，其他情况按 G，放映机图标在才
; 在约 0.05 秒后按 X）。
DetectStep() {
    global CurrentDesktop, DesktopPhase, DesktopWaitMs, txtDesktopStatus
    global DesktopKey, DesktopKey2, KeyGapMs
    global CalStatusX, CalStatusY, CalProjX, CalProjY, CalOK
    global CycleStart, DetectSeconds
    Idx := CurrentDesktop + 1
    PX := 0
    PY := 0
    ProjFound := FindProjector(Idx, &PX, &PY)
    if (ProjFound) {
        CalProjX[Idx] := PX
        CalProjY[Idx] := PY
    }
    DX := 0
    DY := 0
    DarkFound := FindDark(Idx, &DX, &DY)
    State := ""
    if (DarkFound) {
        CalStatusX[Idx] := DX
        CalStatusY[Idx] := DY
        State := "dark"
    } else {
        BX := 0
        BY := 0
        if (FindBright(Idx, &BX, &BY)) {
            CalStatusX[Idx] := BX
            CalStatusY[Idx] := BY
            State := "non-dark"
        } else {
            State := "not found"
        }
    }
    CalOK[Idx] := (CalStatusX[Idx] != 0)
    ; 检测阶段也按轮询的规则按 G/X，只是绝不点图标。
    if (ProjFound && !DarkFound) {
        Send(DesktopKey2)   ; 放映机图标在、并且是非暗色，只按 X、不按 G
    } else {
        Send(DesktopKey)    ; 其他情况按 G
        if (ProjFound) {
            Sleep(KeyGapMs)
            Send(DesktopKey2)   ; 放映机图标在，约 0.05 秒后按 X
        }
    }
    Left := DetectSeconds * 1000 - (A_TickCount - CycleStart)
    ToolTip("Desktop " Idx ": projector " (ProjFound ? "yes" : "no") ", status " State)
    txtDesktopStatus.Text := "状态：检测 15 秒，剩余 " FormatMMSS(Left) " - " DetectSummary()
    DesktopPhase := "switch"
    SetTimer(StepDesktop, DesktopWaitMs)
}

; 轮询检查：每轮到一个桌面就先找放映机图标和状态图标，
; 再按下面规则做。只判断暗色：找到暗版图案就是暗色，
; 没找到就当非暗色（亮色）。
;   1. 放映机图标在、并且是非暗色：只按 X，不按 G，不点。
;   2. 其他情况：按 G；放映机图标在，才在约 0.05 秒后按 X。
;   3. 放映机图标在、并且是暗色，才点状态图标一下，
;      尝试帮它变亮色；点完下轮再来检查，不单独验证。
MainCheckStep() {
    global CurrentDesktop, DesktopPhase, DesktopWaitMs, DesktopKey, DesktopKey2, KeyGapMs
    global CalStatusX, CalStatusY, CalProjX, CalProjY, CheckProjFound
    Idx := CurrentDesktop + 1
    PX := 0
    PY := 0
    ProjFound := FindProjector(Idx, &PX, &PY)
    CheckProjFound := ProjFound
    if (ProjFound) {
        CalProjX[Idx] := PX
        CalProjY[Idx] := PY
    }
    DX := 0
    DY := 0
    DarkFound := FindDark(Idx, &DX, &DY)
    if (DarkFound) {
        CalStatusX[Idx] := DX
        CalStatusY[Idx] := DY
    } else {
        ; 非暗色：顺便找一下亮版图案，把亮色图标的位置也记下来，
        ; 下次找暗版时只在附近找，范围小、不容易认错别处。
        BX := 0
        BY := 0
        if (FindBright(Idx, &BX, &BY)) {
            CalStatusX[Idx] := BX
            CalStatusY[Idx] := BY
        }
    }
    if (ProjFound && !DarkFound) {
        ; 放映机图标在、并且是非暗色（亮色）：只按 X，不按 G，不点。
        Send(DesktopKey2)
        ToolTip("Desktop " Idx ": projector yes, non-dark, X only, no G, no click")
        DesktopPhase := "switch"
        SetTimer(StepDesktop, DesktopWaitMs)
        return
    }
    ; 其他情况：按 G，约 0.05 秒后到 pressX 步（放映机图标在才按 X）。
    Send(DesktopKey)
    DesktopPhase := "pressX"
    SetTimer(StepDesktop, KeyGapMs)
}

; 按 X 和点图标（轮询检查的下一步，约 0.05 秒后）。
; 放映机图标在才按 X；放映机图标在、并且是暗色，才点
; 状态图标一下。这里找暗版图案是再确认一次：按完 G 之后
; 如果图标已经变亮了（非暗色），暗版图案就找不到了，也就不会点错。
PressXStep() {
    global CurrentDesktop, DesktopPhase, DesktopWaitMs, DesktopKey2, CheckProjFound
    global CalStatusX, CalStatusY
    Idx := CurrentDesktop + 1
    if (!CheckProjFound) {
        ; 放映机图标不在：不按 X、不点（只按了 G）。
        ToolTip("Desktop " Idx ": projector no, no X, no click")
        DesktopPhase := "switch"
        SetTimer(StepDesktop, DesktopWaitMs)
        return
    }
    Send(DesktopKey2)   ; 放映机图标在，才按 X
    ; 到这里一定是暗色（非暗色的话检查步已经只按 X、直接回去了）。
    ; 再找暗版图案确认一次：按完 G 之后如果图标已经变亮了，
    ; 暗版图案就找不到了，也就不会点错。
    DX := 0
    DY := 0
    if (FindDark(Idx, &DX, &DY)) {
        CalStatusX[Idx] := DX
        CalStatusY[Idx] := DY
        Click(DX, DY)
        ToolTip("Desktop " Idx ": projector yes, dark, clicked to bright")
    } else {
        ToolTip("Desktop " Idx ": projector yes, dark, icon not found, no click")
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
    ; 按了 F8 手动暂停，就不点，等再按 F8 继续后再点。
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
    ; 按了 F8 手动暂停，就不点，下次定时到了再试。
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
; 存到脚本同目录的 fenix_Config.ini，下次打开自动恢复。
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
; 检测计时跟着停）。
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
; F11 = 桌面轮询 开启 / 停止（再启动会从检测重新开始）
; F12 = 开箱子 开启 / 暂停
; F9  = 统一暂停（全部停止，不退出程序，窗口还在，可再启动）
F8::ToggleManualPause()
F11::ToggleDesktop()
F12::ToggleClickHotkey()
F9::StopAll()

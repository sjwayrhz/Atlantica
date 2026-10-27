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
;      轮询切换，停掉之前不会自己停。
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
;      深紫，图标里的数字会变，只认图案不看数字。三种状态：
;      暗色（暗版图案找到）、未知（未知图案找到，全黑、剑也是
;      黑的、只有边框是亮的那种）、非暗色（两个都没找到，就当
;      亮色）。放映机图标是附件里那张放映机截图（45x39），
;      它在才说明能按 X、能点状态图标。
;      用 FindText 找图标：暗版一个 42x35 的黑白图案（阈值 120，
;      从你发的截图转出来的），暗版是深底浅剑；未知一个 46x41 的
;      黑白图案（阈值 82，从你发的截图整个图标转的），全黑、剑也
;      是黑的、只有边框亮；亮版图案只用来定位亮色图标的位置、记下
;      坐标，不参与亮暗判断。放映机图标一个 45x39 的图案（阈值 68）。
;      暗版图案找到后，还要在图标中心附近取一个 5x5 网格验亮度
;      （亮点不到一半才是真暗色），因为亮版图标底色浅、亮点多，
;      图案万一认错亮版，亮度能把它拦下来。未知图案和亮版、暗版
;      都认不到对方，图案本身就够了，不用再验亮度。
;      在游戏窗口里面全窗口找图标，不用记位置：窗口挪位置、
;      图标挪位置都能找到；窗口外面不找，屏幕别处的暗色
;      误匹配进不来。
;      之前用的 ImageSearch 模板图里带了会变的数字和游戏背景角，
;      数字一变、背景一换就整张对不上，所以完全找不到；FindText
;      只比图案本身的明暗形状，容错 0.1，数字变了也不影响。
;      轮询：
;        每轮到一个桌面：先激活游戏窗口，再在窗口里面找放映机
;        图标和状态图标；放映机图标在、并且是非暗色，就只按 X、
;        不按 G；未知图标按 G、按 X、不点图标；放映机图标在、并且
;        状态图标是暗色，才按 G、按 X、点状态图标一下，尝试帮它
;        变亮色。放映机图标不在，就只按 G，不按 X、不点。一直重复。
;      暂停：按 F8 手动暂停（轮询和开箱子都停），再按一次
;      F8 继续。F11 是停止（再启动从桌面 1 重新开始），F9 是全部停止。
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
;       桌面轮询只有开始和暂停两个按钮（暂停和 F8 一样），参数
;       不用界面填，用配置文件里的值（没保存过就用默认值）。
;       点“保存配置”会把开箱子界面里当前填的坐标、间隔存到
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
GetWindowDesktopNumberProc := 0
GetCurrentDesktopNumberProc := 0
DesktopCount := 0
if (hDll) {
    GoToDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "GoToDesktopNumber", "Ptr")
    GetDesktopCountProc := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "GetDesktopCount", "Ptr")
    IsWindowOnCurrentVirtualDesktopProc := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "IsWindowOnCurrentVirtualDesktop", "Ptr")
    GetWindowDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "GetWindowDesktopNumber", "Ptr")
    GetCurrentDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "GetCurrentDesktopNumber", "Ptr")
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
; 没有检测阶段了：每次到一个桌面，先激活游戏窗口，再找图标
; （放映机图标和状态图标），找到就按规则处理。位置都是固定
; 的：第一次全窗口找并记下位置，以后只在记录位置附近找。
; DesktopPhase 是每一步的小阶段：switch 切桌面、activate 激活游戏窗口
; （先按标题找，找不到再用图标位置）、click212 点切换后坐标、click 原地点击、
; check 检查放映机图标和状态图标（决定按 G 还是只按 X、点不点
; 状态图标）、pressX 按 X 和点图标。
CyclePhase := "main"
CycleCount := 0
CurrentDesktop := 0
ManualPaused := false   ; F8 手动暂停的开关
QuickSwitchEnabled := false ; 快捷切换桌面（键盘 F1/F2/F3）的开关，默认关
Recording := false        ; 是不是正在录鼠标
RecordEvents := []        ; 录下来的鼠标动作，每条是 [类型, X, Y, 间隔毫秒]
RecordLastTick := 0       ; 上一个录下来的动作是什么时候（A_TickCount）
RecordLastL := false      ; 上次轮询时左键是不是按着
RecordLastR := false      ; 上次轮询时右键是不是按着
PlayingBack := false      ; 是不是正在回放
; 刚激活的游戏窗口的位置和大小，找图标只在这个窗口里面找。
GameWinX := 0
GameWinY := 0
GameWinW := 0
GameWinH := 0
; 各桌面记下的图标中心坐标（下标从 1 开始，对应桌面 1、2、3……）
; 0 表示该桌面还没找到这个点（第一次全窗口找，找到就记下来）。
CalStatusX := []        ; 状态图标（双剑）中心
CalStatusY := []
CalProjX := []          ; 放映机图标中心
CalProjY := []
NonDarkSince := []     ; 每个桌面连续非暗色（亮色）是从什么时候开始的（A_TickCount），0 表示没在连续
NonDarkClickMs := 1200000 ; 连续非暗色超过 20 分钟，就点一下状态图标（怕是误判）
CheckProjFound := false ; 这轮检查：放映机图标在不在（check 步记下，pressX 步用）
CheckStatusNotFound := false ; 这轮检查：状态图标是不是都没找到（check 步记下，pressX 步用）

; ===== 图标图案（功能 1 用，FindText）=====
; 状态图标：交叉双剑的方形图标，亮版底色浅蓝、暗版底色深紫，
; 图标里的数字会变，只认图案不看数字。亮版和暗版图案都是
; 42x35，阈值 120，从你发的两张截图裁出来的图标方形转的
; （亮版取 y 7-41、暗版取 y 2-36，都是 x 3-44）。亮版是浅底
; 深剑（暗像素只占约 9%），暗版是深底浅剑（暗像素约 83%），
; 亮版和暗版图案几乎是反的，互相认不到对方。亮暗判断只看暗版图案：
; 找到暗版就是暗色；暗版没找到时再找未知图案，找到就是未知；
; 两个都没找到就当非暗色（亮色）。亮版图案只用来定位亮色图标的
; 位置、记下坐标，不参与亮暗判断。未知图案（46x41，阈值 82）和
; 亮版、暗版都认不到对方，见 StatusUnknown.png。
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
ProjErr1 := 0.2
ProjErr0 := 0.2
BrightText := "|<Bright>*120$42.U000001000000000000000000000003zk00003zk10401zU20430z0k041UV1U040kS30040MA6E040A0A004060M004030k00001VU00400H0004000000400M000400Q000000S000000n000001VU000030k0000200000040A000000400000040000E06000000000000000000000000400080000000000000000000001U"
DarkText := "|<Dark>*120$42.U000001DzzzzzxTvzzzryTszzz7yTsTzy7yTwDzwDyTw7zsDyTz7zszyTzXVlzyTzlSXzyTzsy7zyTzwyDzyTzyETzyTzzAzzyTzzgzzyTzzGzzyTzzVzzyTzzvzzzTzzzzzzTzzzzzyTjzzzxyTjzzzxzTrvzzvzTzu1VzzTzqzSzzTz6zQzzTz63QzzTzrxSzzzzjxSzzzzjxSzzzzixSzzzzj1VzzzzTzzzzzTTzzyzzjzzzxzU"
UnknownText := "|<Unknown>*82$46.zzzzzzzvzzzzzzzjzzzzzzzk000000yTzzzzztdzTzzyzqjwzzznzSzszzwTxfzVzzVzqjz3zwDzOzzDznzxfzwTyDzqjzszlzzOzznzDzxfzzbtzzqjzzDDzzOzzytzzxvzzxjzzrjzztzzzSzzzrzzxfzzzzzzqjzzzzzzOzzzzzzxfzzzzzzqjrzzzyzOzzzzzzxfzzzzzzqjzzzzzzOzyTztzxfztzzbzqjzzzzzzOzzzzzzxfzzzzzzqjzzzzzzOzzzPzzxfzzzzzzyjjzzzzTTzzzzzzzi000000SzzzzzzzvzzzzLzzz"
ProjectorText := "|<projector>*79$46.s000000TDzzzzzwwzzzzzzurzzzzzzfTzVzzzyhzw3zzzurzm7zzzfTy0Nzzyhzt3y3zurzk7sLzfTzEQBTyhzx7koTurzm711zfTz8SOTyhzUXs7zurw0AgTzfTU00kTyhy03k/Turl07k5zfTY030DyhyG00Svurxj007zfTszk7zyhzkzkTzurzUzszzfTyET7zyhztkATzurznsDzzfTzbwTzyhzzbzzzurzzbzxzfTzzbzzyhzzznzzurzzzzzzfzzzzzzzj000000D"
ProjectorTextOld := "|<projector>*68$45.Tzzzzzzv0000003Hzzzzzz+TzzzzzxLzwLzzzezz1zzzxLzk7zzzezy0zzzxLzU6T3zezw0s1zxLzU3EHzezw0sERxLzo701zezy0s0DxLzm764rezk0k1axLw084Srez001UCxLk0601zey80y0jxLl00k1jez8006NxLt0007jezUz07zxLz3z0zzezs3y7zxLzU7lzrezwM6DyxLzVs7zzezz7szzxLzwDzzzezzsTzbxLzzszbzezzzkXzxLzzzzzzfTzzzzzzQ000000vzzzzzzzSnk0008I"

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

; ---- 功能 1：桌面轮询 ----
MyGui.Add("Text", "x10 y10 w360", "1. 桌面轮询 (F11)")
btnDesktop := MyGui.Add("Button", "x10 y35 w175 h30", "开始：桌面轮询")
btnDesktop.OnEvent("Click", ToggleDesktop)
btnDesktopPause := MyGui.Add("Button", "x195 y35 w175 h30", "暂停")
btnDesktopPause.OnEvent("Click", ToggleManualPause)
txtDesktopStatus := MyGui.Add("Text", "x10 y70 w360", "状态：未运行")
MyGui.Add("Text", "x10 y90 w360 h2 +0x1000")

; ---- 功能 2：开箱子（两点点击 + 右键点击）----
MyGui.Add("Text", "x10 y100 w360", "2. 开箱子 (F12)")
MyGui.Add("Text", "x10 y125 w50", "点 1 X:")
edtP1X := MyGui.Add("Edit", "x60 y122 w55", CfgPoint1X)
MyGui.Add("Text", "x125 y125 w15", "Y:")
edtP1Y := MyGui.Add("Edit", "x140 y122 w55", CfgPoint1Y)
MyGui.Add("Text", "x205 y125 w50", "点 2 X:")
edtP2X := MyGui.Add("Edit", "x255 y122 w55", CfgPoint2X)
MyGui.Add("Text", "x320 y125 w15", "Y:")
edtP2Y := MyGui.Add("Edit", "x335 y122 w35", CfgPoint2Y)
MyGui.Add("Text", "x10 y152 w80", "点 1 后等(ms):")
edtWait1 := MyGui.Add("Edit", "x95 y149 w60", CfgWaitAfterFirst)
MyGui.Add("Text", "x165 y152 w80", "点 2 后等(ms):")
edtWait2 := MyGui.Add("Edit", "x250 y149 w60", CfgWaitAfterSecond)
MyGui.Add("Text", "x10 y182 w50", "右键 X:")
edtRightX := MyGui.Add("Edit", "x60 y179 w60", CfgRightX)
MyGui.Add("Text", "x130 y182 w15", "Y:")
edtRightY := MyGui.Add("Edit", "x145 y179 w60", CfgRightY)
MyGui.Add("Text", "x215 y182 w60", "间隔(ms):")
edtRightInterval := MyGui.Add("Edit", "x280 y179 w70", CfgRightInterval)
btnBoth := MyGui.Add("Button", "x10 y210 w150 h30", "两种点击同时操作")
btnBoth.OnEvent("Click", ToggleBoth)
btnRightOnly := MyGui.Add("Button", "x165 y210 w100 h30", "抽奖")
btnRightOnly.OnEvent("Click", ToggleRightOnly)
btnSynth := MyGui.Add("Button", "x270 y210 w100 h30", "合成")
btnSynth.OnEvent("Click", ToggleSynth)
txtClickStatus := MyGui.Add("Text", "x10 y245 w360", "状态：未运行")
MyGui.Add("Text", "x10 y265 w360 h2 +0x1000")

; ---- 3. 快捷切换桌面 ----
MyGui.Add("Text", "x10 y275 w360", "3. 快捷切换桌面")
btnQuickStart := MyGui.Add("Button", "x10 y300 w175 h30", "开始：快捷切换")
btnQuickStart.OnEvent("Click", StartQuickSwitch)
btnQuickStop := MyGui.Add("Button", "x195 y300 w175 h30", "停止")
btnQuickStop.OnEvent("Click", StopQuickSwitch)
btnQuickStop.Enabled := false
txtQuickStatus := MyGui.Add("Text", "x10 y335 w360", "状态：未录制")
MyGui.Add("Text", "x10 y355 w360 h2 +0x1000")

; ---- 底部 ----
btnStopAll := MyGui.Add("Button", "x10 y365 w115 h30", "全部停止")
btnStopAll.OnEvent("Click", StopAll)
btnSaveConfig := MyGui.Add("Button", "x132 y365 w115 h30", "保存配置")
btnSaveConfig.OnEvent("Click", SaveConfig)
btnExit := MyGui.Add("Button", "x254 y365 w115 h30", "退出")
btnExit.OnEvent("Click", (*) => ExitApp())
MyGui.OnEvent("Close", (*) => ExitApp())

; DLL 没加载成功时，禁用功能 1 和快捷切换，不影响功能 2
if (DesktopCount < 1) {
    btnDesktop.Enabled := false
    btnQuickStart.Enabled := false
    txtDesktopStatus.Text := "状态：不可用（DLL 加载失败，请检查同目录的 VirtualDesktopAccessor.dll）"
}

MyGui.Show("w380 h405")

; ===== 功能 1：桌面轮询 =====
; F11 或点按钮启动：一直轮询，直到再按 F11 或 F9 停掉。
; 轮询时每轮按 G；放映机图标在，才按 X；放映机图标在、
; 并且状态图标是暗色，才点状态图标一下，尝试变亮色；未知图标不点。
; 三个功能互斥：同一时间只能跑一个。启动哪个功能，就先停掉另外两个；
; 以后加新功能也按这个规矩——启动时停掉其他所有功能。
StopDesktopPolling() {
    global DesktopRunning, CyclePhase, btnDesktop, txtDesktopStatus
    if (!DesktopRunning) {
        return
    }
    DesktopRunning := false
    CyclePhase := ""
    SetTimer(StepDesktop, 0)
    btnDesktop.Text := "开始：桌面轮询"
    txtDesktopStatus.Text := "状态：已停止"
}

ToggleDesktop(*) {
    global DesktopRunning, DesktopPhase, DesktopWaitMs, DesktopKey, SwitchClickX, SwitchClickY
    global btnDesktop, txtDesktopStatus
    global CfgDesktopWait, CfgDesktopKey, CfgSwitchX, CfgSwitchY
    global CyclePhase, CycleCount, DesktopNext, CurrentDesktop, DesktopCount
    global CalStatusX, CalStatusY, CalProjX, CalProjY
    if (DesktopRunning) {
        StopDesktopPolling()
        ToolTip()
        return
    }
    ; 启动轮询前先停掉另外两个功能（开箱子、快捷切换）。
    StopClickLoops()
    StopQuickSwitch()
    ; 轮询参数不用界面填了，用配置文件里的值（没保存过就用默认值：
    ; 间隔 1000 毫秒、按键 g、切换后点 (212,57)）。
    DesktopWaitMs := Integer(CfgDesktopWait)
    DesktopKey := CfgDesktopKey
    SwitchClickX := Integer(CfgSwitchX)
    SwitchClickY := Integer(CfgSwitchY)
    DesktopRunning := true
    CycleCount++
    ; 各桌面图标位置清零（0 表示还没找到，第一次全窗口找，找到就记下来）。
    CalStatusX := []
    CalStatusY := []
    CalProjX := []
    CalProjY := []
    Loop DesktopCount {
        CalStatusX.Push(0)
        CalStatusY.Push(0)
        CalProjX.Push(0)
        CalProjY.Push(0)
    }
    DesktopNext := 0
    CurrentDesktop := 0
    StartCyclePhase("main")
    btnDesktop.Text := "停止：桌面轮询"
    StepDesktop()
}

; 开始轮询：从桌面 1 重新开始。
StartCyclePhase(NewPhase) {
    global CyclePhase, DesktopPhase, DesktopNext, CurrentDesktop
    global txtDesktopStatus
    CyclePhase := NewPhase
    DesktopPhase := "switch"
    DesktopNext := 0
    CurrentDesktop := 0
    ToolTip()
    txtDesktopStatus.Text := "状态：轮询中（放映机图标在才按 X，暗色才点状态图标，未知不点）"
}

; 是不是手动暂停了（F8）：轮询和开箱子都用这个判断。
UserBusy() {
    global ManualPaused
    return ManualPaused
}

; 轮询的暂停检查（只认 F8 手动暂停）：暂停返回 true，恢复返回 false。
CheckPaused() {
    global ManualPaused
    return ManualPaused
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
FindPattern(Text, X1, Y1, X2, Y2, &CX, &CY, E1 := "", E0 := "") {
    global FindErr1, FindErr0
    if (E1 = "") {
        E1 := FindErr1
    }
    if (E0 = "") {
        E0 := FindErr0
    }
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
        if (FindText(&FX, &FY, X1, Y1, X2, Y2, E1, E0, Text).Length) {
            CX := FX
            CY := FY
            return true
        }
    } catch {
    }
    return false
}

; 在游戏窗口里面找一个图标：位置都是固定的，第一次全窗口找，
; 以后只在记录位置附近找（中心 ±60/±50），这样又快、屏幕别处
; 的误匹配也进不来；附近没找到，图标可能挪位置了（窗口移动、
; 弹窗挡住），再全窗口找一次重新定位；全窗口也找不到才是不在。
; 没记下位置时直接全窗口找。找到返回 true，OutX/OutY 是图标中心。
FindIcon(Pattern, RecX, RecY, &OutX, &OutY, E1 := "", E0 := "") {
    global GameWinX, GameWinY, GameWinW, GameWinH
    OutX := 0
    OutY := 0
    ; 全窗口的范围：激活的游戏窗口里面；窗口位置没记下来时全屏找。
    WX1 := (GameWinW > 0 && GameWinH > 0) ? GameWinX : 0
    WY1 := (GameWinW > 0 && GameWinH > 0) ? GameWinY : 0
    WX2 := (GameWinW > 0 && GameWinH > 0) ? GameWinX + GameWinW : A_ScreenWidth
    WY2 := (GameWinW > 0 && GameWinH > 0) ? GameWinY + GameWinH : A_ScreenHeight
    if (RecX != 0) {
        if (FindPattern(Pattern, RecX - 60, RecY - 50, RecX + 60, RecY + 50, &OutX, &OutY, E1, E0)) {
            return true
        }
        return FindPattern(Pattern, WX1, WY1, WX2, WY2, &OutX, &OutY, E1, E0)
    }
    return FindPattern(Pattern, WX1, WY1, WX2, WY2, &OutX, &OutY, E1, E0)
}

; 找放映机图标（Idx 是桌面序号，从 1 开始）。
FindProjector(Idx, &OutX, &OutY) {
    global ProjectorText, ProjectorTextOld, ProjErr1, ProjErr0, CalProjX, CalProjY
    RX := (Idx >= 1 && Idx <= CalProjX.Length) ? CalProjX[Idx] : 0
    RY := (Idx >= 1 && Idx <= CalProjY.Length) ? CalProjY[Idx] : 0
    Found := FindIcon(ProjectorText, RX, RY, &OutX, &OutY, ProjErr1, ProjErr0)
    if (Found) {
        CalProjX[Idx] := OutX
        CalProjY[Idx] := OutY
        LogFind("D" . Idx . " projector FOUND (" . OutX . "," . OutY . ")")
        return true
    }
    Found := FindIcon(ProjectorTextOld, RX, RY, &OutX, &OutY, ProjErr1, ProjErr0)
    if (Found) {
        CalProjX[Idx] := OutX
        CalProjY[Idx] := OutY
        LogFind("D" . Idx . " projector (old size) FOUND (" . OutX . "," . OutY . ")")
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

; 点状态图标：点一下，然后模拟人工操作，在图标内部小范围移动鼠标 0.5 秒，
; 再把鼠标移到左边的横向黄金分割点（屏幕宽度的 0.382 倍、高 200），免得
; 鼠标挡住图标、影响下次识别。
ClickStatusIcon(IconX, IconY) {
    global CurrentDesktop
    LogFind("D" (CurrentDesktop + 1) " CLICK status icon at (" IconX "," IconY ")")
    Click(IconX, IconY)
    Loop 5 {
        MouseMove(IconX + Random(-18, 18), IconY + Random(-14, 14), 0)
        Sleep(100)
    }
    MouseMove(Round(A_ScreenWidth * 0.382), 200, 5)
    ; 点完多等 0.5 秒再走：切桌面卡顿时，点下去的输入可能还没处理完，
    ; 马上切桌面会把这次点击带到新桌面上去，点到新桌面相同位置的按钮。
    Sleep(500)
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
    CalStatusX[Idx] := OutX
    CalStatusY[Idx] := OutY
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
    CalStatusX[Idx] := OutX
    CalStatusY[Idx] := OutY
    LogFind("D" . Idx . " icon dark FOUND (" . OutX . "," . OutY . ")")
    return true
}

; 找未知状态图标（判断未知用）：就是那张全黑、剑也是黑的、只有边框是亮的
; 交叉双剑图标（46x41，阈值 82，从你发的截图整个图标转的）。它和亮版、
; 暗版图案都认不到对方（交叉验证过），所以图案本身就够了，不用再验亮度。
; 找到返回 true，OutX/OutY 是图标中心。未知图标不点，只按 G 和 X。
FindUnknown(Idx, &OutX, &OutY) {
    global UnknownText, CalStatusX, CalStatusY
    RX := (Idx >= 1 && Idx <= CalStatusX.Length) ? CalStatusX[Idx] : 0
    RY := (Idx >= 1 && Idx <= CalStatusY.Length) ? CalStatusY[Idx] : 0
    Found := FindIcon(UnknownText, RX, RY, &OutX, &OutY)
    if (Found) {
        CalStatusX[Idx] := OutX
        CalStatusY[Idx] := OutY
        LogFind("D" . Idx . " icon unknown FOUND (" . OutX . "," . OutY . ")")
    }
    return Found
}

; 记下刚激活的游戏窗口的位置和大小，后面找图标只在这个窗口里面找。
SaveGameWinRect(hWnd) {
    global GameWinX, GameWinY, GameWinW, GameWinH
    try {
        WinGetPos(&X, &Y, &W, &H, "ahk_id " hWnd)
        GameWinX := X
        GameWinY := Y
        GameWinW := W
        GameWinH := H
    } catch {
    }
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
                SaveGameWinRect(hWnd)
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
    if (FindUnknown(Idx, &OutX, &OutY)) {
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
            SaveGameWinRect(WinID)
            LogFind("activated game window at (" IconX "," IconY ") hwnd=" WinID)
            return true
        }
    } catch {
    }
    return false
}



; 轮询主循环：一个定时器驱动的状态机，每步做完再约下一步。
; 每轮：切桌面 -> 停 0.5 秒 -> 激活游戏窗口（先按标题找，找不到再用图标位置）
; 激活成功就直接去检查（左上角那两下点击本来就是为了聚焦，激活成功就没意义了）；
; 激活失败才点 (212,57) -> 停 0.5 秒 -> 原地点一下 -> 等 1000 毫秒 -> 检查放映机图标和状态图标
; （放映机图标在、并且是非暗色，就只按 X、不按 G；其他情况
; 按 G，放映机图标在才在约 0.05 秒后按 X；放映机图标在、
; 状态图标是暗色，才点状态图标）。
; 切到指定桌面，并且等切换真正完成（当前桌面号变成目标桌面）再返回。
; 切桌面卡顿时，只等固定时间可能不够，后面的找图标会读到上一个桌面
; 的画面，坐标记错、点错地方。最多等 2 秒，超时也继续往下走。
GoToDesktopAndWait(DesktopNum) {
    global GoToDesktopNumberProc, GetCurrentDesktopNumberProc
    try {
        DllCall(GoToDesktopNumberProc, "Int", DesktopNum)
    } catch {
        return
    }
    if (!GetCurrentDesktopNumberProc) {
        return
    }
    Start := A_TickCount
    Loop {
        try {
            Cur := DllCall(GetCurrentDesktopNumberProc, "Int")
        } catch {
            break
        }
        if (Cur = DesktopNum) {
            break
        }
        if (A_TickCount - Start > 2000) {
            break
        }
        Sleep(100)
    }
}

StepDesktop() {
    global DesktopRunning, CyclePhase, DesktopPhase, DesktopNext, CurrentDesktop
    global DesktopCount, DesktopKey, KeyGapMs, GoToDesktopNumberProc, DesktopWaitMs, SwitchClickX, SwitchClickY
    global GameWinX, GameWinY, GameWinW, GameWinH
    global txtDesktopStatus
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
    if (DesktopPhase = "switch") {
        CurrentDesktop := DesktopNext
        GoToDesktopAndWait(CurrentDesktop)
        DesktopNext := Mod(DesktopNext + 1, DesktopCount)
        DesktopPhase := "activate"
        SetTimer(StepDesktop, 500)   ; 切换后先停 0.5 秒
    } else if (DesktopPhase = "activate") {
        ; 切完桌面先激活游戏窗口，这样后面的按 G/X 才进游戏，
        ; 不用再手动点窗口。先按标题找（每个桌面只有一个游戏窗口，
        ; 用 DLL 挑出当前桌面上的那一个），找不到再用图标位置找。
        ; 激活成功的话，左上角 (212,57) 那两下点击就没意义了（本来
        ; 就是为了聚焦窗口），直接去检查；激活失败才照旧用点击来聚焦。
        ; 先把上个桌面的窗口位置清掉：激活失败时找图标就全屏找，
        ; 不会拿着上个桌面的窗口位置去找这个桌面的图标。
        GameWinW := 0
        GameWinH := 0
        Activated := false
        if (ActivateGameByTitle()) {
            Activated := true
        } else {
            Idx := CurrentDesktop + 1
            IX := 0
            IY := 0
            if (FindGameIcon(Idx, &IX, &IY)) {
                if (ActivateGameWindow(IX, IY)) {
                    Activated := true
                }
            } else {
                LogFind("D" Idx " activate: no window found by title or icon, skip activation")
            }
        }
        if (Activated) {
            DesktopPhase := "check"
            SetTimer(StepDesktop, DesktopWaitMs)
        } else {
            DesktopPhase := "click212"
            SetTimer(StepDesktop, 100)   ; 激活失败，稍停一下再点
        }
    } else if (DesktopPhase = "click212") {
        LogFind("D" (CurrentDesktop + 1) " CLICK focus (212,57) after activation failed")
        Click(SwitchClickX, SwitchClickY)
        DesktopPhase := "click"
        SetTimer(StepDesktop, 500)   ; 点完再停 0.5 秒
    } else if (DesktopPhase = "click") {
        MouseGetPos(&CX, &CY)
        LogFind("D" (CurrentDesktop + 1) " CLICK focus at current pos (" CX "," CY ") after activation failed")
        Click()
        DesktopPhase := "check"
        SetTimer(StepDesktop, DesktopWaitMs)
    } else if (DesktopPhase = "check") {
        MainCheckStep()
    } else if (DesktopPhase = "pressX") {
        PressXStep()
    }
}

; 轮询检查：每轮到一个桌面就先找放映机图标和状态图标，
; 再按下面规则做。三种状态：暗色（暗版图案找到）、未知
; （未知图案找到）、非暗色（亮版图案找到）；都没找到就是
; 状态没找到（not found）。
;   1. 放映机图标在、并且是非暗色：只按 X，不按 G，不点。
;   2. 未知：按 G；放映机图标在，才在约 0.05 秒后按 X；不点图标。
;   3. 暗色：按 G；放映机图标在，才在约 0.05 秒后按 X；
;      放映机图标在，才点状态图标一下，尝试帮它变亮色；
;      点完下轮再来检查，不单独验证。
;   4. 状态没找到：放映机图标在时，按 G、按 X，点一下记下的
;      状态图标位置（有记下位置才点）；放映机不在就只按 G。
MainCheckStep() {
    global CurrentDesktop, DesktopPhase, DesktopWaitMs, DesktopKey, DesktopKey2, KeyGapMs
    global CheckProjFound, CheckStatusNotFound
    global NonDarkSince, NonDarkClickMs, CyclePhase
    Idx := CurrentDesktop + 1
    PX := 0
    PY := 0
    ProjFound := FindProjector(Idx, &PX, &PY)
    CheckProjFound := ProjFound
    DX := 0
    DY := 0
    DarkFound := FindDark(Idx, &DX, &DY)
    UnknownFound := false
    BrightFound := false
    BX := 0
    BY := 0
    if (!DarkFound) {
        UX := 0
        UY := 0
        UnknownFound := FindUnknown(Idx, &UX, &UY)
        if (!UnknownFound) {
            ; 非暗色也不是未知：找一下亮版图案，确认是亮色。
            BrightFound := FindBright(Idx, &BX, &BY)
        }
    }
    CheckStatusNotFound := (!DarkFound && !UnknownFound && !BrightFound)
    ; 连续非暗色计时：亮色确认了就开始计时，暗色/未知/没找到就清零。
    ; 连续非暗色超过 20 分钟，就点一下本次找到的亮色图标位置（怕是误判，
    ; 实际是暗色却认成了亮色）；点完重新计时。
    ; 注意：NonDarkSince 一开始是空的，直接按下标写会下标越界报错，
    ; 所以先把它补到够长。
    while (NonDarkSince.Length < Idx) {
        NonDarkSince.Push(0)
    }
    if (BrightFound) {
        Since := (Idx <= NonDarkSince.Length) ? NonDarkSince[Idx] : 0
        if (Since = 0) {
            NonDarkSince[Idx] := A_TickCount
        } else if (CyclePhase = "main" && A_TickCount - Since >= NonDarkClickMs) {
            ClickStatusIcon(BX, BY)
            LogFind("D" Idx " non-dark for 20+ min, clicked status icon to check (possible misjudge)")
            ToolTip("Desktop " Idx ": non-dark 20+ min, clicked icon to check")
            NonDarkSince[Idx] := 0
        }
    } else {
        NonDarkSince[Idx] := 0
    }
    ; 暗色 + 放映机在：发现就马上点（按 G 之前点，点的是这次刚找到的位置；
    ; 按 G 可能过图，等 0.05 秒后再点位置就变了）。
    if (ProjFound && DarkFound) {
        ClickStatusIcon(DX, DY)
        LogFind("D" Idx " dark found, clicked immediately")
        ToolTip("Desktop " Idx ": projector yes, dark, clicked immediately")
    }
    if (ProjFound && !DarkFound && !UnknownFound && !CheckStatusNotFound) {
        ; 放映机图标在、并且是非暗色（亮色）：只按 X，不按 G，不点。
        Send(DesktopKey2)
        ToolTip("Desktop " Idx ": projector yes, non-dark, X only, no G, no click")
        DesktopPhase := "switch"
        SetTimer(StepDesktop, DesktopWaitMs)
        return
    }
    ; 暗色、未知、状态没找到：按 G，约 0.05 秒后到 pressX 步（放映机图标在才按 X）。
    Send(DesktopKey)
    DesktopPhase := "pressX"
    SetTimer(StepDesktop, KeyGapMs)
}

; 按 X（轮询检查的下一步，约 0.05 秒后）。
; 放映机图标在才按 X。暗色已经在检查步发现就马上点过了，
; 这里不再点；未知和状态没找到都不点。
PressXStep() {
    global CurrentDesktop, DesktopPhase, DesktopWaitMs, DesktopKey2, CheckProjFound
    Idx := CurrentDesktop + 1
    if (!CheckProjFound) {
        ; 放映机图标不在：不按 X（只按了 G）。
        ToolTip("Desktop " Idx ": projector no, no X")
        DesktopPhase := "switch"
        SetTimer(StepDesktop, DesktopWaitMs)
        return
    }
    Send(DesktopKey2)   ; 放映机图标在，才按 X
    ToolTip("Desktop " Idx ": projector yes, X pressed")
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
    StopDesktopPolling()
    StopQuickSwitch()
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
    StopDesktopPolling()
    StopQuickSwitch()
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
    StopDesktopPolling()
    StopQuickSwitch()
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
    StopDesktopPolling()
    StopClickLoops()
    StopQuickSwitch()
    ToolTip()
}

; ===== 保存配置 =====
; 保存的是开箱子界面里当前填的值（不是正在运行的那份旧值），
; 存到脚本同目录的 fenix_Config.ini，下次打开自动恢复。
; 桌面轮询的参数不用界面填了（用配置文件里的值，没保存过
; 就用默认值），所以保存配置不再写桌面轮询那几项。
; 正在运行时点保存也不会停掉正在跑的功能。
SaveConfig(*) {
    global ConfigFile
    global edtP1X, edtP1Y, edtP2X, edtP2Y, edtWait1, edtWait2, edtRightX, edtRightY, edtRightInterval
    for ctrl in [edtP1X, edtP1Y, edtP2X, edtP2Y, edtWait1, edtWait2, edtRightX, edtRightY, edtRightInterval] {
        if (!IsNumber(ctrl.Value)) {
            MsgBox("有坐标或间隔不是数字，配置没有保存，请先改成数字再点保存配置。")
            return
        }
    }
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

; F8 = 手动暂停 / 继续（轮询和开箱子都停，再按一次继续）。
ToggleManualPause(*) {
    global ManualPaused
    ManualPaused := !ManualPaused
    UpdatePauseButton()
    if (ManualPaused) {
        ToolTip("Paused manually (F8), press F8 again to resume")
    } else {
        ToolTip()
    }
}

; 按暂停状态更新轮询区的暂停按钮文字：暂停时显示“继续”，没暂停显示“暂停”。
UpdatePauseButton() {
    global ManualPaused, btnDesktopPause
    try {
        btnDesktopPause.Text := ManualPaused ? "继续" : "暂停"
    } catch {
    }
}

; 把其他桌面上的游戏窗口位置和大小调成和当前桌面一样。
; 这样录的鼠标坐标换桌面也能用。找不到当前桌面的游戏窗口
; 就什么都不做。窗口可能不在，找不到就跳过，不报错。
AlignGameWindows() {
    global GameTitle, GetWindowDesktopNumberProc, GetCurrentDesktopNumberProc
    LogFind("align: started")
    if (!GetWindowDesktopNumberProc || !GetCurrentDesktopNumberProc) {
        LogFind("align: DLL proc missing, skip")
        return
    }
    try {
        CurrentDesk := DllCall(GetCurrentDesktopNumberProc, "Int")
        WinList := WinGetList(GameTitle)
    } catch as Err {
        LogFind("align: exception getting desktop/window list: " Err.Message)
        return
    }
    LogFind("align: current desktop=" CurrentDesk ", windows found=" WinList.Length)
    if (WinList.Length = 0) {
        LogFind("align: no game window found")
        return
    }
    RefX := 0
    RefY := 0
    RefW := 0
    RefH := 0
    Found := false
    for hWnd in WinList {
        try {
            Desk := DllCall(GetWindowDesktopNumberProc, "Ptr", hWnd, "Int")
        } catch as Err {
            LogFind("align: GetWindowDesktopNumber failed for hwnd=" hWnd ": " Err.Message)
            continue
        }
        LogFind("align: hwnd=" hWnd " is on desktop " Desk)
        if (Desk = CurrentDesk) {
            try {
                WinGetPos(&RefX, &RefY, &RefW, &RefH, "ahk_id " hWnd)
                Found := true
                LogFind("align: reference window hwnd=" hWnd " at (" RefX "," RefY " " RefW "x" RefH ")")
            } catch as Err {
                LogFind("align: WinGetPos failed for hwnd=" hWnd ": " Err.Message)
            }
            break
        }
    }
    if (!Found) {
        LogFind("align: no game window on current desktop")
        return
    }
    for hWnd in WinList {
        try {
            Desk := DllCall(GetWindowDesktopNumberProc, "Ptr", hWnd, "Int")
        } catch as Err {
            LogFind("align: GetWindowDesktopNumber failed for hwnd=" hWnd ": " Err.Message)
            continue
        }
        if (Desk != CurrentDesk) {
            try {
                WinMove(RefX, RefY, RefW, RefH, "ahk_id " hWnd)
                LogFind("align: moved hwnd=" hWnd " (desktop " Desk ") to (" RefX "," RefY " " RefW "x" RefH ")")
            } catch as Err {
                LogFind("align: WinMove failed for hwnd=" hWnd ": " Err.Message)
            }
        } else {
            LogFind("align: hwnd=" hWnd " already on current desktop, skip")
        }
    }
    LogFind("align: done")
}

; ===== 快捷切换桌面 =====
; 点按钮或按键盘 F1/F2/F3 切到对应桌面。
; 桌面号从 0 开始（桌面 1 = 0）。DLL 没加载成功时切不了。
GoToDesktop(DesktopNum) {
    global GoToDesktopNumberProc, DesktopCount
    if (!GoToDesktopNumberProc || DesktopNum < 0 || DesktopNum >= DesktopCount) {
        return
    }
    try {
        DllCall(GoToDesktopNumberProc, "Int", DesktopNum)
    } catch {
    }
}

; 快捷切换的开始/停止：开始打开键盘 F1/F2/F3 切桌面，停止就关掉。
; 开始后「开始」变灰、「停止」可用；停止后反过来。
StartQuickSwitch(*) {
    global QuickSwitchEnabled, btnQuickStart, btnQuickStop
    ; 启动快捷切换前先停掉另外两个功能（轮询、开箱子）。
    StopDesktopPolling()
    StopClickLoops()
    QuickSwitchEnabled := true
    btnQuickStart.Enabled := false
    btnQuickStop.Enabled := true
    ShowTempToolTip("快捷切换已开启")
    ; 2 秒后把其他两个桌面上的游戏窗口位置调成和当前桌面一样，
    ; 这样录的鼠标坐标换桌面也能用。
    LogFind("quickswitch: started, align timer set (2s)")
    SetTimer(AlignGameWindows, -2000)
}

; SC029 = ` 键（飘号键，左上角 1 左边那个）：快捷切换的启动 / 停止开关（全局热键，不受开关状态限制）。
; （AHK v2 里反引号是转义字符，不能直接写 ``:: 做热键，要用扫描码 SC029。）
ToggleQuickSwitch(*) {
    global QuickSwitchEnabled
    if (QuickSwitchEnabled) {
        StopQuickSwitch()
    } else {
        StartQuickSwitch()
    }
}

StopQuickSwitch(*) {
    global QuickSwitchEnabled, btnQuickStart, btnQuickStop
    global Recording, PlayingBack, txtQuickStatus
    WasOn := QuickSwitchEnabled
    SetTimer(AlignGameWindows, 0)
    SetTimer(RecordPoll, 0)
    Recording := false
    PlayingBack := false
    QuickSwitchEnabled := false
    btnQuickStart.Enabled := true
    btnQuickStop.Enabled := false
    txtQuickStatus.Text := "状态：未录制"
    if (WasOn) {
        ShowTempToolTip("快捷切换已停止")
    }
}

; 显示一个提示，3 秒后自动消失（不然提示字会一直留在屏幕上）。
ShowTempToolTip(Text) {
    ToolTip(Text)
    SetTimer(ClearToolTip, -3000)
}

ClearToolTip() {
    ToolTip()
}

; ===== 录鼠标 / 回放（快捷切换开着的时候才能用）=====
; 只录鼠标，不录键盘。录的是每次点下/松开左键/右键的位置和间隔。
; 回放按 F4，执行一遍；回放中按 F5 或 F9 可以停掉。
RecordPoll() {
    global Recording, RecordEvents, RecordLastTick, RecordLastL, RecordLastR, txtQuickStatus
    if (!Recording) {
        return
    }
    MouseGetPos(&MX, &MY)
    LDown := GetKeyState("LButton", "P")
    RDown := GetKeyState("RButton", "P")
    Now := A_TickCount
    if (LDown && !RecordLastL) {
        RecordEvents.Push(["LDown", MX, MY, Now - RecordLastTick])
        RecordLastTick := Now
        txtQuickStatus.Text := "状态：正在记录…已录 " RecordEvents.Length " 个动作"
    } else if (!LDown && RecordLastL) {
        RecordEvents.Push(["LUp", MX, MY, Now - RecordLastTick])
        RecordLastTick := Now
        txtQuickStatus.Text := "状态：正在记录…已录 " RecordEvents.Length " 个动作"
    }
    if (RDown && !RecordLastR) {
        RecordEvents.Push(["RDown", MX, MY, Now - RecordLastTick])
        RecordLastTick := Now
        txtQuickStatus.Text := "状态：正在记录…已录 " RecordEvents.Length " 个动作"
    } else if (!RDown && RecordLastR) {
        RecordEvents.Push(["RUp", MX, MY, Now - RecordLastTick])
        RecordLastTick := Now
        txtQuickStatus.Text := "状态：正在记录…已录 " RecordEvents.Length " 个动作"
    }
    RecordLastL := LDown
    RecordLastR := RDown
}

; 5 键：回放中按一下停回放；不回放时按一下开始/停止录制。
ToggleRecord(*) {
    global Recording, RecordEvents, RecordLastTick, RecordLastL, RecordLastR, PlayingBack, txtQuickStatus
    if (PlayingBack) {
        PlayingBack := false
        ShowTempToolTip("回放已停止")
        return
    }
    if (Recording) {
        Recording := false
        SetTimer(RecordPoll, 0)
        txtQuickStatus.Text := "状态：已录制 " RecordEvents.Length " 个动作，按 F4 回放"
        ShowTempToolTip("已录制 " RecordEvents.Length " 个动作，按 F4 回放")
    } else {
        RecordEvents := []
        RecordLastTick := A_TickCount
        RecordLastL := GetKeyState("LButton", "P")
        RecordLastR := GetKeyState("RButton", "P")
        Recording := true
        SetTimer(RecordPoll, 10)
        txtQuickStatus.Text := "状态：正在记录鼠标…再按 F5 停止"
        ToolTip("正在记录鼠标…再按 F5 停止")
    }
}

; 4 键：把录下来的鼠标动作执行一遍。间隔按录的时候一样（最长 30 秒）。
PlayRecording(*) {
    global Recording, RecordEvents, PlayingBack, txtQuickStatus
    if (Recording || PlayingBack) {
        return
    }
    if (RecordEvents.Length = 0) {
        ShowTempToolTip("没有录制内容，先按 F5 录一段")
        return
    }
    PlayingBack := true
    txtQuickStatus.Text := "状态：正在回放…按 F5 停止"
    ToolTip("正在回放…按 F5 停止")
    for Ev in RecordEvents {
        if (!PlayingBack) {
            break
        }
        Sleep(Min(Ev[4], 30000))
        if (!PlayingBack) {
            break
        }
        if (Ev[1] = "LDown") {
            MouseMove(Ev[2], Ev[3], 0)
            Click("Down")
        } else if (Ev[1] = "LUp") {
            MouseMove(Ev[2], Ev[3], 0)
            Click("Up")
        } else if (Ev[1] = "RDown") {
            MouseMove(Ev[2], Ev[3], 0)
            Click("Right Down")
        } else if (Ev[1] = "RUp") {
            MouseMove(Ev[2], Ev[3], 0)
            Click("Right Up")
        }
    }
    PlayingBack := false
    txtQuickStatus.Text := "状态：已录制 " RecordEvents.Length " 个动作，按 4 回放"
    ShowTempToolTip("回放完成")
}

; ===== 快捷键 =====
; F8  = 手动暂停 / 继续
; F11 = 桌面轮询 开启 / 停止（再启动从桌面 1 重新开始）
; F12 = 开箱子 开启 / 暂停
; F9  = 统一暂停（全部停止，不退出程序，窗口还在，可再启动）
F8::ToggleManualPause()
F11::ToggleDesktop()
F12::ToggleClickHotkey()
F9::StopAll()
SC029::ToggleQuickSwitch()

; 快捷切换桌面的键盘：只在开关打开时生效（默认关），
; 关了 F1/F2/F3 就是正常的功能键，不会切桌面。
#HotIf QuickSwitchEnabled
F1::GoToDesktop(0)
F2::GoToDesktop(1)
F3::GoToDesktop(2)
F4::PlayRecording()
F5::ToggleRecord()
#HotIf

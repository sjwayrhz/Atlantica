#Requires AutoHotkey v2.0
#SingleInstance Force
#Include FindText.ahk

; 必须开：不然 WinGetList 只找得到当前桌面上的窗口，
; 其他桌面上的游戏窗口会被当成隐藏窗口漏掉，
; 对齐（AlignGameWindows）就永远只找到 1 个、没东西可挪。
; 轮询不受影响，因为它每次只要当前桌面那一个窗口。
DetectHiddenWindows(true)

; ============================================================
; fenix 功能菜单（图形界面版，AHK v2）
; 原来的两个脚本已经合并到这一个窗口里，
; 不会出现两个脚本互相冲突。
;
; 功能：
;   1. 桌面轮询（F11）：按 F11 或点按钮启动后，三个桌面一直
;      轮询切换，停掉之前不会自己停。
;      切到每个桌面后，先激活游戏窗口（窗口是窗口模式跑的，
;      不激活的话按 F/X 进不去游戏；以前要手动点一下窗口，
;      现在脚本自己激活，不用手动点了）。先按窗口标题找：
;      标题是 "Atlantica Online Fenix"，三个桌面标题都一样，
;      但每个桌面只有一个游戏窗口，用 DLL 的
;      IsWindowOnCurrentVirtualDesktop 挑出当前桌面上的那一个
;      激活它，不会切到别的桌面去。标题找不到时再用图标位置
;      找（图标在当前桌面上，图标位置的窗口就是当前这个桌面的
;      游戏窗口）。
;      轮询时先看放映机图标和状态图标：放映机图标在、并且是
;      非暗色，就只按 X、不按 F；其他情况按 F，放映机图标在才
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
;        不按 F；未知图标按 F、按 X、不点图标；放映机图标在、并且
;        状态图标是暗色，才按 F、按 X、点状态图标一下，尝试帮它
;        变亮色。放映机图标不在，就只按 F，不按 X、不点。一直重复。
;      暂停：点“暂停”按钮手动暂停（轮询和开箱子都停），再点
;      一次继续。F11 是停止（再启动从桌面 1 重新开始）。
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
;   3. 跟随队长（F10，在“快捷切换桌面”区里）：
;      点“开启跟随队长 (F10)”或按 F10 启动，跑一遍四步、点完 X 点
;      自动停；中途再按一次可以停掉。和快捷切换不冲突，可以叠加使用。
;      都是左键点击，每步间隔 0.5 秒：P 点 -> 队长名称 -> 跟随队员 -> X 点。
;      四个点用按钮取点（窗口会最小化，在屏幕上点一下就行）。
;
; 使用：双击运行本脚本，点按钮或按快捷键即可。
;       F11 开关桌面轮询，F12 开关开箱子，F10 开关跟随队长。
;       桌面轮询只有开始和暂停两个按钮，参数
;       直接写死在代码里。开箱子的坐标用按钮取点（窗口会最小化，
;       在屏幕上点一下就行），点“保存配置”会存到同目录的
;       fenix_Config.ini，下次打开自动恢复。
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
DesktopKey := "f"
DesktopKey2 := "x"      ; 每次按 F 后再按的第二个键
KeyGapMs := 50          ; 按 F 和按 X 之间相隔的毫秒数（约 0.05 秒）
SwitchClickX := 212     ; 每次切换后要点的固定位置
SwitchClickY := 57
GameTitle := "Atlantica Online Fenix"  ; 游戏窗口标题（截图里看到的；三个桌面都一样，但每个桌面只有一个，用 DLL 挑当前桌面上的那一个）

; ===== 轮询循环（功能 1）的阶段和计时 =====
; 没有检测阶段了：每次到一个桌面，先激活游戏窗口，再找图标
; （放映机图标和状态图标），找到就按规则处理。位置都是固定
; 的：第一次全窗口找并记下位置，以后只在记录位置附近找。
; DesktopPhase 是每一步的小阶段：switch 切桌面、activate 激活游戏窗口
; （先按标题找，找不到再用图标位置）、click212 点切换后坐标、click 原地点击、
; check 检查放映机图标和状态图标（决定按 F 还是只按 X、点不点
; 状态图标）、pressX 按 X 和点图标。
CyclePhase := "main"
CycleCount := 0
CurrentDesktop := 0
ManualPaused := false   ; 手动暂停的开关
QuickSwitchEnabled := false ; 快捷切换桌面（键盘 F1/F2/F3）的开关，默认关
Recording := false        ; 是不是正在录鼠标
RecordEvents := []        ; 录下来的鼠标动作，每条是 [类型, X, Y, 间隔毫秒]
RecordLastTick := 0       ; 上一个录下来的动作是什么时候（A_TickCount）
RecordLastL := false      ; 上次轮询时左键是不是按着
RecordLastR := false      ; 上次轮询时右键是不是按着
PlayingBack := false      ; 是不是正在回放
; 录键盘时要轮询的按键（脚本自己的热键 F1-F5、F8、F9、F10、F11、F12、飘号键不录，
; 免得录进去又触发脚本功能）。字母、数字、空格、回车、Tab、Esc、退格、
; 左右 Shift/Ctrl/Alt、方向键、F6/F7、小键盘。
KeysToRecord := ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","1","2","3","4","5","6","7","8","9","0","Space","Enter","Tab","Escape","Backspace","LShift","RShift","LCtrl","RCtrl","LAlt","RAlt","Up","Down","Left","Right","F6","F7","Numpad0","Numpad1","Numpad2","Numpad3","Numpad4","Numpad5","Numpad6","Numpad7","Numpad8","Numpad9","NumpadDot","NumpadAdd","NumpadSub","NumpadMult","NumpadDiv","NumpadEnter"]
KeyPrevState := Map()       ; 每个按键上次轮询时是不是按着（录键盘用）
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
WaitAfterFirst := 1000    ; 点 1 后等，固定值
WaitAfterSecond := 2000   ; 点 2 后等，固定值

RightRunning := false
RightClickInterval := 3500 ; 右键间隔，固定值

; ===== 参数 =====
; 轮询的参数和开箱子的三个等待时间直接写死在代码里，不用 ini 文件。
; 开箱子的三个坐标和跟随队长的四个点存在脚本同目录的 fenix_Config.ini 里，
; 点“保存配置”会更新它，下次打开自动恢复。
ConfigFile := A_ScriptDir "\fenix_Config.ini"
CfgDesktopWait := "1000"
CfgDesktopKey := "f"
CfgSwitchX := "212"
CfgSwitchY := "57"
CfgPoint1X := IniRead(ConfigFile, "Click", "Point1X", "700")
CfgPoint1Y := IniRead(ConfigFile, "Click", "Point1Y", "450")
CfgPoint2X := IniRead(ConfigFile, "Click", "Point2X", "822")
CfgPoint2Y := IniRead(ConfigFile, "Click", "Point2Y", "450")
CfgRightX := IniRead(ConfigFile, "Click", "RightX", "980")
CfgRightY := IniRead(ConfigFile, "Click", "RightY", "593")
CfgFollowPX := IniRead(ConfigFile, "Follow", "PX", "0")
CfgFollowPY := IniRead(ConfigFile, "Follow", "PY", "0")
CfgFollowLeaderX := IniRead(ConfigFile, "Follow", "LeaderX", "0")
CfgFollowLeaderY := IniRead(ConfigFile, "Follow", "LeaderY", "0")
CfgFollowMemberX := IniRead(ConfigFile, "Follow", "MemberX", "0")
CfgFollowMemberY := IniRead(ConfigFile, "Follow", "MemberY", "0")
CfgFollowXX := IniRead(ConfigFile, "Follow", "XX", "0")
CfgFollowXY := IniRead(ConfigFile, "Follow", "XY", "0")

; 开箱子运行时用的坐标，先按配置文件里的值来；
; 点“取点”按钮改了之后就用新取到的值。
Point1X := Integer(CfgPoint1X)
Point1Y := Integer(CfgPoint1Y)
Point2X := Integer(CfgPoint2X)
Point2Y := Integer(CfgPoint2Y)
RightX := Integer(CfgRightX)
RightY := Integer(CfgRightY)

; 跟随队长用的四个点，先按配置文件里的值来；
; 点取点按钮改了之后就用新取到的值。
FollowPX := Integer(CfgFollowPX)
FollowPY := Integer(CfgFollowPY)
FollowLeaderX := Integer(CfgFollowLeaderX)
FollowLeaderY := Integer(CfgFollowLeaderY)
FollowMemberX := Integer(CfgFollowMemberX)
FollowMemberY := Integer(CfgFollowMemberY)
FollowXX := Integer(CfgFollowXX)
FollowXY := Integer(CfgFollowXY)
FollowRunning := false
FollowStep := 0

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
; 坐标不用手输数字：点下面三个按钮取点，窗口会最小化，
; 在屏幕上点一下要记录的位置，按 Esc 取消。
MyGui.Add("Text", "x10 y100 w360", "2. 开箱子 (F12)")
btnCapRight := MyGui.Add("Button", "x10 y122 w115 h30", "箱子位置")
btnCapRight.OnEvent("Click", (*) => CapturePos(3))
btnCapP1 := MyGui.Add("Button", "x132 y122 w115 h30", "自动放入")
btnCapP1.OnEvent("Click", (*) => CapturePos(1))
btnCapP2 := MyGui.Add("Button", "x254 y122 w115 h30", "开始精炼")
btnCapP2.OnEvent("Click", (*) => CapturePos(2))
txtClickPos := MyGui.Add("Text", "x10 y158 w360 h28", "")
btnBoth := MyGui.Add("Button", "x10 y192 w150 h30", "两种点击同时操作")
btnBoth.OnEvent("Click", ToggleBoth)
btnRightOnly := MyGui.Add("Button", "x165 y192 w100 h30", "抽奖")
btnRightOnly.OnEvent("Click", ToggleRightOnly)
btnSynth := MyGui.Add("Button", "x270 y192 w100 h30", "合成")
btnSynth.OnEvent("Click", ToggleSynth)
txtClickStatus := MyGui.Add("Text", "x10 y227 w360", "状态：未运行")
MyGui.Add("Text", "x10 y247 w360 h2 +0x1000")

; ---- 3. 快捷切换桌面 ----
MyGui.Add("Text", "x10 y257 w360", "3. 快捷切换桌面 (~)")
btnQuickStart := MyGui.Add("Button", "x10 y282 w175 h30", "开始：快捷切换")
btnQuickStart.OnEvent("Click", StartQuickSwitch)
btnQuickStop := MyGui.Add("Button", "x195 y282 w175 h30", "停止")
btnQuickStop.OnEvent("Click", StopQuickSwitch)
btnQuickStop.Enabled := false
; ---- 3.1 跟随队长（和快捷切换不冲突，可以叠加使用；F10 开启 / 停止）----
; 分组框把“开启跟随队长”按钮和下面四个取点按钮框在一起（AHK 自带的
; 分组框是细实线边框，不是虚线；框住五个按钮、看起来是一个模块就行）。
grpFollow := MyGui.Add("GroupBox", "x8 y315 w364 h85", "")
btnFollow := MyGui.Add("Button", "x10 y322 w360 h30", "开启跟随队长 (F10)")
btnFollow.OnEvent("Click", ToggleFollow)
btnCapFollowP := MyGui.Add("Button", "x10 y362 w87 h30", "P点")
btnCapFollowP.OnEvent("Click", (*) => CapturePos(4))
btnCapFollowLeader := MyGui.Add("Button", "x101 y362 w87 h30", "队长名称")
btnCapFollowLeader.OnEvent("Click", (*) => CapturePos(5))
btnCapFollowMember := MyGui.Add("Button", "x192 y362 w87 h30", "跟随队员")
btnCapFollowMember.OnEvent("Click", (*) => CapturePos(6))
btnCapFollowX := MyGui.Add("Button", "x283 y362 w87 h30", "X点")
btnCapFollowX.OnEvent("Click", (*) => CapturePos(7))
txtFollowPos := MyGui.Add("Text", "x10 y407 w360 h28", "")
txtFollowStatus := MyGui.Add("Text", "x10 y437 w360", "状态：未运行")
txtQuickStatus := MyGui.Add("Text", "x10 y462 w360", "状态：未录制")
MyGui.Add("Text", "x10 y487 w360 h2 +0x1000")

; ---- 底部 ----
btnStopAll := MyGui.Add("Button", "x10 y497 w115 h30", "全部停止")
btnStopAll.OnEvent("Click", StopAll)
btnSaveConfig := MyGui.Add("Button", "x132 y497 w115 h30", "保存配置")
btnSaveConfig.OnEvent("Click", SaveConfig)
btnExit := MyGui.Add("Button", "x254 y497 w115 h30", "退出")
btnExit.OnEvent("Click", (*) => ExitApp())
MyGui.OnEvent("Close", (*) => ExitApp())

; 最小化时藏到托盘：任务栏不显示，只剩右下角托盘图标。
; 点一下托盘图标（或右键菜单「显示窗口」）就恢复窗口。
MyGui.OnEvent("Size", GuiOnSize)
GuiOnSize(GuiObj, MinMax, Width, Height) {
    if (MinMax = -1) {
        GuiObj.Hide()
    }
}
A_TrayMenu.Add("显示窗口", (*) => MyGui.Show())
A_TrayMenu.Default := "显示窗口"
OnMessage(0x404, TrayIconClick)
TrayIconClick(wParam, lParam, Msg, Hwnd) {
    ; 0x202 = 左键松开（单击托盘图标）
    if (lParam = 0x202) {
        MyGui.Show()
    }
}

; DLL 没加载成功时，禁用功能 1 和快捷切换，不影响功能 2
if (DesktopCount < 1) {
    btnDesktop.Enabled := false
    btnQuickStart.Enabled := false
    txtDesktopStatus.Text := "状态：不可用（DLL 加载失败，请检查同目录的 VirtualDesktopAccessor.dll）"
}

UpdateClickPosText()
UpdateFollowPosText()

MyGui.Show("w380 h597")

; ===== 功能 1：桌面轮询 =====
; F11 或点按钮启动：一直轮询，直到再按 F11 或再点按钮停掉。
; 轮询时每轮按 F；放映机图标在，才按 X；放映机图标在、
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
    ; 轮询参数不用界面填，直接用代码里写死的值（间隔 1000 毫秒、
    ; 按键 f、切换后点 (212,57)）。
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

; 是不是手动暂停了：轮询和开箱子都用这个判断。
UserBusy() {
    global ManualPaused
    return ManualPaused
}

; 轮询的暂停检查（只认手动暂停）：暂停返回 true，恢复返回 false。
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
; 找到返回 true，OutX/OutY 是图标中心。未知图标不点，只按 F 和 X。
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
; （放映机图标在、并且是非暗色，就只按 X、不按 F；其他情况
; 按 F，放映机图标在才在约 0.05 秒后按 X；放映机图标在、
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
    ; 暂停：点了手动暂停，就停在这里，什么都不做；
    ; 再点一次继续。
    if (CheckPaused()) {
        ToolTip("Paused manually, click Continue to resume")
        txtDesktopStatus.Text := "状态：已暂停（手动暂停，点「继续」恢复）"
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
        ; 切完桌面先激活游戏窗口，这样后面的按 F/X 才进游戏，
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
;   1. 放映机图标在、并且是非暗色：只按 X，不按 F，不点。
;   2. 未知：按 F；放映机图标在，才在约 0.05 秒后按 X；不点图标。
;   3. 暗色：按 F；放映机图标在，才在约 0.05 秒后按 X；
;      放映机图标在，才点状态图标一下，尝试帮它变亮色；
;      点完下轮再来检查，不单独验证。
;   4. 状态没找到：放映机图标在时，按 F、按 X，点一下记下的
;      状态图标位置（有记下位置才点）；放映机不在就只按 F。
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
    ; 暗色 + 放映机在：发现就马上点（按 F 之前点，点的是这次刚找到的位置；
    ; 按 F 可能过图，等 0.05 秒后再点位置就变了）。
    if (ProjFound && DarkFound) {
        ClickStatusIcon(DX, DY)
        LogFind("D" Idx " dark found, clicked immediately")
        ToolTip("Desktop " Idx ": projector yes, dark, clicked immediately")
    }
    if (ProjFound && !DarkFound && !UnknownFound && !CheckStatusNotFound) {
        ; 放映机图标在、并且是非暗色（亮色）：只按 X，不按 F，不点。
        Send(DesktopKey2)
        ToolTip("Desktop " Idx ": projector yes, non-dark, X only, no F, no click")
        DesktopPhase := "switch"
        SetTimer(StepDesktop, DesktopWaitMs)
        return
    }
    ; 暗色、未知、状态没找到：按 F，约 0.05 秒后到 pressX 步（放映机图标在才按 X）。
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
        ; 放映机图标不在：不按 X（只按了 F）。
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
; 取点：点取点按钮后窗口最小化，在屏幕上点一下要记录的位置，
; 按 Esc 取消。target: 1=自动放入(点 1)，2=开始精炼(点 2)，3=箱子位置(右键)，
; 4=跟随队长的 P 点，5=队长名称，6=跟随队员，7=X 点。
UpdateClickPosText() {
    global txtClickPos, Point1X, Point1Y, Point2X, Point2Y, RightX, RightY
    txtClickPos.Text := "箱子位置(" RightX ", " RightY ")  自动放入(" Point1X ", " Point1Y ")  开始精炼(" Point2X ", " Point2Y ")"
}

UpdateFollowPosText() {
    global txtFollowPos, FollowPX, FollowPY, FollowLeaderX, FollowLeaderY, FollowMemberX, FollowMemberY, FollowXX, FollowXY
    txtFollowPos.Text := "P点(" FollowPX ", " FollowPY ")  队长名称(" FollowLeaderX ", " FollowLeaderY ")  跟随队员(" FollowMemberX ", " FollowMemberY ")  X点(" FollowXX ", " FollowXY ")"
}

CapturePos(target) {
    global MyGui, Point1X, Point1Y, Point2X, Point2Y, RightX, RightY
    global FollowPX, FollowPY, FollowLeaderX, FollowLeaderY, FollowMemberX, FollowMemberY, FollowXX, FollowXY
    MyGui.Minimize()
    Sleep(300)
    KeyWait("LButton")
    ToolTip("点一下要记录的位置，按 Esc 取消")
    cancelled := false
    while (true) {
        if (GetKeyState("Escape", "P")) {
            cancelled := true
            break
        }
        if (GetKeyState("LButton", "P")) {
            break
        }
        Sleep(50)
    }
    ToolTip()
    if (!cancelled) {
        MouseGetPos(&mx, &my)
        if (target = 1) {
            Point1X := mx
            Point1Y := my
        } else if (target = 2) {
            Point2X := mx
            Point2Y := my
        } else if (target = 3) {
            RightX := mx
            RightY := my
        } else if (target = 4) {
            FollowPX := mx
            FollowPY := my
        } else if (target = 5) {
            FollowLeaderX := mx
            FollowLeaderY := my
        } else if (target = 6) {
            FollowMemberX := mx
            FollowMemberY := my
        } else {
            FollowXX := mx
            FollowXY := my
        }
        if (target <= 3) {
            UpdateClickPosText()
        } else {
            UpdateFollowPosText()
        }
        ShowTempToolTip("已记录 (" mx ", " my ")，点保存配置可存下来")
    }
    MyGui.Restore()
}

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
    if (ClickMode = "both") {
        StopClickLoops()
        ToolTip()
        return
    }
    StopClickLoops()
    StopDesktopPolling()
    StopQuickSwitch()
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
    if (ClickMode = "right") {
        StopClickLoops()
        ToolTip()
        return
    }
    StopClickLoops()
    StopDesktopPolling()
    StopQuickSwitch()
    RightRunning := true
    ClickMode := "right"
    UpdateClickButtons()
    StepRight()
    SetTimer(StepRight, RightClickInterval)
}

ToggleSynth(*) {
    global ClickMode, TwoRunning, TwoPhase, Point1X, Point1Y, Point2X, Point2Y, WaitAfterFirst, WaitAfterSecond
    if (ClickMode = "two") {
        StopClickLoops()
        ToolTip()
        return
    }
    StopClickLoops()
    StopDesktopPolling()
    StopQuickSwitch()
    TwoRunning := true
    TwoPhase := 0
    ClickMode := "two"
    UpdateClickButtons()
    StepTwo()
}

StepTwo() {
    global TwoPhase, Point1X, Point1Y, Point2X, Point2Y, WaitAfterFirst, WaitAfterSecond
    ; 手动暂停了，就不点，等点了继续后再点。
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
    ; 手动暂停了，就不点，下次定时到了再试。
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
    StopFollow()
    ToolTip()
}

; ===== 跟随队长（F10 / “开启跟随队长”按钮）=====
; 和快捷切换不冲突，可以叠加使用；启动后跑一遍下面四步，点完 X 点自动停，
; 中途再按 F10（或点按钮、或点“全部停止”）可以停掉。都是左键点击。
; 顺序：P 点 -> 队长名称 -> 跟随队员 -> X 点，每步间隔 0.5 秒。
StepFollow() {
    global FollowRunning, FollowStep
    global FollowPX, FollowPY, FollowLeaderX, FollowLeaderY, FollowMemberX, FollowMemberY, FollowXX, FollowXY
    if (!FollowRunning) {
        return
    }
    ; 手动暂停了就不点，等恢复后再继续。
    if (UserBusy()) {
        SetTimer(StepFollow, 500)
        return
    }
    if (FollowStep = 0) {
        Click(FollowPX, FollowPY)
    } else if (FollowStep = 1) {
        Click(FollowLeaderX, FollowLeaderY)
    } else if (FollowStep = 2) {
        Click(FollowMemberX, FollowMemberY)
    } else {
        Click(FollowXX, FollowXY)
        StopFollow()
        ShowTempToolTip("跟随队长已完成")
        return
    }
    FollowStep := FollowStep + 1
    SetTimer(StepFollow, 500)
}

UpdateFollowButtons() {
    global FollowRunning, btnFollow, txtFollowStatus
    if (FollowRunning) {
        btnFollow.Text := "停止跟随队长 (F10)"
        txtFollowStatus.Text := "状态：运行中（跟随队长）"
    } else {
        btnFollow.Text := "开启跟随队长 (F10)"
        txtFollowStatus.Text := "状态：未运行"
    }
}

ToggleFollow(*) {
    global FollowRunning, FollowStep
    global FollowPX, FollowPY, FollowLeaderX, FollowLeaderY, FollowMemberX, FollowMemberY, FollowXX, FollowXY
    if (FollowRunning) {
        StopFollow()
        return
    }
    ; 四个点都没取过（都是 0,0）就先不跑，免得点到屏幕左上角。
    if (FollowPX = 0 and FollowPY = 0 and FollowLeaderX = 0 and FollowLeaderY = 0 and FollowMemberX = 0 and FollowMemberY = 0 and FollowXX = 0 and FollowXY = 0) {
        MsgBox("四个点还没取，先点下面的 P点 / 队长名称 / 跟随队员 / X点 取点。")
        return
    }
    FollowRunning := true
    FollowStep := 0
    UpdateFollowButtons()
    SetTimer(StepFollow, -500)
}

StopFollow(*) {
    global FollowRunning
    FollowRunning := false
    SetTimer(StepFollow, 0)
    UpdateFollowButtons()
}

; ===== 保存配置 =====
; 把开箱子当前用的三个坐标和跟随队长的四个点存到脚本同目录的 fenix_Config.ini，
; 下次打开自动恢复。等待时间是写死在代码里的固定值，不用 ini，不写。
; 正在运行时点保存也不会停掉正在跑的功能。
SaveConfig(*) {
    global ConfigFile
    global Point1X, Point1Y, Point2X, Point2Y, RightX, RightY
    global FollowPX, FollowPY, FollowLeaderX, FollowLeaderY, FollowMemberX, FollowMemberY, FollowXX, FollowXY
    IniWrite(Point1X, ConfigFile, "Click", "Point1X")
    IniWrite(Point1Y, ConfigFile, "Click", "Point1Y")
    IniWrite(Point2X, ConfigFile, "Click", "Point2X")
    IniWrite(Point2Y, ConfigFile, "Click", "Point2Y")
    IniWrite(RightX, ConfigFile, "Click", "RightX")
    IniWrite(RightY, ConfigFile, "Click", "RightY")
    IniWrite(FollowPX, ConfigFile, "Follow", "PX")
    IniWrite(FollowPY, ConfigFile, "Follow", "PY")
    IniWrite(FollowLeaderX, ConfigFile, "Follow", "LeaderX")
    IniWrite(FollowLeaderY, ConfigFile, "Follow", "LeaderY")
    IniWrite(FollowMemberX, ConfigFile, "Follow", "MemberX")
    IniWrite(FollowMemberY, ConfigFile, "Follow", "MemberY")
    IniWrite(FollowXX, ConfigFile, "Follow", "XX")
    IniWrite(FollowXY, ConfigFile, "Follow", "XY")
    MsgBox("配置已保存到：`n" ConfigFile "`n下次打开脚本会自动恢复这些坐标。")
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

; 手动暂停 / 继续（轮询和开箱子都停，再点一次继续）。
ToggleManualPause(*) {
    global ManualPaused
    ManualPaused := !ManualPaused
    UpdatePauseButton()
    if (ManualPaused) {
        ToolTip("Paused manually, click Continue to resume")
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
; F1/F2/F3 切桌面：切过去后自动激活（点选）那个桌面上的游戏窗口，
; 不用再手动点一下。先等切换真正完成，再按标题找（每个桌面只有一个
; 游戏窗口，用 DLL 挑出当前桌面上的那一个），找不到再用图标位置找；
; 都找不到就点一下 (212,57) 来聚焦（和轮询的激活失败后一样）。
GoToDesktop(DesktopNum) {
    global GoToDesktopNumberProc, DesktopCount, GameWinW, GameWinH, SwitchClickX, SwitchClickY
    if (!GoToDesktopNumberProc || DesktopNum < 0 || DesktopNum >= DesktopCount) {
        return
    }
    GoToDesktopAndWait(DesktopNum)
    GameWinW := 0
    GameWinH := 0
    if (ActivateGameByTitle()) {
        return
    }
    Idx := DesktopNum + 1
    IX := 0
    IY := 0
    if (FindGameIcon(Idx, &IX, &IY)) {
        if (ActivateGameWindow(IX, IY)) {
            return
        }
    }
    ; 标题和图标都找不到，点一下来聚焦。
    try {
        Click(SwitchClickX, SwitchClickY)
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

; ===== 录鼠标和键盘 / 回放（快捷切换开着的时候才能用）=====
; 录鼠标（每次点下/松开左键/右键的位置和间隔）和键盘（每次按下/松开按键和间隔）。
; 回放按 F4：点一下回放 1 次；按住 F4 大约 2 秒是无限回放，
; 按住 2 秒后先显示「无限回放」提示，1 秒后开始循环回放，再按 F4 停掉。
; 每遍开始时光标旁边显示统计（回放 1 次显示「回放 1/1」，无限显示「无限回放 第 k 次」）。
RecordPoll() {
    global Recording, RecordEvents, RecordLastTick, RecordLastL, RecordLastR, KeysToRecord, KeyPrevState, txtQuickStatus
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
    ; 键盘：和鼠标一样，状态变了才记一条（按下记 KDown，松开记 KUp）。
    for Key in KeysToRecord {
        Down := GetKeyState(Key, "P")
        Prev := KeyPrevState.Has(Key) ? KeyPrevState[Key] : false
        if (Down && !Prev) {
            RecordEvents.Push(["KDown", Key, 0, Now - RecordLastTick])
            RecordLastTick := Now
            txtQuickStatus.Text := "状态：正在记录…已录 " RecordEvents.Length " 个动作"
        } else if (!Down && Prev) {
            RecordEvents.Push(["KUp", Key, 0, Now - RecordLastTick])
            RecordLastTick := Now
            txtQuickStatus.Text := "状态：正在记录…已录 " RecordEvents.Length " 个动作"
        }
        KeyPrevState[Key] := Down
    }
}

; 5 键：回放中按一下停回放；不回放时按一下开始/停止录制。
ToggleRecord(*) {
    global Recording, RecordEvents, RecordLastTick, RecordLastL, RecordLastR, PlayingBack, KeysToRecord, KeyPrevState, txtQuickStatus
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
        ; 键盘先记下当前状态，免得开始录的时候已经按着的键被当成新按下的记进去。
        KeyPrevState := Map()
        for Key in KeysToRecord {
            KeyPrevState[Key] := GetKeyState(Key, "P")
        }
        Recording := true
        SetTimer(RecordPoll, 10)
        txtQuickStatus.Text := "状态：正在记录鼠标和键盘…再按 F5 停止"
        ToolTip("正在记录鼠标和键盘…再按 F5 停止")
    }
}

; F4：点一下回放 1 次；按住大约 2 秒是无限回放。
; 按住 2 秒后先显示「无限回放」提示，1 秒后开始循环回放，
; 再按 F4 停掉（F5 也能停）。
F4Handler(*) {
    global Recording, RecordEvents, PlayingBack, txtQuickStatus
    if (Recording) {
        return
    }
    if (PlayingBack) {
        ; 正在回放，按 F4 就停掉（点一下还是按住都一样，立刻停）
        PlayingBack := false
        ToolTip()
        txtQuickStatus.Text := "状态：已录制 " RecordEvents.Length " 个动作，按 F4 回放"
        ShowTempToolTip("回放已停止")
        return
    }
    if (RecordEvents.Length = 0) {
        ShowTempToolTip("没有录制内容，先按 F5 录一段")
        return
    }
    ; 等 F4 松开，最多等 2 秒：2 秒内松开是点一下，超过 2 秒是按住。
    Released := KeyWait("F4", "T2")
    if (Released) {
        PlayRecording(1)
    } else {
        ToolTip("无限回放")
        Sleep(1000)
        PlayRecording(0)
    }
}

; 把录下来的鼠标动作执行 Count 遍（Count=0 是无限次，直到再按 F4 停掉）。
; 间隔按录的时候一样（最长 30 秒）。
; 有限次时每遍开始显示「回放 k/N」，无限时显示「无限回放 第 k 次」。
PlayRecording(Count) {
    global RecordEvents, PlayingBack, txtQuickStatus
    if (PlayingBack) {
        return
    }
    PlayingBack := true
    FinishedAll := true
    Round := 0
    Loop {
        Round++
        if (Count > 0 && Round > Count) {
            break
        }
        if (!PlayingBack) {
            FinishedAll := false
            break
        }
        if (Count > 0) {
            CountText := Round "/" Count
            ToolTip("回放 " CountText)
            txtQuickStatus.Text := "状态：正在回放 " CountText "…按 F4 停止"
        } else {
            ToolTip("无限回放 第 " Round " 次")
            txtQuickStatus.Text := "状态：无限回放 第 " Round " 次…按 F4 停止"
        }
        for Ev in RecordEvents {
            if (!PlayingBack) {
                FinishedAll := false
                break
            }
            Sleep(Min(Ev[4], 30000))
            if (!PlayingBack) {
                FinishedAll := false
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
            } else if (Ev[1] = "KDown") {
                try {
                    Send("{" Ev[2] " Down}")
                } catch {
                }
            } else if (Ev[1] = "KUp") {
                try {
                    Send("{" Ev[2] " Up}")
                } catch {
                }
            }
        }
        if (!PlayingBack) {
            FinishedAll := false
            break
        }
    }
    PlayingBack := false
    txtQuickStatus.Text := "状态：已录制 " RecordEvents.Length " 个动作，按 F4 回放"
    if (FinishedAll) {
        ToolTip()
        ShowTempToolTip("回放完成")
    } else {
        ; 中途停掉：松开可能还按着的修饰键和鼠标键，免得卡住。
        try {
            Send("{LShift Up}{RShift Up}{LCtrl Up}{RCtrl Up}{LAlt Up}{RAlt Up}")
            Click("Up")
            Click("Right Up")
        } catch {
        }
    }
    ; 中途停掉的，F4/F5 那边已经显示了「回放已停止」，这里不碰提示。
}

; ===== 快捷键 =====
; F10 = 跟随队长 开启 / 停止（和快捷切换不冲突，可以叠加使用）
; F11 = 桌面轮询 开启 / 停止（再启动从桌面 1 重新开始）
; F12 = 开箱子 开启 / 暂停
F10::ToggleFollow()
F11::ToggleDesktop()
F12::ToggleClickHotkey()
SC029::ToggleQuickSwitch()

; 快捷切换桌面的键盘：只在开关打开时生效（默认关），
; 关了 F1/F2/F3 就是正常的功能键，不会切桌面。
#HotIf QuickSwitchEnabled
F1::GoToDesktop(0)
F2::GoToDesktop(1)
F3::GoToDesktop(2)
F4::F4Handler()
F5::ToggleRecord()
#HotIf

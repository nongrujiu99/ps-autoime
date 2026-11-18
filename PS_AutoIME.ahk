; ==============================================================
;  PS 中文输入法 · 单字母快捷键助手   v2（诊断版）
;  运行环境：AutoHotkey v1.1 / Photoshop 2018
;
;  v2 相比 v1 的变化：
;   1. 新增日志：每次点击/切换都把「光标形态、目标输入法、切换是否成功」写进
;      PS_AutoIME.log，用于定位"到底哪一步没生效"
;   2. 切换改为「焦点窗口 + 前台窗口」双投递，并读回 HKL 判断是否真的成功
;   3. 新增「双击 = 要输入」规则，覆盖"双击图层缩略图进入文字编辑"这条路径
;   4. 新增 Ctrl+Alt+F8 状态快照
; ==============================================================

#NoEnv
#SingleInstance Force
SendMode Input
SetWorkingDir %A_ScriptDir%
Menu, Tray, Tip, PS 输入法助手 v2

; ---------------- 配置区 ----------------
FORCE_CN := true                ; 切中文时把搜狗的中/英状态拨到中文
LOG_ON   := true                ; 排查完把这里改成 false 就不再写日志
PS_EXE   := "ahk_exe Photoshop.exe"
HKL_EN_FALLBACK := 0x04090409
HKL_CN_FALLBACK := 0x08040804
; ---------------------------------------

g_Enabled   := true
g_LastClick := 0
g_InEdit    := false   ; 是否处于文字编辑会话（进入=中文，退出=英文，中间不插手）
LOG_FILE    := A_ScriptDir . "\PS_AutoIME.log"

InitLog()
Log("===== 启动 =====")
Log("布局数=" . GetLayoutCount() . " 英文HKL=" . Hex8(FindHKL(0x0409, 0)) . " 中文HKL=" . Hex8(FindHKL(0x0804, 0)))
Log("当前前台HKL=" . GetHKL())

; ---------------- 全局热键 ----------------
^!F11::
    g_Enabled := !g_Enabled
    Log("总开关 -> " . (g_Enabled ? "启用" : "暂停"))
    ToolTip % g_Enabled ? "PS 输入法助手：已启用" : "PS 输入法助手：已暂停"
    SetTimer, TipClear, -1500
return

^!F10::
    SetIME(true)
    ToolTip % "已切到中文输入法"
    SetTimer, TipClear, -1200
return

^!F9::
    SetIME(false)
    ToolTip % "已切到英文键盘"
    SetTimer, TipClear, -1200
return

^!F8::
    Log("快照: 前台HKL=" . GetHKL() . " 光标=" . A_Cursor . " 焦点hwnd=" . GetFocusHwnd())
    ToolTip % "HKL=" . GetHKL() . "`n光标=" . A_Cursor
    SetTimer, TipClear, -3000
return

^!F12::
    ToolTip % "当前输入法 HKL = " . GetHKL() . "`n已加载布局数 = " . GetLayoutCount()
    SetTimer, TipClear, -3000
return

TipClear:
    ToolTip
return

; ---------------- 主逻辑 ----------------
#If WinActive(PS_EXE) && g_Enabled

~LButton::
    now := A_TickCount
    isDbl := (now - g_LastClick < 400)
    g_LastClick := now
    cur := A_Cursor
    diag := " 焦点=" . GetFocusHwnd() . " 插入符=" . GetCaretHwnd()

    if (isDbl) {
        Log("[双击] 光标=" . cur . diag . " -> 中文（进入编辑）")
        SetIME(true)
        g_InEdit := true
        return
    }
    if (cur = "IBeam") {
        ; 已经在编辑里：可能是挪光标、拖选、点另一处文字。
        ; 这时不能重新强制中文，否则你在层内临时按 Shift 切到的英文会被顶回去。
        if (g_InEdit) {
            Log("[单击] 光标=IBeam 编辑中" . diag . " -> 保持当前输入状态")
        } else {
            Log("[单击] 光标=IBeam" . diag . " -> 中文（进入编辑）")
            SetIME(true)
            g_InEdit := true
        }
        return
    }
    Log("[单击] 光标=" . cur . diag . " -> 英文（非编辑）")
    SetIME(false)
    g_InEdit := false
return

~Esc::
    Log("[Esc] 切英文 结束编辑")
    SetIME(false)
    g_InEdit := false
return

; 提交文字编辑的三个键：小键盘回车、Ctrl+回车（主键盘回车是换行，不能碰）
~NumpadEnter::
~^NumpadEnter::
~^Enter::
    Log("[提交文字] 切英文 结束编辑")
    SetIME(false)
    g_InEdit := false
return

#If

; ---------------- 函数 ----------------

SetIME(toCN) {
    target := toCN ? FindHKL(0x0804, HKL_CN_FALLBACK) : FindHKL(0x0409, HKL_EN_FALLBACK)
    ok := SwitchIME(target)
    Log("    SetIME->" . (toCN ? "中文" : "英文") . " target=" . Hex8(target) . " 成功=" . (ok ? "是" : "否"))
    if (toCN && FORCE_CN)
        ForceIMEOpen()
}

SwitchIME(hkl) {
    global
    if !hkl
        return false
    fw := GetFocusHwnd()
    if (fw)
        PostMessage, 0x50, 0, %hkl%, , ahk_id %fw%
    PostMessage, 0x50, 0, %hkl%, , A
    Sleep, 45
    return (GetHKL() = Hex8(hkl))
}

; 取前台线程的焦点窗口（PS 画布是自定义窗口，ControlGetFocus 常拿不到，必须走这个）
GetFocusHwnd() {
    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if !hwnd
        return 0
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    size := 8 + A_PtrSize * 6 + 16
    VarSetCapacity(gti, size, 0)
    NumPut(size, gti, 0, "UInt")
    if !DllCall("GetGUIThreadInfo", "UInt", tid, "Ptr", &gti)
        return 0
    return NumGet(gti, 8 + A_PtrSize, "Ptr")
}

; 文本插入符句柄：PS 若真进入文字编辑，通常会创建一个系统插入符。
; 仅用于日志诊断——如果证实它可靠，下一步就改用"有没有插入符"来判断是否在编辑。
GetCaretHwnd() {
    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if !hwnd
        return 0
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    size := 8 + A_PtrSize * 6 + 16
    VarSetCapacity(gti, size, 0)
    NumPut(size, gti, 0, "UInt")
    if !DllCall("GetGUIThreadInfo", "UInt", tid, "Ptr", &gti)
        return 0
    return NumGet(gti, 8 + A_PtrSize * 5, "Ptr")
}

FindHKL(langId, fallback) {
    n := GetLayoutCount()
    if (n > 0) {
        VarSetCapacity(buf, n * A_PtrSize, 0)
        DllCall("GetKeyboardLayoutList", "Int", n, "Ptr", &buf, "Int")
        Loop, %n% {
            h := NumGet(buf, (A_Index - 1) * A_PtrSize, "Ptr")
            if ((h & 0xFFFF) = langId)
                return h
        }
    }
    return fallback
}

GetLayoutCount() {
    return DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0, "Int")
}

ForceIMEOpen() {
    hwnd := GetFocusHwnd()
    if !hwnd {
        ctl := ""
        ControlGetFocus, ctl, A
        if (ctl != "") {
            ControlGet, hwnd, Hwnd, , %ctl%, A
        }
    }
    if !hwnd
        return
    himc := DllCall("imm32\ImmGetContext", "Ptr", hwnd, "Ptr")
    if !himc
        return
    DllCall("imm32\ImmSetOpenStatus", "Ptr", himc, "Int", 1)
    DllCall("imm32\ImmReleaseContext", "Ptr", hwnd, "Ptr", himc)
}

GetHKL() {
    hwnd := WinExist("A")
    if !hwnd
        return "00000000"
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    return Hex8(DllCall("GetKeyboardLayout", "UInt", tid, "Ptr"))
}

Hex8(v) {
    return Format("{:08X}", v & 0xFFFFFFFF)
}

InitLog() {
    global LOG_FILE
    if FileExist(LOG_FILE) {
        FileGetSize, sz, %LOG_FILE%
        if (sz > 400000)
            FileDelete, %LOG_FILE%
    }
}

Log(msg) {
    global LOG_ON, LOG_FILE
    if !LOG_ON
        return
    FormatTime, ts, , HH:mm:ss
    FileAppend, % ts . "  " . msg . "`r`n", %LOG_FILE%
}

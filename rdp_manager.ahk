#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")

; ================== CONFIG ==================
global IniFile := A_ScriptDir . "\rdp_manager.ini"
global MonitorIndex := 1
global WinClass := "TscShellContainerClass"
global WinExe := "mstsc.exe"

; Slots are filled in reading order. (Optional: rename your RDP windows to match these)
global SlotTitles := ["macro1", "macro2", "macro3", "macro4", "macro5", "macro6", "macro7", "macro8"]

; Hotkeys
Hotkey("F1", ToggleRDPs)         ; F1 → minimize / restore all
Hotkey("F2", LayoutRDPs)         ; F2 → tile in slot order
Hotkey("F3", ShowSlotMap)        ; F3 → show slot ↔ window mapping
Hotkey("^!m", CycleMonitor)      ; Ctrl+Alt+M → cycle monitor
; ============================================

LoadSettings()

; Show startup instructions
TrayTip("RDP Manager Loaded", "F1: Minimize/Restore`nF2: Tile Windows`nF3: Show Map`nCtrl+Alt+M: Change Monitor", 1)

LoadSettings() {
    global IniFile, MonitorIndex
    if FileExist(IniFile) {
        try MonitorIndex := Integer(IniRead(IniFile, "Settings", "Monitor", "1"))
    }
}

SaveSettings() {
    global IniFile, MonitorIndex
    try IniWrite(MonitorIndex, IniFile, "Settings", "Monitor")
}

CycleMonitor(*) {
    global MonitorIndex
    maxMon := MonitorGetCount()
    MonitorIndex += 1
    if (MonitorIndex > maxMon)
        MonitorIndex := 1
    
    SaveSettings()
    ToolTip("RDP Manager target monitor set to: " . MonitorIndex)
    SetTimer(() => ToolTip(), -2000)
    
    ; Auto-tile to show the user it worked
    LayoutRDPs()
}

; --- Monitor work area ---
GetWorkArea(index) {
    if (index < 1 || index > MonitorGetCount())
        index := 1
    MonitorGetWorkArea(index, &L, &T, &R, &B)
    return {L: L, T: T, R: R, B: B}
}

; --- All live RDP windows ---
FindRDPWindows() {
    global WinClass, WinExe
    out := []
    ; Look for both the standard RDP class and the executable name just in case
    for hwnd in WinGetList("ahk_class " WinClass) {
        if WinExist("ahk_id " hwnd)
            out.Push(hwnd)
    }
    for hwnd in WinGetList("ahk_exe " WinExe) {
        if WinExist("ahk_id " hwnd) && !out.Has(hwnd)
            out.Push(hwnd)
    }
    return out
}

; --- Map each slot (in order) to a window handle ---
AssignSlots() {
    global SlotTitles
    all  := FindRDPWindows()
    used := Map()
    for hwnd in all
        used[hwnd] := false

    slots := []
    ; Pass 1: match by title, in SlotTitles order
    for needle in SlotTitles {
        match := 0
        for hwnd in all {
            if used[hwnd]
                continue
            if InStr(WinGetTitle("ahk_id " hwnd), needle) {
                match := hwnd
                used[hwnd] := true
                break
            }
        }
        slots.Push(match)   ; 0 = no window matched this slot
    }

    ; Pass 2: any leftover windows fill the first empty slot
    for hwnd in all {
        if used[hwnd]
            continue
        for i, val in slots {
            if (val = 0) {
                slots[i] := hwnd
                used[hwnd] := true
                break
            }
        }
    }
    
    ; Clean up empty slots at the end of the array
    finalSlots := []
    for hwnd in slots {
        if (hwnd != 0)
            finalSlots.Push(hwnd)
    }
    return finalSlots
}

; --- Dynamic Grid Math & Tiling ---
LayoutRDPs(*) {
    global MonitorIndex

    slots := AssignSlots()
    count := slots.Length
    
    if (count = 0) {
        ToolTip("No RDP windows found")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    ; Determine optimal columns/rows based on window count
    if (count == 1) {
        Cols := 1, Rows := 1
    } else if (count == 2) {
        Cols := 2, Rows := 1
    } else if (count == 3 || count == 4) {
        Cols := 2, Rows := 2
    } else if (count == 5 || count == 6) {
        Cols := 3, Rows := 2
    } else if (count == 7 || count == 8) {
        Cols := 4, Rows := 2
    } else {
        ; Fallback for 9+ windows
        Cols := Ceil(Sqrt(count))
        Rows := Ceil(count / Cols)
    }

    m      := GetWorkArea(MonitorIndex)
    totalW := m.R - m.L
    totalH := m.B - m.T
    cellW  := totalW // Cols
    cellH  := totalH // Rows

    for i, hwnd in slots {
        idx := i - 1
        col := Mod(idx, Cols)
        row := idx // Cols

        x := m.L + col * cellW
        y := m.T + row * cellH
        
        ; Adjust last column/row to fill exactly to the edge without gaps
        w := (col = Cols - 1) ? (totalW - col * cellW) : cellW
        h := (row = Rows - 1) ? (totalH - row * cellH) : cellH

        ; FIX: Always restore before moving. RDP windows often ignore WinMove if maximized.
        WinRestore("ahk_id " hwnd)
        Sleep(50) ; Give the window a split second to un-maximize
        WinMove(x, y, w, h, "ahk_id " hwnd)
    }
}

; --- Minimize all / restore + tile ---
ToggleRDPs(*) {
    wins := FindRDPWindows()
    if (wins.Length = 0) {
        ToolTip("No RDP windows found")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    anyVisible := false
    for hwnd in wins {
        if (WinGetMinMax("ahk_id " hwnd) != -1) { ; Not minimized
            anyVisible := true
            break
        }
    }

    if (anyVisible) {
        for hwnd in wins
            WinMinimize("ahk_id " hwnd)
    } else {
        LayoutRDPs()
        for hwnd in wins
            WinActivate("ahk_id " hwnd)
    }
}

; --- Debug: show which window matched which slot ---
ShowSlotMap(*) {
    slots := AssignSlots()
    out := "Live RDP Windows found: " . slots.Length . "`n`n"
    for i, hwnd in slots {
        title := WinGetTitle("ahk_id " hwnd)
        out .= Format("Slot {}:`n  → {}{}`n`n", i, title, hwnd ? "" : "  ⚠")
    }
    MsgBox(out, "RDP Slot Map")
}
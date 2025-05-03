#SingleInstance Force
#Persistent
#NoTrayIcon
SetBatchLines, -1
DetectHiddenWindows, On

; Initialize global variables
global AppTimeout := 5
global AppIdle := 0
global IsIdle := false
global AppList := {}
global CurrentTimer := "--:--:--"
global ActiveExe := ""
global TimerRunning := false
global DataFile := A_ScriptDir . "\time-tracker-data.ini"

; Load saved data if exists
LoadSavedData()

; Create main GUI
Gui, Main: New, +AlwaysOnTop -MinimizeBox, Tracker
Gui, Main: Font, s18, Consolas
Gui, Main: Add, Text, vTimerLabel x5 y6 w110 h30, Time: %CurrentTimer%
Gui, Main: Font, s10
Gui, Main: Add, Button, gShowMenu x122 y8 w50 h25, Menu
Gui, Main: Show, w180 h40 NoActivate

; Add icon
hIcon := LoadPicture("laksapedia-logo.ico", "Icon1 w32 h32", imgtype)
Gui, Main: Show
SendMessage, 0x80, 0, hIcon,, A  ; WM_SETICON, ICON_SMALL
SendMessage, 0x80, 1, hIcon,, A  ; WM_SETICON, ICON_BIG
; Menu, Tray, Icon, %IconFilePath% ; if #NoTrayIcon flag is off, we can customize the icon here

; Create menu GUI - added AlwaysOnTop flag
Gui, Menu: New, +AlwaysOnTop + ToolWindow + Owner, Tracker Menu
Gui, Menu: Add, Button, gResetTimer w150 h30, Reset current timer
Gui, Menu: Add, Button, gResetAllTimers w150 h30, Reset ALL timers
Gui, Menu: Add, Button, gTrackNewApp w150 h30, Track new app
Gui, Menu: Add, Button, gShowRemoveMenu w150 h30, Remove tracked app
Gui, Menu: Add, Button, gShowTimeoutMenu w150 h30, Set timeout
Gui, Menu: Add, Button, gCloseMenu w150 h30, Close Menu

; Create app selection GUI
Gui, SelectApp: New, +AlwaysOnTop + ToolWindow + Owner, Select App
Gui, SelectApp: Add, Text, , Click on any window or taskbar button to select the app to track.
Gui, SelectApp: Add, Button, gCancelSelection w100 h25, Cancel

; Create app name input GUI - added AlwaysOnTop flag
Gui, NameApp: New, +AlwaysOnTop + ToolWindow + Owner, Name App
Gui, NameApp: Add, Text, , Enter name for this app:
Gui, NameApp: Add, Edit, vAppNameInput w200
Gui, NameApp: Add, Button, gSaveAppName w100 h25, OK
Gui, NameApp: Add, Button, gCancelNaming w100 h25, Cancel

; Create remove app GUI - added AlwaysOnTop flag
Gui, RemoveApp: New, +AlwaysOnTop + ToolWindow + Owner, Remove App
Gui, RemoveApp: Add, ListBox, vAppToRemove w200 h150
Gui, RemoveApp: Add, Button, gRemoveSelectedApp w100 h25, Remove
Gui, RemoveApp: Add, Button, gCancelRemoval w100 h25, Cancel

; GUI for setting timeout
Gui, TimeoutApp: New, +AlwaysOnTop + ToolWindow + Owner, Set Timeout App
Gui, TimeoutApp: Add, Text, x5 y10, Set idle timeout (seconds):
Gui, TimeoutApp: Add, Edit, vTimeoutInput x140 y7 w30
Gui, TimeoutApp: Add, Button, gTimeoutSet x180 y5 w40 h25, Set

; Start the timer loop
SetTimer, CheckActiveWindow, 500
SetTimer, UpdateTimer, 1000
SetTimer, CheckMouseMove, 100
SetTimer, CheckKeyPress, 10

ResetLabels()
UpdateGui()

return

; Function to load saved data
LoadSavedData() {
    if FileExist(DataFile) {
        IniRead, AppTimeout, %DataFile%, Timeout, AppTimeout, 5

        IniRead, AppCount, %DataFile%, General, AppCount, 0
        if (AppCount > 0) {
            loop, %AppCount% {
                IniRead, AppExe, %DataFile%, Apps, App%A_Index%_Exe
                IniRead, AppName, %DataFile%, Apps, App%A_Index%_Name
                IniRead, AppTime, %DataFile%, Apps, App%A_Index%_Time, 0

                AppList[AppExe] := { Name: AppName, Time: AppTime }
            }
        }
    }
}

; Function to save data
SaveData() {
    FileDelete, %DataFile%

    AppCount := 0
    for AppExe, AppData in AppList {
        AppCount++
        IniWrite, % AppExe, %DataFile%, Apps, App%AppCount%_Exe
        IniWrite, % AppData.Name, %DataFile%, Apps, App%AppCount%_Name
        IniWrite, % AppData.Time, %DataFile%, Apps, App%AppCount%_Time
    }

    IniWrite, %AppCount%, %DataFile%, General, AppCount
    IniWrite, %AppTimeout%, %DataFile%, Timeout, AppTimeout
}

; Check which window is active
CheckActiveWindow:
    WinGet, CurrentWinID, ID, A
    WinGet, CurrentExeName, ProcessName, ahk_id %CurrentWinID%

    ; Skip if it's the tracker itself or its submenus
    WinGet, TrackerID, ID, Tracker
    WinGet, MenuID, ID, Tracker Menu
    WinGet, SelectAppID, ID, Select App
    WinGet, NameAppID, ID, Name App
    WinGet, RemoveAppID, ID, Remove App

    Gui, Main: Color, Silver

    if (CurrentWinID = TrackerID || CurrentWinID = MenuID || CurrentWinID = SelectAppID || CurrentWinID = NameAppID || CurrentWinID = RemoveAppID) {
        return
    }

    ; Check if the window is minimized
    WinGet, MinMax, MinMax, ahk_id %CurrentWinID%
    IsMinimized := (MinMax = -1)

    ; Update the active app
    if (AppList.HasKey(CurrentExeName)) {
        Gui, Main: Show, NoActivate, %CurrentExeName%
        ActiveExe := CurrentExeName
        CurrentTimer := FormatTime(AppList[CurrentExeName].Time)
        TimerRunning := true

        if (!IsIdle && !IsMinimized) {
            Gui, Main: Color, Green
        }
    }

    Gui, Main: Show, NoActivate

    UpdateGui()
    return

; Update the timer
UpdateTimer:
    if (!IsIdle && TimerRunning && ActiveExe != "") {
        ; Make sure the app is still active and not minimized
        WinGet, CurrentActiveID, ID, A
        WinGet, MinMax, MinMax, ahk_id %CurrentActiveID%
        WinGet, CurrentExeName, ProcessName, ahk_id %CurrentActiveID%

        IsMinimized := (MinMax = -1)

        if (CurrentExeName = ActiveExe && !IsMinimized) {
            ; Increment timer for active app
            AppList[ActiveExe].Time += 1
            AppIdle += 1
            CurrentTimer := FormatTime(AppList[ActiveExe].Time)
            UpdateGui()

            if (AppIdle >= AppTimeout) {
                IsIdle := true
                Gui, Main: Color, Silver
                Gui, Main: Show, NoActivate
            }
        } else {
            ; The window is no longer active, pause the timer
            TimerRunning := false
        }
    }
    return

CheckMouseMove:
    MouseGetPos, xNow, yNow
    if (xNow != xLast || yNow != yLast) {
        ; ToolTip, Mouse moved to: %xNow%, %yNow% ; for debugging
        xLast := xNow
        yLast := yNow

        AppIdle := 0
        IsIdle := false
    }
    return

CheckKeyPress:
    Input, key, L1 V, {LShift}{RShift}{LControl}{RControl}{LAlt}{RAlt}{LWin}{RWin}
    if (ErrorLevel != "Timeout") {
        AppIdle := 0
        IsIdle := false
    }

    return

~LButton::
~MButton::
~WheelUp::
~WheelDown::
~RButton::
    AppIdle := 0
    IsIdle := false
    return

; Format time in HH:MM:SS
FormatTime(Seconds) {
    Hours := Floor(Seconds / 3600)
    Minutes := Floor(Mod(Seconds, 3600) / 60)
    Seconds := Mod(Seconds, 60)
    return Format("{:02}:{:02}:{:02}", Hours, Minutes, Seconds)
}

ResetLabels() {
    Gui, Main: Color, Silver
    Gui, Main: Show, NoActivate
    ActiveExe := ""
    CurrentTimer := "--:--:--"
    TimerRunning := false
}

UpdateGui() {
    GuiControl, Main:, TimerLabel, %CurrentTimer%
}

; Show menu
ShowMenu:
    Gui, Main: +Disabled
    Gui, Menu: Show, w170 h220
    return

ResetTimer() {
    if (AppList.HasKey(ActiveExe)) {
        AppList[ActiveExe].Time := 0
        CurrentTimer := FormatTime(AppList[ActiveExe].Time)
        UpdateGui()
    }
}

ResetAllTimers() {
    for ExeName, _ in AppList {
        AppList[ExeName].Time := 0
    }
    CurrentTimer := FormatTime(AppList[ActiveExe].Time)
    UpdateGui()
}

; Close menu
CloseMenu:
    Gui, Menu: Hide
    Gui, Main: -Disabled
    Gui, Main: Show
    return

; Track new app
TrackNewApp:
    Gui, Menu: Hide
    Gui, SelectApp: Show, w400 h100
    SetTimer, WaitForWindowSelection, 10
    return

; Wait for window selection
WaitForWindowSelection:
    ; Check for mouse click
    if GetKeyState("LButton", "P") {
        ; Store current active window
        WinGet, PreviousActiveWindow, ID, A
        WinGet, PreviousExeName, ProcessName, ahk_id %PreviousActiveWindow%

        ; Wait for new window to activate after click
        Sleep, 300  ; Short delay to allow window activation

        ; Get newly activated window
        WinGet, SelectedWindowID, ID, A
        WinGet, SelectedExeName, ProcessName, ahk_id %SelectedWindowID%

        ; If active window changed and is not one of our GUIs
        if (SelectedExeName != PreviousExeName) {
            ; Skip if it's one of our GUIs
            WinGet, TrackerID, ID, Tracker
            WinGet, MenuID, ID, Tracker Menu
            WinGet, SelectAppID, ID, Select App
            WinGet, NameAppID, ID, Name App
            WinGet, RemoveAppID, ID, Remove App

            if (SelectedWindowID != TrackerID && SelectedWindowID != MenuID && SelectedWindowID != SelectAppID && SelectedWindowID != NameAppID && SelectedWindowID != RemoveAppID) {
                ; Selected a valid window
                SetTimer, WaitForWindowSelection, Off
                Gui, SelectApp: Hide

                ; Show input dialog for app name
                GuiControl, NameApp:, AppNameInput, %SelectedExeName%
                Gui, NameApp: Show, w220 h120
            }
        }
    }
    return

; Cancel selection
CancelSelection:
    SetTimer, WaitForWindowSelection, Off
    Gui, SelectApp: Hide
    Gui, Menu: Show
    return

; Save app name
SaveAppName:
    Gui, NameApp: Submit
    Gui, NameApp: Hide

    ; Add app to tracking list
    AppList[SelectedExeName] := { Name: AppNameInput, Time: 0 }

    ; Save data
    SaveData()

    ; Show menu again
    Gui, Menu: Show
    return

; Cancel naming
CancelNaming:
    Gui, NameApp: Hide
    Gui, Menu: Show
    return

; Show remove menu
ShowRemoveMenu() {
    ; Clear listbox
    GuiControl, RemoveApp:, AppToRemove, |
        ; Populate listbox with tracked apps
        for _ExeName, AppData in AppList {
            GuiControl, RemoveApp:, AppToRemove, % AppData.Name
        }
        Gui, Menu: Hide
    Gui, RemoveApp: Show, w220 h220
}

; Remove selected app
RemoveSelectedApp:
    Gui, RemoveApp: Submit, NoHide

    ; Find app ID by name
    if (AppToRemove) {
        for ExeName, AppData in AppList {
            if (AppData.Name = AppToRemove) {
                AppList.Delete(ExeName)
                break
            }
        }

        ; Save data
        SaveData()
    }

    ShowRemoveMenu()
    return

; Cancel removal
CancelRemoval:
    Gui, RemoveApp: Hide
    Gui, Menu: Show
    return

ShowTimeoutMenu:
    Gui, Menu: Hide
    Gui, TimeoutApp: Show, w250 h50
    GuiControl, TimeoutApp: , TimeoutInput, %AppTimeout%
    return

TimeoutSet:
    Gui, TimeoutApp: Submit, NoHide
    AppTimeout := TimeoutInput + 0 ; force to number
    Gui, TimeoutApp: Hide
    Gui, Menu: Show
    SaveData()
    return

; Add handlers for X button closes on all GUIs
MenuGuiClose:
    Gui, Menu: Hide
    Gui, Main: -Disabled
    Gui, Main: Show
    return

SelectAppGuiClose:
    SetTimer, WaitForWindowSelection, Off
    Gui, SelectApp: Hide
    Gui, Main: -Disabled
    Gui, Menu: Show
    return

NameAppGuiClose:
    Gui, NameApp: Hide
    Gui, Main: -Disabled
    Gui, Menu: Show
    return

RemoveAppGuiClose:
    Gui, RemoveApp: Hide
    Gui, Main: -Disabled
    Gui, Menu: Show
    return

TimeoutAppGuiClose:
    Gui, TimeoutApp: Hide
    Gui, Main: -Disabled
    Gui, Menu: Show
    return

; Exit event
GuiClose:
MainGuiClose:
    ; Save data before exiting
    SaveData()
    ExitApp
    return
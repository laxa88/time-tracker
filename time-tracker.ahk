#SingleInstance Force
#Persistent
SetBatchLines, -1
DetectHiddenWindows, On

; Initialize global variables
global AppList := {}
; global CurrentApp := "Not tracked"
global CurrentTimer := "--:--:--"
global ActiveAppID := ""
global TimerRunning := false
global DataFile := A_ScriptDir . "\TrackerData.ini"

; Load saved data if exists
LoadSavedData()

; Create main GUI
Gui, Main: New, +AlwaysOnTop + ToolWindow + Resize, Tracker
; Gui, Main: Add, Text, vAppNameLabel w280 h20, App: %CurrentApp%
Gui, Main: Font, s18, Consolas
Gui, Main: Add, Text, vTimerLabel x5 y5 w120 h30, Time: %CurrentTimer%
Gui, Main: Font, s10
Gui, Main: Add, Button, gShowMenu x200 y5 w50 h25, Menu
; Gui, Main: Add, Button, gResetTimer x130 y5 w50 h25, Reset
Gui, Main: Show, w260 h40 NoActivate

; Create menu GUI - added AlwaysOnTop flag
Gui, Menu: New, +AlwaysOnTop + ToolWindow + Owner, Tracker Menu
Gui, Menu: Add, Button, gResetTimer w150 h30, Reset current timer
Gui, Menu: Add, Button, gTrackNewApp w150 h30, Track New App
Gui, Menu: Add, Button, gShowRemoveMenu w150 h30, Remove App
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

; Start the timer loop
SetTimer, CheckActiveWindow, 500
SetTimer, UpdateTimer, 1000

ResetLabels()
UpdateGui()

return

; Function to load saved data
LoadSavedData() {
    if FileExist(DataFile) {
        IniRead, AppCount, %DataFile%, General, AppCount, 0
        if (AppCount > 0) {
            loop, %AppCount% {
                IniRead, AppID, %DataFile%, Apps, App%A_Index%_ID
                IniRead, AppName, %DataFile%, Apps, App%A_Index%_Name
                IniRead, AppTime, %DataFile%, Apps, App%A_Index%_Time, 0

                AppList[AppID] := { Name: AppName, Time: AppTime }
            }
        }
    }
}

; Function to save data
SaveData() {
    FileDelete, %DataFile%

    AppCount := 0
    for AppID, AppData in AppList {
        AppCount++
        IniWrite, % AppID, %DataFile%, Apps, App%AppCount%_ID
        IniWrite, % AppData.Name, %DataFile%, Apps, App%AppCount%_Name
        IniWrite, % AppData.Time, %DataFile%, Apps, App%AppCount%_Time
    }

    IniWrite, %AppCount%, %DataFile%, General, AppCount
}

; Check which window is active
CheckActiveWindow:
    WinGet, CurrentWinID, ID, A
    WinGetTitle, CurrentWinTitle, ahk_id %CurrentWinID%

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
    if (AppList.HasKey(CurrentWinID)) {
        Gui, Main: Show, NoActivate, %CurrentWinTitle%
        ActiveAppID := CurrentWinID
        ; CurrentApp := AppList[CurrentWinID].Name
        CurrentTimer := FormatTime(AppList[CurrentWinID].Time)
        TimerRunning := true

        if (!IsMinimized) {
            Gui, Main: Color, Green
        } else {
            Gui, Main: Color, Red
        }
    }

    Gui, Main: Show, NoActivate

    UpdateGui()
    return

; Update the timer
UpdateTimer:
    if (TimerRunning && ActiveAppID != "") {
        ; Make sure the app is still active and not minimized
        WinGet, CurrentActiveID, ID, A
        WinGet, MinMax, MinMax, ahk_id %CurrentActiveID%
        IsMinimized := (MinMax = -1)

        if (CurrentActiveID = ActiveAppID && !IsMinimized) {
            ; Increment timer for active app
            AppList[ActiveAppID].Time += 1
            CurrentTimer := FormatTime(AppList[ActiveAppID].Time)
            UpdateGui()
        } else {
            ; The window is no longer active, pause the timer
            TimerRunning := false
        }
    }
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
    ActiveAppID := ""
    ; CurrentApp := "[untracked] " . CurrentWinTitle
    CurrentTimer := "--:--:--"
    TimerRunning := false
}

UpdateGui() {
    ; GuiControl, Main:, AppNameLabel, App: %CurrentApp%
    GuiControl, Main:, TimerLabel, %CurrentTimer%
}

; Show menu
ShowMenu:
    Gui, Main: +Disabled
    Gui, Menu: Show, w170 h150
    return

ResetTimer() {
    if (AppList.HasKey(ActiveAppID)) {
        AppList[ActiveAppID].Time := 0
        CurrentTimer := FormatTime(AppList[CurrentWinID].Time)
        UpdateGui()
    }
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
    SetTimer, WaitForWindowSelection, 100
    return

; Wait for window selection
WaitForWindowSelection:
    ; Check for mouse click
    if GetKeyState("LButton", "P") {
        ; Store current active window
        WinGet, PreviousActiveWindow, ID, A

        ; Wait for new window to activate after click
        Sleep, 300  ; Short delay to allow window activation

        ; Get newly activated window
        WinGet, SelectedWindowID, ID, A
        WinGetTitle, WindowTitle, ahk_id %SelectedWindowID%

        ; If active window changed and is not one of our GUIs
        if (SelectedWindowID != PreviousActiveWindow) {
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
                GuiControl, NameApp:, AppNameInput, %WindowTitle%
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
    AppList[SelectedWindowID] := { Name: AppNameInput, Time: 0 }

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
ShowRemoveMenu:
    ; Clear listbox
    GuiControl, RemoveApp:, AppToRemove, |
        ; Populate listbox with tracked apps
        for AppID, AppData in AppList {
            GuiControl, RemoveApp:, AppToRemove, % AppData.Name
            }
            Gui, Menu: Hide
    Gui, RemoveApp: Show, w220 h220
    return

; Remove selected app
RemoveSelectedApp:
    Gui, RemoveApp: Submit, NoHide

    ; Find app ID by name
    if (AppToRemove) {
        for AppID, AppData in AppList {
            if (AppData.Name = AppToRemove) {
                AppList.Delete(AppID)
                break
            }
        }

        ; Save data
        SaveData()
    }

    Gui, RemoveApp: Hide
    Gui, Menu: Show
    return

; Cancel removal
CancelRemoval:
    Gui, RemoveApp: Hide
    Gui, Menu: Show
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

; Exit event
GuiClose:
MainGuiClose:
    ; Save data before exiting
    SaveData()
    ExitApp
    return
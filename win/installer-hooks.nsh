; Hooks for the Tauri NSIS installer (bundle.windows.nsis.installerHooks in tauri.conf.json).
;
; KeyCat installs for all users into Program Files (installMode perMachine), a folder only
; administrators can change: the login task of 以管理员身份运行 starts it elevated without asking,
; so it must not start anything the user's own programs could have replaced. The installer runs
; in the all-users context, where $APPDATA and $LOCALAPPDATA name ProgramData; the per-user paths
; below switch to the current user's first.
;
; Up to 1.0.1 KeyCat for Windows was an Electron app in %LOCALAPPDATA%\Programs\KeyCat. Its
; updater downloads this installer like any other release, so here the old copy is removed and
; its settings and start-at-login choice move over; otherwise two cats would run side by side.
; Its updater passes --force-run when the app should start again afterwards.

Var MigratedFromElectron

!macro NSIS_HOOK_PREINSTALL
  SetShellVarContext current
  StrCpy $R8 "$LOCALAPPDATA\Programs\KeyCat"
  ${If} ${FileExists} "$R8\Uninstall KeyCat.exe"
    DetailPrint "Removing KeyCat 1.0 (Electron)"
    StrCpy $MigratedFromElectron 1
    nsExec::Exec 'taskkill /f /im KeyCat.exe'
    Pop $R9
    ExecWait '"$R8\Uninstall KeyCat.exe" /S _?=$R8'
    Delete "$R8\Uninstall KeyCat.exe"
    RMDir "$R8"
  ${EndIf}

  ; Electron registered start at login under its AppUserModelId; the new build uses the product name.
  ReadRegStr $R9 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "com.ellobok.keycat"
  ${If} $R9 != ""
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "com.ellobok.keycat"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "KeyCat" '"$INSTDIR\KeyCat.exe"'
  ${EndIf}

  ; "Local State" marks the folder as Electron's profile; only settings.json is worth keeping.
  ${If} ${FileExists} "$APPDATA\KeyCat\Local State"
    ${IfNot} ${FileExists} "$APPDATA\com.ellobok.keycat\settings.json"
    ${AndIf} ${FileExists} "$APPDATA\KeyCat\settings.json"
      CreateDirectory "$APPDATA\com.ellobok.keycat"
      CopyFiles /SILENT "$APPDATA\KeyCat\settings.json" "$APPDATA\com.ellobok.keycat"
    ${EndIf}
    RMDir /r "$APPDATA\KeyCat"
  ${EndIf}
  RMDir /r "$LOCALAPPDATA\keycat-win-updater"

  ; Up to 1.0.4 the Tauri build installed per user into %LOCALAPPDATA%\KeyCat. That copy goes; an
  ; uninstall without /UPDATE also drops its Run value, so start at login is pointed at this one.
  StrCpy $R8 "$LOCALAPPDATA\${PRODUCTNAME}"
  ${If} $R8 != $INSTDIR
  ${AndIf} ${FileExists} "$R8\uninstall.exe"
    DetailPrint "Removing the per-user KeyCat in $R8"
    ReadRegStr $R7 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PRODUCTNAME}"
    nsExec::Exec 'taskkill /f /im ${MAINBINARYNAME}.exe'
    Pop $R9
    ExecWait '"$R8\uninstall.exe" /S _?=$R8'
    Delete "$R8\uninstall.exe"
    RMDir "$R8"
    ${If} $R7 != ""
      WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PRODUCTNAME}" '"$INSTDIR\${MAINBINARYNAME}.exe"'
    ${EndIf}
  ${EndIf}

  ; A login task that starts KeyCat from anywhere but this folder (a per-user copy, or one removed
  ; by hand) is deleted: whatever sits at that path would start elevated. The Run value takes over
  ; start at login, and KeyCat makes the task again for this copy the next time it runs elevated.
  ; The task is named after the account, as in win/src/autostart.rs.
  System::Call 'Kernel32::SetEnvironmentVariable(t "KEYCAT_EXE", t "$INSTDIR\${MAINBINARYNAME}.exe")'
  nsExec::Exec `powershell -NoProfile -NonInteractive -Command "$$t = Get-ScheduledTask -TaskName ('KeyCat (' + $$env:USERNAME + ')') -ErrorAction SilentlyContinue; if ($$t -and $$t.Actions[0].Execute.Trim([char]34) -ne $$env:KEYCAT_EXE) { Unregister-ScheduledTask -InputObject $$t -Confirm:$$false; exit 2 }"`
  Pop $R9
  ${If} $R9 = 2
    DetailPrint "Removed a login task for another copy of KeyCat"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PRODUCTNAME}" '"$INSTDIR\${MAINBINARYNAME}.exe"'
  ${EndIf}
  SetShellVarContext all
!macroend

!macro NSIS_HOOK_POSTINSTALL
  ${If} $MigratedFromElectron = 1
    ClearErrors
    ${GetOptions} $CMDLINE "--force-run" $R9
    ${IfNot} ${Errors}
      nsis_tauri_utils::RunAsUser "$INSTDIR\KeyCat.exe" ""
    ${EndIf}
  ${EndIf}
!macroend

; The login task is not part of the install, so the uninstaller removes it (not when updating,
; which keeps start at login as it is).
!macro NSIS_HOOK_PREUNINSTALL
  ${If} $UpdateMode <> 1
    ReadEnvStr $R9 USERNAME
    nsExec::Exec 'schtasks /Delete /F /TN "KeyCat ($R9)"'
    Pop $R9
  ${EndIf}
!macroend

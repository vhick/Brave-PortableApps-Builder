; Independent, open-source NSIS installer for a pre-verified BravePortable payload.
; This is NOT the official PortableApps.com Installer, nor an endorsed package.
; Data is NEVER embedded, deleted, overwritten, or recursively cleaned by this installer.
; Compile headlessly: makensis /V3 /DAPP_VERSION=... /DSOURCE_DIR=... /DOUTPUT_PATH=... script.nsi
Unicode true
!include "MUI2.nsh"

!ifndef APP_VERSION
  !error "APP_VERSION must be supplied"
!endif
!ifndef SOURCE_DIR
  !error "SOURCE_DIR must point to the verified BravePortable staging folder"
!endif
!ifndef OUTPUT_PATH
  !error "OUTPUT_PATH must name the generated community NSIS .paf.exe"
!endif

Name "Brave Portable ${APP_VERSION} (independent NSIS package)"
OutFile "${OUTPUT_PATH}"
InstallDir "$DOCUMENTS\PortableApps\BravePortable"
RequestExecutionLevel user
SetCompressor /FINAL zlib
SetDatablockOptimize on
CRCCheck force
ShowInstDetails show
AutoCloseWindow false
BrandingText "Independent NSIS build - not the official PortableApps.com Installer"
!define MUI_ICON "${SOURCE_DIR}\App\AppInfo\appicon.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Brave Portable ${APP_VERSION} - independent installer"
!define MUI_WELCOMEPAGE_TEXT "This independent NSIS installer deploys the validated BravePortable application.$\r$\n$\r$\nIt does not install Brave system-wide or modify the Windows registry. Existing portable Data folders are preserved.$\r$\n$\r$\nClose Brave Portable before upgrading."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_LANGUAGE "English"

; Abort with a nonzero code in both interactive and silent mode.
Function FailTarget
  IfSilent +2 0
    MessageBox MB_ICONSTOP|MB_OK "$0"
  DetailPrint "ABORT: $0"
  SetErrorLevel 2
  Abort
FunctionEnd

Function .onInit
  ; Auto-detect the Platform only when its original default wasn't overridden.
  ; An explicit NSIS /D= path always takes precedence.
  StrCmp "$INSTDIR" "$DOCUMENTS\PortableApps\BravePortable" 0 platform_done
  IfFileExists "$EXEDIR\PortableApps\PortableApps.com\PortableAppsPlatform.exe" 0 +2
    StrCpy $INSTDIR "$EXEDIR\PortableApps\BravePortable"
  IfFileExists "$EXEDIR\PortableApps.com\PortableAppsPlatform.exe" 0 +2
    StrCpy $INSTDIR "$EXEDIR\BravePortable"
platform_done:
FunctionEnd

Function CheckDestination
  ; Refuse paths occupied by other applications, unknown Data-only leftovers,
  ; or a Brave Portable folder with an unexpected application identifier.
  IfFileExists "$INSTDIR\App\AppInfo\appinfo.ini" known_install new_install
known_install:
  ReadINIStr $1 "$INSTDIR\App\AppInfo\appinfo.ini" "Details" "AppID"
  StrCmp $1 "BravePortableIndependent" validated
  StrCpy $0 "Destination contains another application's metadata (AppID: $1). No files were changed."
  Call FailTarget
new_install:
  IfFileExists "$INSTDIR\*.*" 0 validated
  StrCpy $0 "Destination is not empty and is not a recognized BravePortableIndependent install. No files were changed."
  Call FailTarget
validated:
  ; Exclusive FILE_SHARE_NONE probes ensure we do not update active executables.
  ; Access denied also aborts safely; user must close the application or choose
  ; a writable location. No processes are force-terminated.
  IfFileExists "$INSTDIR\BravePortable.exe" 0 test_brave
    System::Call 'kernel32::CreateFileW(w "$INSTDIR\BravePortable.exe", i 0x80000000, i 0, p 0, i 3, i 0, p 0) p .r2'
    StrCmp $2 "-1" launcher_locked
    System::Call 'kernel32::CloseHandle(p r2)'
    Goto test_brave
launcher_locked:
    StrCpy $0 "BravePortable.exe is in use or inaccessible. Close Brave Portable before upgrading. No files were changed."
    Call FailTarget
test_brave:
  IfFileExists "$INSTDIR\App\Brave\brave.exe" 0 checked
    System::Call 'kernel32::CreateFileW(w "$INSTDIR\App\Brave\brave.exe", i 0x80000000, i 0, p 0, i 3, i 0, p 0) p .r2'
    StrCmp $2 "-1" browser_locked
    System::Call 'kernel32::CloseHandle(p r2)'
    Goto checked
browser_locked:
    StrCpy $0 "Brave browser executable is in use or inaccessible. Close the portable browser before upgrading. No files were changed."
    Call FailTarget
checked:
FunctionEnd

Section "Brave Portable" Core
  Call CheckDestination
  ; Preserve existing Data exactly. It is never a File input and never removed.
  SetOverwrite on
  SetOutPath "$INSTDIR"
  File "${SOURCE_DIR}\BravePortable.exe"
  SetOutPath "$INSTDIR\App"
  File /r "${SOURCE_DIR}\App\*.*"
  SetOutPath "$INSTDIR\Other"
  File /r "${SOURCE_DIR}\Other\*.*"
  CreateDirectory "$INSTDIR\Data"
  DetailPrint "Installed program files. Existing Data directory was not touched."
SectionEnd

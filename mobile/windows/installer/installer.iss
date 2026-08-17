; Inno Setup script for Ironpeak Fitness (Windows).
;
; Before this file existed, windows.yml only produced a plain .zip of the
; Release folder — "download the update, tap install" then just opened
; that zip in Explorer, it never actually replaced the running app. This
; compiles into a real setup.exe: a normal install wizard, a Start Menu
; shortcut, a proper uninstaller registered in "Apps & Features", and —
; via CloseApplications/RestartApplications below — it closes a currently
; running Ironpeak Fitness before installing and relaunches it afterwards,
; which is what actually makes UpdateProvider's "download -> install ->
; it's the new version" flow true on Windows.
;
; #MyAppVersion is passed in from windows.yml at compile time
; (`iscc /DMyAppVersion=1.2.3 installer.iss`) so the installer's version
; always matches the tag the release was built from, same as the app
; binary itself (see Runner.rc's VERSION_AS_STRING). The /D default below
; only matters for a local/manual `iscc` run with nothing passed in.
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "Ironpeak Fitness"
#define MyAppPublisher "Ironpeak Fitness"
#define MyAppExeName "ironpeak_mobile.exe"
; Fixed and must never change between releases -- this is what lets Inno
; Setup recognize "this is an upgrade of an existing install" (same
; install dir, replaces in place, keeps it in Apps & Features as one
; entry) instead of installing a confusing second copy side by side.
; The doubled leading "{{" is required, not a typo -- Inno Setup treats a
; single "{" in a [Setup] value as the start of a {constant} reference
; (like {app}), so a literal brace (as GUIDs need here) must be escaped by
; doubling it, per ISCC's own "Unknown constant" error message.
#define MyAppId "{{720BC523-8F21-48FF-8EAB-558CA030078B}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename=ironpeak-fitness-windows-setup
OutputDir=..\..\build\windows\x64\runner
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
; Closes an already-running instance of the app before copying files over
; it (a normal install can't overwrite a locked, running .exe/.dll), and
; relaunches whatever it closed once the new files are in place -- so an
; update triggered from inside the running app really does end with the
; new version open, not just "installed, please find and reopen it
; yourself".
CloseApplications=yes
CloseApplicationsFilter=*.exe,*.dll
RestartApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The whole Release output (the .exe plus its sibling flutter_windows.dll,
; plugin DLLs, and data\ folder -- none of that is optional, the app
; won't start without all of it alongside the executable).
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Only relevant for a first-time install (an in-place update relaunches
; automatically via RestartApplications above, this would just double-open
; it) -- Inno Setup's own postinstall/skipifsilent flags already handle
; that overlap correctly, no extra condition needed here.
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

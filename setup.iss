; ============================================================
; HotKey2026 Inno Setup Install Script
; ============================================================

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppName=HotKey2026
AppVersion={#AppVersion}
AppPublisher=HotKey2026
DefaultDirName={autopf}\HotKey2026
DefaultGroupName=HotKey2026
OutputDir=.\dist
OutputBaseFilename=HotKey2026_Setup_v{#AppVersion}
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
AllowNoIcons=yes
UninstallDisplayName=HotKey2026
Uninstallable=yes
CreateUninstallRegKey=yes

[Tasks]
Name: "desktopicon"; Description: "Create Desktop Shortcut"; GroupDescription: "Options:"
Name: "autostart"; Description: "Start with Windows"; GroupDescription: "Options:"

[Files]
Source: "dist\HotKey2026-02-04.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "config\config.ini"; DestDir: "{app}\config"; Flags: ignoreversion onlyifdoesntexist
Source: "config\credentials.ini"; DestDir: "{app}\config"; Flags: ignoreversion onlyifdoesntexist
Source: "config\credentials_rongyiban.ini"; DestDir: "{app}\config"; Flags: ignoreversion onlyifdoesntexist

[Icons]
Name: "{group}\HotKey2026"; Filename: "{app}\HotKey2026-02-04.exe"
Name: "{group}\Uninstall HotKey2026"; Filename: "{uninstallexe}"
Name: "{userdesktop}\HotKey2026"; Filename: "{app}\HotKey2026-02-04.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "HotKey2026"; ValueData: """{app}\HotKey2026-02-04.exe"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\HotKey2026-02-04.exe"; Description: "Run HotKey2026"; Flags: nowait postinstall skipifsilent
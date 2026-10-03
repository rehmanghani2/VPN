; Inno Setup Packaging Script for Commercial VPN Windows Desktop Client
; Builds standalone installer: Output/AntigravityVPN_Setup.exe

#define MyAppName "Antigravity VPN"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Antigravity Security Inc."
#define MyAppURL "https://vpnplatform.com"
#define MyAppExeName "vpn_client.exe"

[Setup]
AppId={{E68A9F24-B150-4B19-9D6C-77B28B45B321}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE.md
PrivilegesRequired=admin
OutputDir=..\build\windows\installer
OutputBaseFilename=AntigravityVPN_Installer_x64
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Launch Antigravity VPN automatically on Windows startup"; GroupDescription: "Startup Settings:"; Flags: checkedonce

[Files]
; Release Flutter Windows Binary Bundle
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Elevated Background Windows Service for Wintun IPC (runs as SYSTEM)
Source: "..\..\windows-service\bin\Debug\net9.0-windows\*"; DestDir: "{app}\service"; Flags: ignoreversion recursesubdirs createallsubdirs
; Wintun high-performance kernel TUN driver (64-bit)
Source: "..\windows\wintun\wintun.dll"; DestDir: "{app}\service"; Flags: ignoreversion

[Run]
; Install and start privileged Windows Service on install
Filename: "{sys}\sc.exe"; Parameters: "create AntigravityVpnTunnelService binPath=""{app}\service\AntigravityVpnService.exe"" start=auto"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "start AntigravityVpnTunnelService"; Flags: runhidden
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Stop and remove privileged Windows Service on uninstall
Filename: "{sys}\sc.exe"; Parameters: "stop AntigravityVpnTunnelService"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "delete AntigravityVpnTunnelService"; Flags: runhidden

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Configure startup auto-launch if task selected
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "AntigravityVPN"; ValueData: """{app}\{#MyAppExeName}"" --minimized"; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

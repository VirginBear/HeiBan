#ifndef SourceDir
  #error SourceDir must be supplied by Package-Installer.ps1
#endif
#ifndef OutputDir
  #error OutputDir must be supplied
#endif
#ifndef AppVersion
  #error AppVersion must be supplied by Package-Installer.ps1
#endif
#ifndef Arch
  #define Arch "x64"
#endif
#define MyAppName "HeiBan 黑板"
[Setup]
AppId={{9F5734A2-9E1F-43DE-8409-C3A6284E5B91}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher=HeiBan Team
AppPublisherURL=https://github.com/VirginBear/HeiBan
DefaultDirName={localappdata}\Programs\HeiBan
DefaultGroupName={#MyAppName}
OutputDir={#OutputDir}
OutputBaseFilename=HeiBan-Setup-{#AppVersion}-{#Arch}
SetupIconFile={#SourceDir}\Assets\AppIcon.ico
UninstallDisplayIcon={app}\HeiBan.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
MinVersion=10.0.17763
ChangesAssociations=yes
#if Arch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
[Languages]
Name: "chinesetraditional"; MessagesFile: "ChineseTraditional.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "fileassociation"; Description: "將 .heiban 文件與黑板關聯"; Flags: unchecked
[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\HeiBan.exe"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\HeiBan.exe"; Tasks: desktopicon
[Registry]
; Windows recognizes the final extension. Do not register .blackboard.json or hijack all .json files.
Root: HKCU; Subkey: "Software\Classes\.heiban\OpenWithProgids"; ValueType: string; ValueName: "HeiBan.Document"; ValueData: ""; Flags: uninsdeletevalue; Tasks: fileassociation
Root: HKCU; Subkey: "Software\Classes\HeiBan.Document"; ValueType: string; ValueName: ""; ValueData: "HeiBan 黑板文件"; Flags: uninsdeletekey; Tasks: fileassociation
Root: HKCU; Subkey: "Software\Classes\HeiBan.Document\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\Assets\AppIcon.ico"; Tasks: fileassociation
Root: HKCU; Subkey: "Software\Classes\HeiBan.Document\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\HeiBan.exe"" ""%1"""; Tasks: fileassociation
[Run]
Filename: "{app}\HeiBan.exe"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
; Keep user-created documents in LocalAppData\HeiBan\Windows on uninstall.

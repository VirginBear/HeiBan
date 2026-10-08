; HeiBan 黑板 — Inno Setup 安裝版腳本
; 生成支援檔案關聯、開始功能表捷徑與右鍵選單之專業安裝檔

#define MyAppName "HeiBan 黑板"
#define MyAppVersion "1.0.1"
#define MyAppPublisher "HeiBan Team"
#define MyAppURL "https://github.com/heiban/heiban"
#define MyAppExeName "HeiBan.exe"

[Setup]
AppId={{9F5734A2-9E1F-43DE-8409-C3A6284E5B91}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\HeiBan
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=..\..\..\LICENSE
OutputDir=..\..\..\dist\windows
OutputBaseFilename=HeiBan-Setup-x64
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest

[Languages]
Name: "chinesetraditional"; MessagesFile: "compiler:Languages\ChineseTraditional.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\bin\Release\net9.0-windows10.0.22621.0\win-x64\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; 關聯 .blackboard.json 檔案格式與右鍵功能表
[Registry]
Root: HKCU; Subkey: "Software\Classes\.blackboard.json"; ValueType: string; ValueName: ""; ValueData: "HeiBan.Document"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\HeiBan.Document"; ValueType: string; ValueName: ""; ValueData: "HeiBan 黑板文件"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\HeiBan.Document\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCU; Subkey: "Software\Classes\HeiBan.Document\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

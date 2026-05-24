; ============================================================
;  4H-Unfolder  --  Inno Setup 6 Script
;  Build: ISCC.exe installer\4H-Unfolder.iss
;
;  AppId GUID  --  DO NOT change across versions.
;  Windows uses this GUID to detect upgrades vs. fresh installs.
; ============================================================

#define AppName       "4H-Unfolder"
#define AppVersion    "0.0.2.G"
#define AppVersionNum "0.0.2.7"
#define AppPublisher  "4H"
#define AppURL        "https://github.com/nghiazer/4H-Unfolder"
#define AppExe        "4H-Unfolder.exe"
#define SourceDir     "..\publish\v0.0.2.G"
#define OutputDir     "..\dist"
#define IconFile      "..\src\FourHUnfolder.App\Assets\app.ico"

[Setup]
AppId={{BC77D099-D014-4D15-86EB-B0012D4F3267}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutputDir}
OutputBaseFilename=4H-Unfolder-Setup-v{#AppVersion}
SetupIconFile={#IconFile}
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
WizardStyle=modern
DisableProgramGroupPage=yes
CloseApplications=yes
CloseApplicationsFilter=*{#AppExe}*
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName} {#AppVersion}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
VersionInfoVersion={#AppVersionNum}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersionNum}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Setup

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "{#SourceDir}\assimp.dll";                    DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\D3DCompiler_47_cor3.dll";       DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\PenImc_cor3.dll";               DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\PresentationNative_cor3.dll";   DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\vcruntime140_cor3.dll";         DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\wpfgfx_cor3.dll";               DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\{#AppExe}";                     DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}";           Filename: "{app}\{#AppExe}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";     Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch {#AppName} {#AppVersion}"; Flags: nowait postinstall skipifsilent

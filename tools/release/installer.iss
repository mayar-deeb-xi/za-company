; The Windows installer for THE NEW HIRE, built by .github/workflows/release.yml
; out of the "Windows Desktop" export (the exe with its pack embedded, and the
; WebRTC library beside it):
;
;   iscc /DAppVersion=0.2.0 /DFileVersion=0.2.0 /DSourceDir=<export folder>
;        /DOutputDir=<dist> tools\release\installer.iss
;
; It installs per user by default - no administrator prompt, the way a game
; from the internet is expected to behave - and offers all users as a choice.
;
; It is also how the game updates itself (ui/update/update_install_windows.gd):
; the game runs a newer setup with /SILENT ... /RELAUNCH=1 and quits. Setup
; then upgrades in place under the same AppId, in the same install mode as
; before (UsePreviousPrivileges, on by default), and /RELAUNCH=1 - ours, read
; in [Code] below - starts the new version when it is done.
;
; Unsigned, so Windows SmartScreen warns on first run ("More info" -> "Run
; anyway"); signing is RELEASING.md's "Later: signing".

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef FileVersion
  #define FileVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\dist"
#endif

#define AppName "The New Hire"
#define AppExe "TheNewHire.exe"
#define Repo "https://github.com/mayar4ki/za-company"

[Setup]
; Fixed forever. It is how a new version finds the old one and upgrades it in
; place instead of installing a second copy beside it.
AppId={{67FAA5DB-86F1-4D4A-AFDD-EA7F55ED67E3}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=mayar4ki
AppPublisherURL={#Repo}
AppSupportURL={#Repo}/issues
AppUpdatesURL={#Repo}/releases
VersionInfoVersion={#FileVersion}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#AppExe}
; The game quits as it starts an update, but may not be gone the instant Setup
; reaches its files: close it rather than fail to overwrite a running exe.
CloseApplications=yes
OutputDir={#OutputDir}
OutputBaseFilename=TheNewHire-{#AppVersion}-windows-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; An ordinary install: the "Launch" box on the last page.
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
; An update started from inside the game: start it again, silently.
Filename: "{app}\{#AppExe}"; Flags: nowait runasoriginaluser; Check: ShouldRelaunch

[Code]
function ShouldRelaunch: Boolean;
begin
  Result := ExpandConstant('{param:RELAUNCH|0}') = '1';
end;

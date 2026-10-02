; The Windows installer for THE NEW HIRE, built by .github/workflows/release.yml
; out of the "Windows Desktop" export (the exe with its pack embedded, and the
; WebRTC library beside it):
;
;   iscc /DAppVersion=0.2.0 /DFileVersion=0.2.0 /DSourceDir=<export folder>
;        /DOutputDir=<dist> [/DDev] tools\release\installer.iss
;
; /DDev is a deploy to dev's build (RELEASING.md, Deploying to dev): "The New
; Hire (dev)" under an AppId of its own, so it installs BESIDE the game rather
; than over it, in its own folder, with its own Start Menu entry and uninstaller.
; The exe inside it is already renamed and keeps its settings apart
; (tools/release/prepare.sh); this is the installer's half of the same thing.
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

; Both AppIds are fixed forever. One is how a new version finds the old one and
; upgrades it in place instead of installing a second copy beside it; two is how
; a dev build and the game never find each other at all.
#ifdef Dev
  #define AppName "The New Hire (dev)"
  #define AppGuid "{{1F438815-FA66-4FF3-8911-2BC788C7A2E2}"
#else
  #define AppName "The New Hire"
  #define AppGuid "{{67FAA5DB-86F1-4D4A-AFDD-EA7F55ED67E3}"
#endif
#define AppExe "TheNewHire.exe"
#define Repo "https://github.com/mayar4ki/za-company"

[Setup]
AppId={#AppGuid}
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

; Gerado por scripts/build-installer.ps1; exige o diretório de staging.
#ifndef StageDir
  #error Execute scripts/build-installer.ps1 em vez de abrir este arquivo diretamente.
#endif
#ifndef AppVersion
  #define AppVersion "0.4.1"
#endif
#define AppUrl "https://github.com/MicamAmorim/LAN-Cam-OBS"

[Setup]
AppId={{47F17D40-AB98-45E8-B5C7-927C2FA85F82}
AppName=LAN Cam OBS
AppVersion={#AppVersion}
AppPublisher=LAN Cam OBS
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}
DefaultDirName={localappdata}\Programs\LAN Cam OBS
DefaultGroupName=LAN Cam OBS
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName=LAN Cam OBS
OutputBaseFilename=LAN-Cam-OBS-Setup-{#AppVersion}-win-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}
VersionInfoDescription=LAN Cam OBS
SetupIconFile={#StageDir}\assets\lan-cam.ico
UninstallDisplayIcon={app}\assets\lan-cam.ico

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na area de trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked

[Files]
Source: "{#StageDir}\scripts\stop-installed.ps1"; DestName: "upgrade-stop.ps1"; Flags: dontcopy
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\LAN Cam OBS"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\scripts\launch-installed.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\assets\lan-cam.ico"
Name: "{autodesktop}\LAN Cam OBS"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\scripts\launch-installed.ps1"""; WorkingDir: "{app}"; Tasks: desktopicon; IconFilename: "{app}\assets\lan-cam.ico"

[InstallDelete]
Type: files; Name: "{autoprograms}\LAN Cam OBS - Configurar Wi-Fi HTTPS.lnk"
Type: files; Name: "{autoprograms}\LAN Cam OBS - Encerrar servidor.lnk"
Type: files; Name: "{autoprograms}\LAN Cam OBS - Instalar webcam virtual.lnk"
Type: files; Name: "{autoprograms}\LAN Cam OBS - Remover webcam virtual.lnk"

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\scripts\launch-installed.ps1"""; Description: "Abrir LAN Cam OBS"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\stop-installed.ps1"""; RunOnceId: "StopLanCam"; Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{app}\.local"
Type: filesandordirs; Name: "{app}\certs"

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  StopScript: String;
  ExitCode: Integer;
begin
  Result := '';
  ExtractTemporaryFile('upgrade-stop.ps1');
  StopScript := ExpandConstant('{tmp}\upgrade-stop.ps1');
  if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -ExecutionPolicy Bypass -File "' + StopScript + '" -InstallRoot "' + ExpandConstant('{app}') + '"',
    ExpandConstant('{tmp}'), SW_HIDE, ewWaitUntilTerminated, ExitCode) then
    Result := 'Nao foi possivel encerrar o LAN Cam OBS. Feche o aplicativo e tente novamente.'
  else if ExitCode <> 0 then
    Result := 'O runtime do LAN Cam OBS continua em uso. Feche o aplicativo e tente novamente.';
end;

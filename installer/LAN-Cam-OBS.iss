; Gerado por scripts/build-installer.ps1; exige o diretório de staging.
#ifndef StageDir
  #error Execute scripts/build-installer.ps1 em vez de abrir este arquivo diretamente.
#endif
#ifndef AppVersion
  #define AppVersion "0.2.0"
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
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\LAN Cam OBS"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\scripts\launch-installed.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\assets\lan-cam.ico"
Name: "{autoprograms}\LAN Cam OBS - Configurar Wi-Fi HTTPS"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -NoExit -File ""{app}\scripts\configure-wifi.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\assets\lan-cam.ico"
Name: "{autoprograms}\LAN Cam OBS - Encerrar servidor"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\scripts\stop-installed.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\assets\lan-cam.ico"
Name: "{autodesktop}\LAN Cam OBS"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\scripts\launch-installed.ps1"""; WorkingDir: "{app}"; Tasks: desktopicon; IconFilename: "{app}\assets\lan-cam.ico"
Name: "{autoprograms}\LAN Cam OBS - Instalar webcam virtual"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\install-webcam-driver.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\assets\lan-cam.ico"
Name: "{autoprograms}\LAN Cam OBS - Remover webcam virtual"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\install-webcam-driver.ps1"" -Remove"; WorkingDir: "{app}"; IconFilename: "{app}\assets\lan-cam.ico"

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\scripts\launch-installed.ps1"""; Description: "Abrir LAN Cam OBS"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\stop-installed.ps1"""; Flags: runhidden waituntilterminated

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
  StopScript := ExpandConstant('{app}\scripts\stop-installed.ps1');
  if FileExists(StopScript) then
  begin
    if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
      '-NoProfile -ExecutionPolicy Bypass -File "' + StopScript + '"',
      ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ExitCode) then
      Log('Aviso: nao foi possivel parar a instalacao anterior.');
  end;
end;

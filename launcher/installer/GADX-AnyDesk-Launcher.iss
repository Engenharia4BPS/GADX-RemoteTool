#define AppName "GADX AnyDesk Launcher"
#define AppVersion "1.1.0"
#define AppPublisher "Araucária DX Group"
#define AppDir "C:\Suporte\AnyDesk-GADX"

[Setup]
AppId={{A63EC2D8-4D15-4F44-9DE1-AC8F6A7A5D58}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={#AppDir}
DefaultGroupName=GADX
DisableProgramGroupPage=yes
OutputDir=..\Output
OutputBaseFilename=GADX-AnyDesk-Launcher-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
SetupIconFile=..\assets\AnyDesk-GADX-Launcher.ico
UninstallDisplayIcon={app}\AnyDesk-GADX-Launcher.ico
ArchitecturesInstallIn64BitMode=x64
UsePreviousAppDir=no
LicenseFile=ULA-GADX-AnyDesk.rtf

[Files]
Source: "..\src\AnyDesk-GADX-Launcher.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\Abrir-AnyDesk-GADX.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\AnyDesk-GADX-Launcher.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\config\maquinas-template.csv"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\client\anydesk-GADX.exe"; DestDir: "{app}\Client"; Flags: ignoreversion

[Icons]
Name: "{autodesktop}\Anydesk GADX"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Abrir-AnyDesk-GADX.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\AnyDesk-GADX-Launcher.ico"
Name: "{group}\Anydesk GADX"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Abrir-AnyDesk-GADX.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\AnyDesk-GADX-Launcher.ico"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if not FileExists(ExpandConstant('{app}\maquinas.csv')) then
    begin
      FileCopy(
        ExpandConstant('{app}\maquinas-template.csv'),
        ExpandConstant('{app}\maquinas.csv'),
        False
      );
    end;
  end;
end;

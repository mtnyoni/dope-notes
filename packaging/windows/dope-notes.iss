#ifndef AppVersion
  #define AppVersion "0.0.1"
#endif
#define ProjectRoot SourcePath + "..\.."
#define AppFiles ProjectRoot + "\build\windows"

[Setup]
AppId={{4B00A3D7-4B79-4E02-8E10-A76626B74BF2}
AppName=Dope Notes
AppVersion={#AppVersion}
AppPublisher=mtnyoni
AppPublisherURL=https://github.com/mtnyoni/dope-notes
DefaultDirName={localappdata}\Programs\Dope Notes
DefaultGroupName=Dope Notes
PrivilegesRequired=lowest
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#ProjectRoot}\build\installer
OutputBaseFilename=dope-notes-{#AppVersion}-windows-x64-setup
LicenseFile={#ProjectRoot}\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\dope-notes.exe
CloseApplications=yes
SetupLogging=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "{#AppFiles}\dope-notes.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppFiles}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppFiles}\assets\icons\*.png"; DestDir: "{app}\assets\icons"; Flags: ignoreversion
Source: "{#AppFiles}\font\Roboto-Regular.ttf"; DestDir: "{app}\font"; Flags: ignoreversion
Source: "{#AppFiles}\packaging\icons\dope-notes.png"; DestDir: "{app}\packaging\icons"; Flags: ignoreversion
Source: "{#ProjectRoot}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Dope Notes"; Filename: "{app}\dope-notes.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Dope Notes"; Filename: "{app}\dope-notes.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\dope-notes.exe"; Description: "Launch Dope Notes"; Flags: nowait postinstall skipifsilent

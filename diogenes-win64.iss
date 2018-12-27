; -- diogenes-win32.iss --
; Same as Example1.iss, but creates its icon in the Programs folder of the
; Start Menu instead of in a subfolder, and also creates a desktop icon.

; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!

[Setup]
AppName=Diogenes
AppVerName=Diogenes version 4
DefaultDirName={pf}\Diogenes\
; since no icons will be created in "{group}", we don't need the install wizard
; to ask for a group name.
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\diogenes.ico
; since there may be a config file there
DirExistsWarning=no

[Files]
Source: "w64\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{commonprograms}\Diogenes"; Filename: "{app}\diogenes.exe"; IconFilename:{app}\diogenes.ico
Name: "{userdesktop}\Diogenes"; Filename: "{app}\diogenes.exe"; IconFilename:{app}\diogenes.ico
Name: "{app}\windows\Diogenes"; Filename: "{app}\diogenes.exe"; IconFilename:{app}\diogenes.ico


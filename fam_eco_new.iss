; ========================================
; Οικογενειακός Προϋπολογισμός - Professional Installer
; ========================================

[Setup]
AppId={{D7C3F8A1-2B44-4C7A-9F9E-8A5D11223344}
AppName=Οικογενειακός Προϋπολογισμός
AppVersion=1.0.0
AppPublisher=Aris Gavrielatos
AppPublisherURL=https://www.example.com
AppSupportURL=https://www.example.com/support
AppUpdatesURL=https://www.example.com/updates
AppContact=support@example.com

; Εμποδίζει την εγκατάσταση αν η εφαρμογή είναι ανοιχτή
AppMutex=FamilyEconomy_Flutter_Mutex
CloseApplications=yes

; Install location (no admin required)
DefaultDirName={localappdata}\f_budget
DefaultGroupName=Οικογενειακός Προϋπολογισμός
UsePreviousAppDir=yes
DisableProgramGroupPage=no
AllowNoIcons=yes

; Output
OutputDir=.\InstallerOutput
OutputBaseFilename=FamilyBudgetSetup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=C:\Users\Vaggelis\Flutter Projects\family_economy\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\family_economy.exe

; Permissions
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "greek"; MessagesFile: "Greek.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Δημιουργία συντόμευσης στην Επιφάνεια Εργασίας"; GroupDescription: "Additional shortcuts:"; Flags: checkedonce

[Files]
; Η εφαρμογή (Release build)
Source: "C:\Users\Vaggelis\Flutter Projects\family_economy\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Το VC++ Redistributable
Source: "C:\Users\Vaggelis\Flutter Projects\family_economy\Dependencies\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Dirs]
Name: "{app}"; Permissions: users-full
Name: "{app}\data"; Permissions: users-full
Name: "{userappdata}\f_budget"; Permissions: users-full

[Icons]
Name: "{group}\Οικογενειακός Προϋπολογισμός"; Filename: "{app}\family_economy.exe"; WorkingDir: "{app}"; Comment: "Οικογενειακός Προϋπολογισμός"
Name: "{group}\Απεγκατάσταση"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Οικογενειακός Προϋπολογισμός"; Filename: "{app}\family_economy.exe"; WorkingDir: "{app}"; Tasks: desktopicon; Comment: "Οικογενειακός Προϋπολογισμός"

[Run]
; Εγκατάσταση του VC Redist αν λείπει (Silent install)
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Check: VCRedistNeedsInstall; StatusMsg: "Εγκατάσταση απαραίτητων στοιχείων συστήματος (Visual C++)..."
; Εκκίνηση εφαρμογής μετά το setup
Filename: "{app}\family_economy.exe"; Description: "Εκκίνηση Οικογενειακός Προϋπολογισμός"; Flags: nowait postinstall skipifsilent; WorkingDir: "{app}"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{userappdata}\f_budget"
Type: filesandordirs; Name: "{localappdata}\f_budget"

[Code]
var
  DeleteUserData: Boolean;

// Έλεγχος αν το VC++ Redistributable είναι ήδη εγκατεστημένο
function VCRedistNeedsInstall(): Boolean;
var
  Version: String;
begin
  Result := not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Version', Version);
end;

procedure InitializeWizard();
begin
  if GetWindowsVersion < $0A000000 then
  begin
    MsgBox('Αυτό το πρόγραμμα απαιτεί Windows 10 ή νεότερα.', mbError, MB_OK);
    Abort();
  end;

  if not IsWin64 then
  begin
    MsgBox('Η εφαρμογή λειτουργεί μόνο σε 64-bit Windows.', mbError, MB_OK);
    Abort();
  end;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
  if MsgBox('Επιθυμείτε να διαγραφούν ΟΛΑ τα δεδομένα της εφαρμογής (βάση δεδομένων, ρυθμίσεις);', 
    mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
    DeleteUserData := True
  else
    DeleteUserData := False;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppDataPath, LocalAppDataPath: string;
begin
  if (CurUninstallStep = usPostUninstall) and DeleteUserData then
  begin
    AppDataPath := ExpandConstant('{userappdata}\f_budget');
    if DirExists(AppDataPath) then DelTree(AppDataPath, True, True, True);

    LocalAppDataPath := ExpandConstant('{localappdata}\f_budget');
    if DirExists(LocalAppDataPath) then DelTree(LocalAppDataPath, True, True, True);
    
    MsgBox('Τα δεδομένα χρήστη διαγράφηκαν.', mbInformation, MB_OK);
  end;
end;
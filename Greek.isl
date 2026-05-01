; *** Inno Setup version 6.0.0+ Greek messages ***
;
; To download user-contributed translations of this file, go to:
;   https://jrsoftware.org/files/istrans/
;
; Note: When translating this text, do not add periods (.) to the end of
; messages that didn't have them already, because on those messages Inno
; Setup adds the periods automatically (appending a period would result in
; two periods being displayed).

[LangOptions]
LanguageName=Greek
LanguageID=$0408
LanguageCodePage=1253

[Messages]

; *** Application titles
SetupAppTitle=Εγκατάσταση
SetupWindowTitle=Εγκατάσταση - %1
UninstallAppTitle=Απεγκατάσταση
UninstallAppFullTitle=%1 Απεγκατάσταση

; *** Misc. common
InformationTitle=Πληροφορίες
ConfirmTitle=Επιβεβαίωση
ErrorTitle=Σφάλμα

; *** SetupLdr messages
SetupLdrStartupMessage=Αυτό θα εγκαταστήσει το %1. Θέλετε να συνεχίσετε;
LdrCannotCreateTemp=Δεν είναι δυνατή η δημιουργία προσωρινού αρχείου. Η εγκατάσταση ματαιώθηκε
LdrCannotExecTemp=Δεν είναι δυνατή η εκτέλεση αρχείου στον προσωρινό κατάλογο. Η εγκατάσταση ματαιώθηκε
HelpTextNote=

; *** Startup error messages
LastErrorMessage=%1.%n%nΣφάλμα %2: %3
SetupFileMissing=Το αρχείο %1 λείπει από τον κατάλογο εγκατάστασης. Παρακαλώ διορθώστε το πρόβλημα ή αποκτήστε ένα νέο αντίγραφο του προγράμματος.
SetupFileCorrupt=Τα αρχεία εγκατάστασης είναι κατεστραμμένα. Παρακαλώ αποκτήστε ένα νέο αντίγραφο του προγράμματος.
SetupFileCorruptOrWrongVer=Τα αρχεία εγκατάστασης είναι κατεστραμμένα ή είναι ασύμβατα με αυτήν την έκδοση του προγράμματος εγκατάστασης. Παρακαλώ διορθώστε το πρόβλημα ή αποκτήστε ένα νέο αντίγραφο του προγράμματος.
InvalidParameter=Μια μη έγκυρη παράμετρος πέρασε στη γραμμή εντολών:%n%n%1
SetupAlreadyRunning=Το πρόγραμμα εγκατάστασης εκτελείται ήδη.
WindowsVersionNotSupported=Αυτό το πρόγραμμα δεν υποστηρίζει την έκδοση των Windows που εκτελείται στον υπολογιστή σας.
WindowsServicePackRequired=Αυτό το πρόγραμμα απαιτεί %1 Service Pack %2 ή νεότερο.
NotOnThisPlatform=Αυτό το πρόγραμμα δεν θα τρέξει σε %1.
OnlyOnThisPlatform=Αυτό το πρόγραμμα πρέπει να τρέξει σε %1.
OnlyOnTheseArchitectures=Αυτό το πρόγραμμα μπορεί να εγκατασταθεί μόνο σε εκδόσεις των Windows σχεδιασμένες για τις ακόλουθες αρχιτεκτονικές επεξεργαστή:%n%n%1
WinVersionTooLowError=Αυτό το πρόγραμμα απαιτεί %1 έκδοση %2 ή νεότερη.
WinVersionTooHighError=Αυτό το πρόγραμμα δεν μπορεί να εγκατασταθεί σε %1 έκδοση %2 ή νεότερη.
AdminPrivilegesRequired=Πρέπει να συνδεθείτε ως διαχειριστής κατά την εγκατάσταση αυτού του προγράμματος.
PowerUserPrivilegesRequired=Πρέπει να συνδεθείτε ως διαχειριστής ή ως μέλος της ομάδας Power Users κατά την εγκατάσταση αυτού του προγράμματος.
SetupAppRunningError=Το πρόγραμμα εγκατάστασης εντόπισε ότι το %1 εκτελείται αυτή τη στιγμή.%n%nΠαρακαλώ κλείστε όλα τα παράθυρά του τώρα, στη συνέχεια κάντε κλικ στο OK για να συνεχίσετε ή στο Άκυρο για έξοδο.
UninstallAppRunningError=Η απεγκατάσταση εντόπισε ότι το %1 εκτελείται αυτή τη στιγμή.%n%nΠαρακαλώ κλείστε όλα τα παράθυρά του τώρα, στη συνέχεια κάντε κλικ στο OK για να συνεχίσετε ή στο Άκυρο για έξοδο.

; *** Startup questions
PrivilegesRequiredOverrideTitle=Επιλογή λειτουργίας εγκατάστασης
PrivilegesRequiredOverrideInstruction=Επιλέξτε λειτουργία εγκατάστασης
PrivilegesRequiredOverrideText1=Το %1 μπορεί να εγκατασταθεί για όλους τους χρήστες (απαιτούνται δικαιώματα διαχειριστή), ή μόνο για εσάς.
PrivilegesRequiredOverrideText2=Το %1 μπορεί να εγκατασταθεί μόνο για εσάς, ή για όλους τους χρήστες (απαιτούνται δικαιώματα διαχειριστή).
PrivilegesRequiredOverrideAllUsers=Εγκατάσταση για &όλους τους χρήστες
PrivilegesRequiredOverrideAllUsersRecommended=Εγκατάσταση για &όλους τους χρήστες (συνιστάται)
PrivilegesRequiredOverrideCurrentUser=Εγκατάσταση μόνο για &εμένα
PrivilegesRequiredOverrideCurrentUserRecommended=Εγκατάσταση μόνο για &εμένα (συνιστάται)

; *** Misc. errors
ErrorCreatingDir=Το πρόγραμμα εγκατάστασης δεν μπόρεσε να δημιουργήσει τον κατάλογο "%1"
ErrorTooManyFilesInDir=Δεν είναι δυνατή η δημιουργία ενός αρχείου στον κατάλογο "%1" επειδή περιέχει πάρα πολλά αρχεία

; *** Setup common messages
ExitSetupTitle=Έξοδος από την εγκατάσταση
ExitSetupMessage=Η εγκατάσταση δεν έχει ολοκληρωθεί. Αν βγείτε τώρα, το πρόγραμμα δεν θα εγκατασταθεί.%n%nΜπορείτε να εκτελέσετε το πρόγραμμα εγκατάστασης ξανά αργότερα για να ολοκληρώσετε την εγκατάσταση.%n%nΈξοδος από την εγκατάσταση;
AboutSetupMenuItem=&Σχετικά με την εγκατάσταση...
AboutSetupTitle=Σχετικά με την εγκατάσταση
AboutSetupMessage=%1 έκδοση %2%n%3%n%n%1 αρχική σελίδα:%n%4
AboutSetupNote=
TranslatorNote=

; *** Buttons
ButtonBack=< &Πίσω
ButtonNext=&Επόμενο >
ButtonInstall=&Εγκατάσταση
ButtonOK=OK
ButtonCancel=Άκυρο
ButtonYes=&Ναι
ButtonYesToAll=Ναι σε &Όλα
ButtonNo=&Όχι
ButtonNoToAll=Ό&χι σε Όλα
ButtonFinish=&Τέλος
ButtonBrowse=&Αναζήτηση...
ButtonWizardBrowse=Α&ναζήτηση...
ButtonNewFolder=&Δημιουργία νέου φακέλου

; *** "Select Language" dialog messages
SelectLanguageTitle=Επιλογή γλώσσας εγκατάστασης
SelectLanguageLabel=Επιλέξτε τη γλώσσα που θα χρησιμοποιηθεί κατά την εγκατάσταση.

; *** Common wizard text
ClickNext=Κάντε κλικ στο Επόμενο για να συνεχίσετε ή στο Άκυρο για έξοδο από την εγκατάσταση.
BeveledLabel=
BrowseDialogTitle=Αναζήτηση φακέλου
BrowseDialogLabel=Επιλέξτε ένα φάκελο από την παρακάτω λίστα και στη συνέχεια κάντε κλικ στο OK.
NewFolderName=Νέος φάκελος

; *** "Welcome" wizard page
WelcomeLabel1=Καλώς ήλθατε στον Οδηγό Εγκατάστασης του [name]
WelcomeLabel2=Αυτό θα εγκαταστήσει το [name/ver] στον υπολογιστή σας.%n%nΣυνιστάται να κλείσετε όλες τις άλλες εφαρμογές πριν συνεχίσετε.

; *** "Password" wizard page
WizardPassword=Κωδικός πρόσβασης
PasswordLabel1=Αυτή η εγκατάσταση προστατεύεται με κωδικό πρόσβασης.
PasswordLabel3=Παρακαλώ δώστε τον κωδικό πρόσβασης, στη συνέχεια κάντε κλικ στο Επόμενο για να συνεχίσετε. Οι κωδικοί πρόσβασης κάνουν διάκριση πεζών-κεφαλαίων.
PasswordEditLabel=&Κωδικός πρόσβασης:
IncorrectPassword=Ο κωδικός πρόσβασης που εισαγάγατε δεν είναι σωστός. Παρακαλώ δοκιμάστε ξανά.

; *** "License Agreement" wizard page
WizardLicense=Συμφωνία άδειας χρήσης
LicenseLabel=Παρακαλώ διαβάστε τις ακόλουθες σημαντικές πληροφορίες πριν συνεχίσετε.
LicenseLabel3=Παρακαλώ διαβάστε την ακόλουθη Συμφωνία Άδειας Χρήσης. Πρέπει να αποδεχτείτε τους όρους αυτής της συμφωνίας πριν συνεχίσετε με την εγκατάσταση.
LicenseAccepted=&Αποδέχομαι τη συμφωνία
LicenseNotAccepted=&Δεν αποδέχομαι τη συμφωνία

; *** "Information" wizard pages
WizardInfoBefore=Πληροφορίες
InfoBeforeLabel=Παρακαλώ διαβάστε τις ακόλουθες σημαντικές πληροφορίες πριν συνεχίσετε.
InfoBeforeClickLabel=Όταν είστε έτοιμοι να συνεχίσετε με την εγκατάσταση, κάντε κλικ στο Επόμενο.
WizardInfoAfter=Πληροφορίες
InfoAfterLabel=Παρακαλώ διαβάστε τις ακόλουθες σημαντικές πληροφορίες πριν συνεχίσετε.
InfoAfterClickLabel=Όταν είστε έτοιμοι να συνεχίσετε με την εγκατάσταση, κάντε κλικ στο Επόμενο.

; *** "User Information" wizard page
WizardUserInfo=Πληροφορίες χρήστη
UserInfoDesc=Παρακαλώ εισάγετε τις πληροφορίες σας.
UserInfoName=Όνομα &χρήστη:
UserInfoOrg=&Οργανισμός:
UserInfoSerial=&Σειριακός αριθμός:
UserInfoNameRequired=Πρέπει να εισάγετε ένα όνομα.

; *** "Select Destination Location" wizard page
WizardSelectDir=Επιλογή θέσης προορισμού
SelectDirDesc=Πού θέλετε να εγκατασταθεί το [name];
SelectDirLabel3=Το πρόγραμμα εγκατάστασης θα εγκαταστήσει το [name] στον ακόλουθο φάκελο.
SelectDirBrowseLabel=Για να συνεχίσετε, κάντε κλικ στο Επόμενο. Αν θέλετε να επιλέξετε διαφορετικό φάκελο, κάντε κλικ στο Αναζήτηση.
DiskSpaceGBLabel=Απαιτείται τουλάχιστον [gb] GB ελεύθερος χώρος στο δίσκο.
DiskSpaceMBLabel=Απαιτείται τουλάχιστον [mb] MB ελεύθερος χώρος στο δίσκο.
CannotInstallToNetworkDrive=Το πρόγραμμα εγκατάστασης δεν μπορεί να εγκαταστήσει σε μια μονάδα δικτύου.
CannotInstallToUNCPath=Το πρόγραμμα εγκατάστασης δεν μπορεί να εγκαταστήσει σε μια διαδρομή UNC.
InvalidPath=Πρέπει να εισάγετε μια πλήρη διαδρομή με γράμμα μονάδας δίσκου· για παράδειγμα:%n%nC:\APP%n%nή μια διαδρομή UNC της μορφής:%n%n\\server\share
InvalidDrive=Η μονάδα δίσκου ή η κοινόχρηστη θέση UNC που επιλέξατε δεν υπάρχει ή δεν είναι προσβάσιμη. Παρακαλώ επιλέξτε μια άλλη.
DiskSpaceWarningTitle=Δεν υπάρχει αρκετός χώρος στο δίσκο
DiskSpaceWarning=Το πρόγραμμα εγκατάστασης απαιτεί τουλάχιστον %1 KB ελεύθερου χώρου για εγκατάσταση, αλλά η επιλεγμένη μονάδα δίσκου έχει μόνο %2 KB διαθέσιμα.%n%nΘέλετε να συνεχίσετε ούτως ή άλλως;
DirNameTooLong=Το όνομα του φακέλου ή η διαδρομή είναι πολύ μεγάλη.
InvalidDirName=Το όνομα του φακέλου δεν είναι έγκυρο.
BadDirName32=Τα ονόματα φακέλων δεν μπορούν να περιλαμβάνουν οποιονδήποτε από τους ακόλουθους χαρακτήρες:%n%n%1
DirExistsTitle=Ο φάκελος υπάρχει
DirExists=Ο φάκελος:%n%n%1%n%nυπάρχει ήδη. Θέλετε να εγκαταστήσετε σε αυτόν τον φάκελο ούτως ή άλλως;
DirDoesntExistTitle=Ο φάκελος δεν υπάρχει
DirDoesntExist=Ο φάκελος:%n%n%1%n%nδεν υπάρχει. Θέλετε να δημιουργηθεί ο φάκελος;

; *** "Select Components" wizard page
WizardSelectComponents=Επιλογή στοιχείων
SelectComponentsDesc=Ποια στοιχεία πρέπει να εγκατασταθούν;
SelectComponentsLabel2=Επιλέξτε τα στοιχεία που θέλετε να εγκαταστήσετε· καταργήστε την επιλογή των στοιχείων που δεν θέλετε να εγκαταστήσετε. Κάντε κλικ στο Επόμενο όταν είστε έτοιμοι να συνεχίσετε.
FullInstallation=Πλήρης εγκατάσταση
CompactInstallation=Συμπαγής εγκατάσταση
CustomInstallation=Προσαρμοσμένη εγκατάσταση
NoUninstallWarningTitle=Τα στοιχεία υπάρχουν
NoUninstallWarning=Το πρόγραμμα εγκατάστασης εντόπισε ότι τα ακόλουθα στοιχεία είναι ήδη εγκατεστημένα στον υπολογιστή σας:%n%n%1%n%nΗ κατάργηση της επιλογής αυτών των στοιχείων δεν θα τα απεγκαταστήσει.%n%nΘέλετε να συνεχίσετε ούτως ή άλλως;
ComponentSize1=%1 KB
ComponentSize2=%1 MB
ComponentsDiskSpaceGBLabel=Η τρέχουσα επιλογή απαιτεί τουλάχιστον [gb] GB χώρου στο δίσκο.
ComponentsDiskSpaceMBLabel=Η τρέχουσα επιλογή απαιτεί τουλάχιστον [mb] MB χώρου στο δίσκο.

; *** "Select Additional Tasks" wizard page
WizardSelectTasks=Επιλογή πρόσθετων εργασιών
SelectTasksDesc=Ποιες πρόσθετες εργασίες πρέπει να εκτελεστούν;
SelectTasksLabel2=Επιλέξτε τις πρόσθετες εργασίες που θέλετε να εκτελέσει το πρόγραμμα εγκατάστασης κατά την εγκατάσταση του [name], στη συνέχεια κάντε κλικ στο Επόμενο.

; *** "Select Start Menu Folder" wizard page
WizardSelectProgramGroup=Επιλογή φακέλου μενού Έναρξη
SelectStartMenuFolderDesc=Πού πρέπει το πρόγραμμα εγκατάστασης να τοποθετήσει τις συντομεύσεις του προγράμματος;
SelectStartMenuFolderLabel3=Το πρόγραμμα εγκατάστασης θα δημιουργήσει τις συντομεύσεις του προγράμματος στον ακόλουθο φάκελο του μενού Έναρξη.
SelectStartMenuFolderBrowseLabel=Για να συνεχίσετε, κάντε κλικ στο Επόμενο. Αν θέλετε να επιλέξετε διαφορετικό φάκελο, κάντε κλικ στο Αναζήτηση.
MustEnterGroupName=Πρέπει να εισάγετε ένα όνομα φακέλου.
GroupNameTooLong=Το όνομα του φακέλου ή η διαδρομή είναι πολύ μεγάλη.
InvalidGroupName=Το όνομα του φακέλου δεν είναι έγκυρο.
BadGroupName=Το όνομα του φακέλου δεν μπορεί να περιλαμβάνει οποιονδήποτε από τους ακόλουθους χαρακτήρες:%n%n%1
NoProgramGroupCheck2=&Να μην δημιουργηθεί φάκελος μενού Έναρξη

; *** "Ready to Install" wizard page
WizardReady=Έτοιμο για εγκατάσταση
ReadyLabel1=Το πρόγραμμα εγκατάστασης είναι τώρα έτοιμο να ξεκινήσει την εγκατάσταση του [name] στον υπολογιστή σας.
ReadyLabel2a=Κάντε κλικ στο Εγκατάσταση για να συνεχίσετε με την εγκατάσταση ή κάντε κλικ στο Πίσω αν θέλετε να ελέγξετε ή να αλλάξετε κάποιες ρυθμίσεις.
ReadyLabel2b=Κάντε κλικ στο Εγκατάσταση για να συνεχίσετε με την εγκατάσταση.
ReadyMemoUserInfo=Πληροφορίες χρήστη:
ReadyMemoDir=Θέση προορισμού:
ReadyMemoType=Τύπος εγκατάστασης:
ReadyMemoComponents=Επιλεγμένα στοιχεία:
ReadyMemoGroup=Φάκελος μενού Έναρξη:
ReadyMemoTasks=Πρόσθετες εργασίες:

; *** TDownloadWizardPage wizard page and DownloadTemporaryFile
DownloadingLabel=Λήψη πρόσθετων αρχείων...
ButtonStopDownload=&Διακοπή λήψης
StopDownload=Είστε βέβαιοι ότι θέλετε να σταματήσετε τη λήψη;
ErrorDownloadAborted=Η λήψη ματαιώθηκε
ErrorDownloadFailed=Αποτυχία λήψης: %1 %2
ErrorDownloadSizeFailed=Αποτυχία λήψης μεγέθους: %1 %2
ErrorFileHash1=Αποτυχία κατακερματισμού αρχείου: %1
ErrorFileHash2=Μη έγκυρος κατακερματισμός αρχείου: αναμενόμενο %1, βρέθηκε %2
ErrorProgress=Μη έγκυρη πρόοδος: %1 από %2
ErrorFileSize=Μη έγκυρο μέγεθος αρχείου: αναμενόμενο %1, βρέθηκε %2

; *** "Preparing to Install" wizard page
WizardPreparing=Προετοιμασία για εγκατάσταση
PreparingDesc=Το πρόγραμμα εγκατάστασης προετοιμάζεται να εγκαταστήσει το [name] στον υπολογιστή σας.
PreviousInstallNotCompleted=Η εγκατάσταση/απεγκατάσταση ενός προηγούμενου προγράμματος δεν έχει ολοκληρωθεί. Θα χρειαστεί να επανεκκινήσετε τον υπολογιστή σας για να ολοκληρωθεί αυτή η εγκατάσταση.%n%nΜετά την επανεκκίνηση του υπολογιστή σας, εκτελέστε ξανά το πρόγραμμα εγκατάστασης για να ολοκληρώσετε την εγκατάσταση του [name].
CannotContinue=Το πρόγραμμα εγκατάστασης δεν μπορεί να συνεχίσει. Παρακαλώ κάντε κλικ στο Άκυρο για έξοδο.
ApplicationsFound=Οι ακόλουθες εφαρμογές χρησιμοποιούν αρχεία που πρέπει να ενημερωθούν από το πρόγραμμα εγκατάστασης. Συνιστάται να επιτρέψετε στο πρόγραμμα εγκατάστασης να κλείσει αυτόματα αυτές τις εφαρμογές.
ApplicationsFound2=Οι ακόλουθες εφαρμογές χρησιμοποιούν αρχεία που πρέπει να ενημερωθούν από το πρόγραμμα εγκατάστασης. Συνιστάται να επιτρέψετε στο πρόγραμμα εγκατάστασης να κλείσει αυτόματα αυτές τις εφαρμογές. Μετά την ολοκλήρωση της εγκατάστασης, το πρόγραμμα εγκατάστασης θα προσπαθήσει να επανεκκινήσει τις εφαρμογές.
CloseApplications=&Αυτόματο κλείσιμο των εφαρμογών
DontCloseApplications=&Να μην κλείσουν οι εφαρμογές
ErrorCloseApplications=Το πρόγραμμα εγκατάστασης δεν μπόρεσε να κλείσει αυτόματα όλες τις εφαρμογές. Συνιστάται να κλείσετε όλες τις εφαρμογές που χρησιμοποιούν αρχεία που πρέπει να ενημερωθούν από το πρόγραμμα εγκατάστασης πριν συνεχίσετε.
PrepareToInstallNeedsRestart=Το πρόγραμμα εγκατάστασης πρέπει να επανεκκινήσει τον υπολογιστή σας. Μετά την επανεκκίνηση του υπολογιστή σας, εκτελέστε ξανά το πρόγραμμα εγκατάστασης για να ολοκληρώσετε την εγκατάσταση του [name].%n%nΘέλετε να επανεκκινήσετε τώρα;

; *** "Installing" wizard page
WizardInstalling=Εγκατάσταση
InstallingLabel=Παρακαλώ περιμένετε όσο το πρόγραμμα εγκατάστασης εγκαθιστά το [name] στον υπολογιστή σας.

; *** "Setup Completed" wizard page
FinishedHeadingLabel=Ολοκλήρωση του Οδηγού Εγκατάστασης του [name]
FinishedLabelNoIcons=Το πρόγραμμα εγκατάστασης ολοκλήρωσε την εγκατάσταση του [name] στον υπολογιστή σας.
FinishedLabel=Το πρόγραμμα εγκατάστασης ολοκλήρωσε την εγκατάσταση του [name] στον υπολογιστή σας. Η εφαρμογή μπορεί να ξεκινήσει επιλέγοντας τα εγκατεστημένα εικονίδια.
ClickFinish=Κάντε κλικ στο Τέλος για έξοδο από το πρόγραμμα εγκατάστασης.
FinishedRestartLabel=Για να ολοκληρωθεί η εγκατάσταση του [name], το πρόγραμμα εγκατάστασης πρέπει να επανεκκινήσει τον υπολογιστή σας. Θέλετε να επανεκκινήσετε τώρα;
FinishedRestartMessage=Για να ολοκληρωθεί η εγκατάσταση του [name], το πρόγραμμα εγκατάστασης πρέπει να επανεκκινήσει τον υπολογιστή σας.%n%nΘέλετε να επανεκκινήσετε τώρα;
ShowReadmeCheck=Ναι, θέλω να δω το αρχείο README
YesRadio=&Ναι, επανεκκίνηση του υπολογιστή τώρα
NoRadio=&Όχι, θα επανεκκινήσω τον υπολογιστή αργότερα
RunEntryExec=Εκτέλεση %1
RunEntryShellExec=Προβολή %1

; *** "Setup Needs the Next Disk" stuff
ChangeDiskTitle=Το πρόγραμμα εγκατάστασης χρειάζεται τον επόμενο δίσκο
SelectDiskLabel2=Παρακαλώ εισάγετε τον Δίσκο %1 και κάντε κλικ στο OK.%n%nΑν τα αρχεία σε αυτόν τον δίσκο βρίσκονται σε φάκελο διαφορετικό από αυτόν που εμφανίζεται παρακάτω, εισάγετε τη σωστή διαδρομή ή κάντε κλικ στο Αναζήτηση.
PathLabel=&Διαδρομή:
FileNotInDir2=Το αρχείο "%1" δεν βρέθηκε στο "%2". Παρακαλώ εισάγετε τον σωστό δίσκο ή επιλέξτε έναν άλλο φάκελο.
SelectDirectoryLabel=Παρακαλώ καθορίστε τη θέση του επόμενου δίσκου.

; *** Installation phase messages
SetupAborted=Η εγκατάσταση δεν ολοκληρώθηκε.%n%nΠαρακαλώ διορθώστε το πρόβλημα και εκτελέστε ξανά το πρόγραμμα εγκατάστασης.
AbortRetryIgnoreSelectAction=Επιλέξτε ενέργεια
AbortRetryIgnoreRetry=&Δοκιμάστε ξανά
AbortRetryIgnoreIgnore=&Αγνοήστε το σφάλμα και συνεχίστε
AbortRetryIgnoreCancel=Ακύρωση εγκατάστασης

; *** Installation status messages
StatusClosingApplications=Κλείσιμο εφαρμογών...
StatusCreateDirs=Δημιουργία καταλόγων...
StatusExtractFiles=Εξαγωγή αρχείων...
StatusCreateIcons=Δημιουργία συντομεύσεων...
StatusCreateIniEntries=Δημιουργία καταχωρίσεων INI...
StatusCreateRegistryEntries=Δημιουργία καταχωρίσεων μητρώου...
StatusRegisterFiles=Καταχώριση αρχείων...
StatusSavingUninstall=Αποθήκευση πληροφοριών απεγκατάστασης...
StatusRunProgram=Ολοκλήρωση εγκατάστασης...
StatusRestartingApplications=Επανεκκίνηση εφαρμογών...
StatusRollback=Επαναφορά αλλαγών...

; *** Misc. errors
ErrorInternal2=Εσωτερικό σφάλμα: %1
ErrorFunctionFailedNoCode=%1 απέτυχε
ErrorFunctionFailed=%1 απέτυχε· κωδικός %2
ErrorFunctionFailedWithMessage=%1 απέτυχε· κωδικός %2.%n%3
ErrorExecutingProgram=Δεν είναι δυνατή η εκτέλεση του αρχείου:%n%1

; *** Registry errors
ErrorRegOpenKey=Σφάλμα ανοίγματος κλειδιού μητρώου:%n%1\%2
ErrorRegCreateKey=Σφάλμα δημιουργίας κλειδιού μητρώου:%n%1\%2
ErrorRegWriteKey=Σφάλμα εγγραφής σε κλειδί μητρώου:%n%1\%2

; *** INI errors
ErrorIniEntry=Σφάλμα δημιουργίας καταχώρισης INI στο αρχείο "%1".

; *** File copying errors
FileAbortRetryIgnoreSkipNotRecommended=&Παράλειψη αυτού του αρχείου (δεν συνιστάται)
FileAbortRetryIgnoreIgnoreNotRecommended=&Αγνοήστε το σφάλμα και συνεχίστε (δεν συνιστάται)
SourceIsCorrupted=Το αρχείο προέλευσης είναι κατεστραμμένο
SourceDoesntExist=Το αρχείο προέλευσης "%1" δεν υπάρχει
ExistingFileReadOnly2=Το υπάρχον αρχείο δεν μπόρεσε να αντικατασταθεί επειδή είναι σημειωμένο ως μόνο για ανάγνωση.
ExistingFileReadOnlyRetry=&Αφαιρέστε το χαρακτηριστικό μόνο για ανάγνωση και δοκιμάστε ξανά
ExistingFileReadOnlyKeepExisting=&Διατήρηση του υπάρχοντος αρχείου
ErrorReadingExistingDest=Παρουσιάστηκε σφάλμα κατά την προσπάθεια ανάγνωσης του υπάρχοντος αρχείου:
FileExistsSelectAction=Επιλέξτε ενέργεια
FileExists2=Το αρχείο υπάρχει ήδη.
FileExistsOverwriteExisting=&Αντικατάσταση του υπάρχοντος αρχείου
FileExistsKeepExisting=&Διατήρηση του υπάρχοντος αρχείου
FileExistsOverwriteOrKeepAll=&Κάντε το ίδιο για τα επόμενα αρχεία
ExistingFileNewerSelectAction=Επιλέξτε ενέργεια
ExistingFileNewer2=Το υπάρχον αρχείο είναι νεότερο από αυτό που προσπαθεί να εγκαταστήσει το πρόγραμμα εγκατάστασης.
ExistingFileNewerOverwriteExisting=&Αντικατάσταση του υπάρχοντος αρχείου
ExistingFileNewerKeepExisting=&Διατήρηση του υπάρχοντος αρχείου (συνιστάται)
ExistingFileNewerOverwriteOrKeepAll=&Κάντε το ίδιο για τα επόμενα αρχεία
ErrorChangingAttr=Παρουσιάστηκε σφάλμα κατά την προσπάθεια αλλαγής των χαρακτηριστικών του υπάρχοντος αρχείου:
ErrorCreatingTemp=Παρουσιάστηκε σφάλμα κατά την προσπάθεια δημιουργίας ενός αρχείου στον κατάλογο προορισμού:
ErrorReadingSource=Παρουσιάστηκε σφάλμα κατά την προσπάθεια ανάγνωσης του αρχείου προέλευσης:
ErrorCopying=Παρουσιάστηκε σφάλμα κατά την προσπάθεια αντιγραφής ενός αρχείου:
ErrorReplacingExistingFile=Παρουσιάστηκε σφάλμα κατά την προσπάθεια αντικατάστασης του υπάρχοντος αρχείου:
ErrorRestartReplace=Η αντικατάσταση με επανεκκίνηση απέτυχε:
ErrorRenamingTemp=Παρουσιάστηκε σφάλμα κατά την προσπάθεια μετονομασίας ενός αρχείου στον κατάλογο προορισμού:
ErrorRegisterServer=Δεν είναι δυνατή η καταχώριση του DLL/OCX: %1
ErrorRegSvr32Failed=Το RegSvr32 απέτυχε με κωδικό εξόδου %1
ErrorRegisterTypeLib=Δεν είναι δυνατή η καταχώριση της βιβλιοθήκης τύπων: %1

; *** Uninstall display name markings
UninstallDisplayNameMark=%1 (%2)
UninstallDisplayNameMarks=%1 (%2, %3)
UninstallDisplayNameMark32Bit=32-bit
UninstallDisplayNameMark64Bit=64-bit
UninstallDisplayNameMarkAllUsers=Όλοι οι χρήστες
UninstallDisplayNameMarkCurrentUser=Τρέχων χρήστης

; *** Post-installation errors
ErrorOpeningReadme=Παρουσιάστηκε σφάλμα κατά την προσπάθεια ανοίγματος του αρχείου README.
ErrorRestartingComputer=Το πρόγραμμα εγκατάστασης δεν μπόρεσε να επανεκκινήσει τον υπολογιστή. Παρακαλώ κάντε το χειροκίνητα.

; *** Uninstaller messages
UninstallNotFound=Το αρχείο "%1" δεν υπάρχει. Δεν είναι δυνατή η απεγκατάσταση.
UninstallOpenError=Το αρχείο "%1" δεν μπόρεσε να ανοίξει. Δεν είναι δυνατή η απεγκατάσταση
UninstallUnsupportedVer=Το αρχείο καταγραφής απεγκατάστασης "%1" είναι σε μορφή που δεν αναγνωρίζεται από αυτήν την έκδοση του προγράμματος απεγκατάστασης. Δεν είναι δυνατή η απεγκατάσταση
UninstallUnknownEntry=Μια άγνωστη καταχώριση (%1) βρέθηκε στο αρχείο καταγραφής απεγκατάστασης
ConfirmUninstall=Είστε βέβαιοι ότι θέλετε να αφαιρέσετε εντελώς το %1 και όλα τα στοιχεία του;
UninstallOnlyOnWin64=Αυτή η εγκατάσταση μπορεί να απεγκατασταθεί μόνο σε 64-bit Windows.
OnlyAdminCanUninstall=Αυτή η εγκατάσταση μπορεί να απεγκατασταθεί μόνο από έναν χρήστη με δικαιώματα διαχειριστή.
UninstallStatusLabel=Παρακαλώ περιμένετε όσο το %1 αφαιρείται από τον υπολογιστή σας.
UninstalledAll=Το %1 αφαιρέθηκε επιτυχώς από τον υπολογιστή σας.
UninstalledMost=Η απεγκατάσταση του %1 ολοκληρώθηκε.%n%nΜερικά στοιχεία δεν μπόρεσαν να αφαιρεθούν. Αυτά μπορούν να αφαιρεθούν χειροκίνητα.
UninstalledAndNeedsRestart=Για να ολοκληρωθεί η απεγκατάσταση του %1, ο υπολογιστής σας πρέπει να επανεκκινηθεί.%n%nΘέλετε να επανεκκινήσετε τώρα;
UninstallDataCorrupted=Το αρχείο "%1" είναι κατεστραμμένο. Δεν είναι δυνατή η απεγκατάσταση

; *** Uninstallation phase messages
ConfirmDeleteSharedFileTitle=Αφαίρεση κοινόχρηστου αρχείου;
ConfirmDeleteSharedFile2=Το σύστημα υποδεικνύει ότι το ακόλουθο κοινόχρηστο αρχείο δεν χρησιμοποιείται πλέον από κανένα πρόγραμμα. Θέλετε η απεγκατάσταση να αφαιρέσει αυτό το κοινόχρηστο αρχείο;%n%nΑν κάποια προγράμματα εξακολουθούν να χρησιμοποιούν αυτό το αρχείο και αφαιρεθεί, αυτά τα προγράμματα ενδέχεται να μην λειτουργούν σωστά. Αν δεν είστε βέβαιοι, επιλέξτε Όχι. Η διατήρηση του αρχείου στο σύστημά σας δεν θα προκαλέσει ζημιά.
SharedFileNameLabel=Όνομα αρχείου:
SharedFileLocationLabel=Θέση:
WizardUninstalling=Κατάσταση απεγκατάστασης
StatusUninstalling=Απεγκατάσταση %1...

; *** Shutdown block reasons
ShutdownBlockReasonInstallingApp=Εγκατάσταση %1.
ShutdownBlockReasonUninstallingApp=Απεγκατάσταση %1.

; The custom wizard page names that are also used in the standard wizard
FinishedLabel=Η εγκατάσταση ολοκληρώθηκε επιτυχώς.

[CustomMessages]
NameAndVersion=%1 έκδοση %2
AdditionalIcons=Πρόσθετα εικονίδια:
CreateDesktopIcon=Δημιουργία εικονιδίου &επιφάνειας εργασίας
CreateQuickLaunchIcon=Δημιουργία εικονιδίου &γρήγορης εκκίνησης
ProgramOnTheWeb=%1 στο Διαδίκτυο
UninstallProgram=Απεγκατάσταση %1
LaunchProgram=Εκκίνηση %1
AssocFileExtension=&Συσχέτιση του %1 με την επέκταση αρχείου %2
AssocingFileExtension=Συσχέτιση του %1 με την επέκταση αρχείου %2...
AutoStartProgramGroupDescription=Εκκίνηση:
AutoStartProgram=Αυτόματη εκκίνηση %1
AddonHostProgramNotFound=%1 δεν βρέθηκε στον φάκελο που επιλέξατε.%n%nΘέλετε να συνεχίσετε ούτως ή άλλως;

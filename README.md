Προαιρετικό script για use case 10

Ο παρακάτω οδηγός περιγράφει τα βήματα για την τοπική εκτέλεση της εφαρμογής NutriFit και την εκκίνηση του Firebase Emulator για την κλήση του Gemini API μέσω Cloud Functions.

1. Προαπαιτούμενα
Βεβαιωθείτε ότι έχετε εγκατεστημένα τα παρακάτω στο σύστημά σας:

Node.js: Έκδοση 20 ή νεότερη (node --version)
npm: (npm --version)
Flutter: Έκδοση 3.x (flutter --version)

2. Σύνδεση στο Firebase (Authentication)
Για να συνδεθείτε στο project, πρέπει να κάνετε login στο Firebase CLI:

Bash
npx -y firebase-tools@latest login
(Αν το περιβάλλον σας δεν επιτρέπει το αυτόματο άνοιγμα του browser, τρέξτε: npx -y firebase-tools@latest login --no-localhost)

Στη συνέχεια, επιλέξτε το σωστό project:

Bash
npx -y firebase-tools@latest use nutrifit-project-2026
(Σημείωση: Το email σας πρέπει να έχει προστεθεί στους εξουσιοδοτημένους χρήστες του project στο Firebase Console. Αν αντιμετωπίσετε πρόβλημα πρόσβασης, παρακαλούμε επικοινωνήστε μαζί μας).

3. Ρύθμιση Περιβάλλοντος (.env)
Στον φάκελο functions, δημιουργήστε ένα αρχείο με το όνομα .env και προσθέστε τα παρακάτω:

Απόσπασμα κώδικα
GEMINI_API_KEY=AIzaSyANkczh-k7JVNyDdu697SPQctN9Tkt12M4
GEMINI_MODEL=gemini-2.5-flash
AI_PROVIDER=gemini

Το αρχείο αυτό δεν περιλαμβάνεται στο αποθετήριο για λόγους ασφαλείας.
Το κλειδί είναι προσωρινό και διαθέτει περιορισμένα token για ερωτήσεις.

Προαιρετικά, ελέγξτε τον κώδικα των functions για τυχόν σφάλματα:

Bash
npm --prefix functions run lint

4. Εκκίνηση των Firebase Emulators

Bash
npx -y firebase-tools@latest emulators:start --only functions

5. Δοκιμή του API (Μέσω Τερματικού)
Αν θέλετε να επιβεβαιώσετε ότι η Cloud Function λειτουργεί σωστά τοπικά, ανοίξτε ένα νέο τερματικό και τρέξτε:

PowerShell
Invoke-RestMethod `
  -Uri "http://127.0.0.1:5001/nutrifit-project-2026/us-central1/askNutriFitAi" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"query":"Πες μου ένα υγιεινό σνακ"}'
Αν όλα έχουν ρυθμιστεί σωστά, θα επιστραφεί η απάντηση από το AI.

6. Εκκίνηση της Εφαρμογής (Flutter)
Ενώ ο emulator τρέχει σε ένα τερματικό, ανοίξτε ένα δεύτερο τερματικό για να τρέξετε την εφαρμογή.
Χρησιμοποιούμε Dart Defines για να κατευθύνουμε την εφαρμογή να μιλήσει στο τοπικό API αντί για το παραγωγικό:

Για Chrome / Windows / Mac:

Bash
flutter run --dart-define=NUTRIFIT_USE_LOCAL_AI_EMULATOR=true

Για Πραγματική Συσκευή (στο ίδιο Wi-Fi):
Πρέπει να περάσετε την τοπική IP του υπολογιστή σας:

Bash
flutter run --dart-define=NUTRIFIT_AI_ENDPOINT=http://<Η_IP_ΤΟΥ_PC_ΣΑΣ>:5001/nutrifit-project-2026/us-central1/askNutriFitAi
(Παράδειγμα: http://192.168.1.25:5001/...)

Εκκίνηση μέσω VS Code (launch.json)
Αν προτιμάτε να τρέξετε την εφαρμογή με Debugging απευθείας από το VS Code, προσθέστε τα παρακάτω configurations στο αρχείο .vscode/launch.json:

JSON
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "NutriFit Local AI (Emulator/Web)",
      "request": "launch",
      "type": "dart",
      "toolArgs": [
        "--dart-define=NUTRIFIT_USE_LOCAL_AI_EMULATOR=true"
      ]
    },
    {
      "name": "NutriFit Local AI (Physical Device)",
      "request": "launch",
      "type": "dart",
      "toolArgs": [
        "--dart-define=NUTRIFIT_AI_ENDPOINT=http://<Η_IP_ΤΟΥ_PC_ΣΑΣ>:5001/nutrifit-project-2026/us-central1/askNutriFitAi"
      ]
    }
  ]
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'goals_screen.dart';
import 'ingredients_list_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final int initialStep;
  const RegistrationScreen({super.key, this.initialStep = 0});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late int _currentStep;
  bool isLoading = false;

  // Μεταβλητές για real time ελέγχους
  String? usernameError;
  List<String> suggestedUsernames = [];
  String? passwordError; 
  String? emailError; 

  // Χρώματα 
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);
  final Color waterBlue = const Color(0xFF7CB9E8);

  // Controllers
  final fullNameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  DateTime? selectedDateOfBirth;
  final heightController = TextEditingController();
  final weightController = TextEditingController();

  // FocusNodes
  final FocusNode fullNameFocus = FocusNode();
  final FocusNode usernameFocus = FocusNode();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  final FocusNode heightFocus = FocusNode();
  final FocusNode weightFocus = FocusNode();

  // Μεταβλητές επιλογών
  String selectedGender = 'Γυναίκα';
  String selectedActivity = 'Καθιστική (Γραφείο)';
  String selectedDiet = 'Όλα (Χωρίς περιορισμούς)';
  String eatingOutFreq = '1-2 φορές την εβδομάδα';
  bool snacksOften = false;
  int waterDrops = 2;

  // Λίστες για Chips
  List<String> selectedAllergies = [];
  List<String> selectedHealthIssues = []; 

  final List<String> dietTypes = [
    'Όλα (Χωρίς περιορισμούς)', 'Vegetarian', 'Vegan', 'Pescatarian', 'Keto / Low Carb'
  ];
  
  final List<String> healthOptions = [
    'Διαβήτης', 'Υπέρταση', 'Χοληστερίνη', 'Αναιμία', 'Θυρεοειδής', 'Ευαίσθητο Στομάχι'
  ];
  
  final List<String> eatingOutOptions = [
    'Σπάνια / Ποτέ', '1-2 φορές την εβδομάδα', '3-5 φορές την εβδομάδα', 'Καθημερινά'
  ];

  final List<String> foodCategories = [
    "Γαλακτοκομικά", "Ψάρια & Θαλασσινά", "Κρέας", "Δημητριακά & Ζυμαρικά", 
    "Ξηροί Καρποί", "Όσπρια", "Φρούτα", "Λαχανικά", "Μπαχαρικά", "Λοιπά"
  ];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _checkAndPrefillData();
  }

  @override
  void dispose() {
    fullNameFocus.dispose();
    usernameFocus.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    heightFocus.dispose();
    weightFocus.dispose();
    fullNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  // Συνάρτηση ελέγχου username
  Future<void> _checkUsernameAvailability(String val) async {
    final username = _normalizeUsername(val);
    if (username.isEmpty) {
      setState(() { usernameError = null; suggestedUsernames = []; });
      return;
    }

    final result = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(username)
        .get();

    if (result.exists) {
      setState(() {
        usernameError = 'Το username χρησιμοποιείται ήδη.';
        suggestedUsernames = [
          "${val.trim()}${val.length + 7}",
          "${val.trim()}_${DateTime.now().second}",
          "${val.trim()}Gr"
        ];
      });
    } else {
      setState(() { usernameError = null; suggestedUsernames = []; });
    }
  }

  // Συνάρτηση ελέγχου mail
  Future<void> _checkEmailAvailability(String val) async {
    if (val.trim().isEmpty) {
      setState(() { emailError = null; });
      return;
    }

    setState(() {
      emailError = val.contains('@') ? null : 'Η μορφή του Email δεν είναι έγκυρη.';
    });
  }

  // Συνάρτηση ελέγχου κωδικού
  void _checkPasswordStrength(String val) {
    if (val.isNotEmpty && val.length < 6) {
      setState(() {
        passwordError = 'Ο κωδικός πρέπει να έχει τουλάχιστον 6 χαρακτήρες.';
      });
    } else {
      setState(() {
        passwordError = null;
      });
    }
  }

  Future<void> _checkAndPrefillData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          fullNameController.text = data['fullName'] ?? '';
          usernameController.text = data['username'] ?? '';
          emailController.text = data['email'] ?? '';
          if (data['dateOfBirth'] != null) selectedDateOfBirth = (data['dateOfBirth'] as Timestamp).toDate();
          heightController.text = (data['height'] ?? '').toString();
          weightController.text = (data['weight'] ?? '').toString();
          selectedGender = data['gender'] ?? 'Γυναίκα';
          selectedActivity = data['dailyActivity'] ?? 'Καθιστική (Γραφείο)';
          selectedDiet = data['dietType'] ?? 'Όλα (Χωρίς περιορισμούς)';
          eatingOutFreq = data['eatingOutFrequency'] ?? '1-2 φορές την εβδομάδα';
          snacksOften = data['snacksOften'] ?? false;
          selectedAllergies = List<String>.from(data['allergies'] ?? []);
          selectedHealthIssues = List<String>.from(data['healthIssues'] ?? []);
          waterDrops = (data['dailyWaterIntake'] is int) ? data['dailyWaterIntake'] : 2;
        });
      }
    }
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (fullNameController.text.trim().isEmpty) {
        _showError('Παρακαλώ συμπληρώστε το Ονοματεπώνυμό σας.');
        fullNameFocus.requestFocus();
        return false;
      }
      if (usernameController.text.trim().isEmpty) {
        _showError('Παρακαλώ συμπληρώστε ένα Username.');
        usernameFocus.requestFocus();
        return false;
      }
      if (usernameError != null) {
        _showError('Παρακαλώ επιλέξτε ένα διαθέσιμο Username.');
        usernameFocus.requestFocus();
        return false;
      }
      if (emailController.text.trim().isEmpty) {
        _showError('Παρακαλώ συμπληρώστε το Email σας.');
        emailFocus.requestFocus();
        return false;
      }
      // Έλεγχος αν υπάρχει σφάλμα στο email
      if (emailError != null) {
        _showError('Παρακαλώ εισάγετε ένα διαθέσιμο Email.');
        emailFocus.requestFocus();
        return false;
      }
      if (passwordController.text.trim().isEmpty) {
        _showError('Παρακαλώ συμπληρώστε τον Κωδικό σας.');
        passwordFocus.requestFocus();
        return false;
      }
      if (passwordError != null) {
        _showError('Ο κωδικός είναι πολύ μικρός.');
        passwordFocus.requestFocus();
        return false;
      }
    } else if (_currentStep == 1) {
      if (selectedDateOfBirth == null) {
        _showError('Παρακαλώ επιλέξτε την Ημερομηνία Γέννησης.');
        return false;
      }
      if (heightController.text.trim().isEmpty) {
        _showError('Παρακαλώ συμπληρώστε το Ύψος σας.');
        heightFocus.requestFocus();
        return false;
      }
      if (weightController.text.trim().isEmpty) {
        _showError('Παρακαλώ συμπληρώστε το Βάρος σας.');
        weightFocus.requestFocus();
        return false;
      }
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  Future<void> _registerOrUpdateUser() async {
    setState(() => isLoading = true);
    var createdAuthUser = false;
    try {
      final auth = FirebaseAuth.instance;
      String uid;
      if (auth.currentUser == null) {
        UserCredential userCredential = await auth.createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
        uid = userCredential.user!.uid;
        createdAuthUser = true;
      } else {
        uid = auth.currentUser!.uid;
      }

      final username = _normalizeUsername(usernameController.text);
      final userData = {
        'fullName': fullNameController.text.trim(),
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'gender': selectedGender,
        'dateOfBirth': selectedDateOfBirth,
        'height': double.tryParse(heightController.text) ?? 170.0,
        'weight': double.tryParse(weightController.text) ?? 70.0,
        'dailyActivity': selectedActivity,
        'dietType': selectedDiet,
        'eatingOutFrequency': eatingOutFreq,
        'dailyWaterIntake': waterDrops,
        'snacksOften': snacksOften,
        'allergies': selectedAllergies,
        'healthIssues': selectedHealthIssues, 
        'hasSetGoals': false, 
      };

      final firestore = FirebaseFirestore.instance;
      final usernameRef = firestore.collection('usernames').doc(username);
      final userRef = firestore.collection('users').doc(uid);

      await firestore.runTransaction((transaction) async {
        final usernameDoc = await transaction.get(usernameRef);
        final usernameOwner = usernameDoc.data()?['uid'];
        if (usernameDoc.exists && usernameOwner != uid) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'username-already-in-use',
            message: 'Το username χρησιμοποιείται ήδη.',
          );
        }

        transaction.set(usernameRef, {
          'uid': uid,
          'email': emailController.text.trim(),
          'username': username,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(userRef, userData, SetOptions(merge: true));
      });

      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const GoalsScreen()));
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        setState(() => _currentStep = 0); 
        emailFocus.requestFocus();        
        _showError('Το email χρησιμοποιείται ήδη από άλλον λογαριασμό.');
      } else if (e.code == 'invalid-email') {
        setState(() => _currentStep = 0);
        emailFocus.requestFocus();
        _showError('Η μορφή του Email δεν είναι έγκυρη.');
      } else if (e.code == 'weak-password') {
        setState(() => _currentStep = 0);
        passwordFocus.requestFocus();     
        _showError('Ο Κωδικός είναι πολύ αδύναμος (τουλάχιστον 6 χαρακτήρες).');
      } else {
        _showError('Σφάλμα σύνδεσης: ${e.message}');
      }
    } on FirebaseException catch (e) {
      if (e.code == 'username-already-in-use') {
        if (createdAuthUser) {
          await FirebaseAuth.instance.currentUser?.delete();
        }
        setState(() => _currentStep = 0);
        usernameFocus.requestFocus();
        _showError('Το username χρησιμοποιείται ήδη.');
      } else {
        if (createdAuthUser) {
          await FirebaseAuth.instance.currentUser?.delete();
        }
        _showError('Σφάλμα Firebase: ${e.message ?? e.code}');
      }
    } catch (e) {
      _showError('Γενικό Σφάλμα: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _normalizeUsername(String value) {
    return value.trim().toLowerCase();
  }

  String get _waterText {
    switch (waterDrops) {
      case 1: return 'Λιγότερο από 1 Λίτρο';
      case 2: return 'Περίπου 1 Λίτρο';
      case 3: return '1.5 Λίτρα';
      case 4: return '2 Λίτρα';
      case 5: return 'Πάνω από 2.5 Λίτρα';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Προφίλ Χρήστη'), elevation: 0),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: sageGreen))
          : Theme(
              data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: sageGreen)),
              child: Stepper(
                type: StepperType.vertical,
                currentStep: _currentStep,
                onStepContinue: () {
                  if (!_validateCurrentStep()) return;
                  if (_currentStep < 3) {
                    setState(() => _currentStep += 1);
                  } else {
                    _registerOrUpdateUser();
                  }
                },
                onStepCancel: () => _currentStep > widget.initialStep ? setState(() => _currentStep -= 1) : Navigator.pop(context),
                controlsBuilder: (context, details) => Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: Row(
                    children: [
                      Expanded(child: ElevatedButton(onPressed: details.onStepContinue, child: Text(_currentStep == 3 ? 'ΑΠΟΘΗΚΕΥΣΗ' : 'ΕΠΟΜΕΝΟ'))),
                      const SizedBox(width: 15),
                      if (_currentStep > widget.initialStep) Expanded(child: OutlinedButton(onPressed: details.onStepCancel, child: const Text('ΠΙΣΩ'))),
                    ],
                  ),
                ),
                steps: _buildSteps(),
              ),
            ),
    );
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: Text('Λογαριασμός', style: TextStyle(color: slateGrey, fontWeight: FontWeight.bold)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: fullNameController, focusNode: fullNameFocus, decoration: const InputDecoration(labelText: 'Ονοματεπώνυμο')),
            const SizedBox(height: 12),
            TextField(
              controller: usernameController, 
              focusNode: usernameFocus, 
              onChanged: (val) => _checkUsernameAvailability(val),
              decoration: InputDecoration(
                labelText: 'Username',
                errorText: usernameError,
              ),
            ),
            if (suggestedUsernames.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Προτεινόμενα:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: suggestedUsernames.map((s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    usernameController.text = s;
                    _checkUsernameAvailability(s);
                  },
                )).toList(),
              ),
            ],
            const SizedBox(height: 12),

            TextField(
              controller: emailController, 
              focusNode: emailFocus, 
              onChanged: _checkEmailAvailability, 
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: emailError, 
              ),
            ),
            // ---------------------------------
            
            const SizedBox(height: 12),
            TextField(
              controller: passwordController, 
              focusNode: passwordFocus, 
              obscureText: true, 
              onChanged: _checkPasswordStrength, 
              decoration: InputDecoration(
                labelText: 'Κωδικός',
                errorText: passwordError, 
              ),
            ),
          ],
        ),
        isActive: _currentStep >= 0,
        state: widget.initialStep > 0 ? StepState.disabled : (_currentStep > 0 ? StepState.complete : StepState.indexed),
      ),
      Step(
        title: Text('Σωματικά Στοιχεία', style: TextStyle(color: slateGrey, fontWeight: FontWeight.bold)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Φύλο', style: TextStyle(fontWeight: FontWeight.w500)),
            DropdownButtonFormField<String>(initialValue: selectedGender, items: ['Άνδρας', 'Γυναίκα'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => selectedGender = val!)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(context: context, initialDate: selectedDateOfBirth ?? DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now(), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: sageGreen)), child: child!));
                      if (pickedDate != null) setState(() => selectedDateOfBirth = pickedDate);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                      child: Text(selectedDateOfBirth == null ? 'Ημ. Γέννησης' : '${selectedDateOfBirth!.day}/${selectedDateOfBirth!.month}/${selectedDateOfBirth!.year}', style: TextStyle(color: selectedDateOfBirth == null ? Colors.grey.shade600 : Colors.black87, fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(child: TextField(controller: heightController, focusNode: heightFocus, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ύψος (cm)'))),
              ],
            ),
            const SizedBox(height: 15),
            TextField(controller: weightController, focusNode: weightFocus, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Βάρος (kg)')),
          ],
        ),
        isActive: _currentStep >= 1,
      ),
      Step(
        title: Text('Τρόπος Ζωής', style: TextStyle(color: slateGrey, fontWeight: FontWeight.bold)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Επίπεδο Κίνησης', style: TextStyle(fontWeight: FontWeight.w500)),
            DropdownButtonFormField<String>(initialValue: selectedActivity, isExpanded: true, items: ['Καθιστική (Γραφείο)', 'Ελαφριά Κίνηση', 'Έντονη Κίνηση'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => selectedActivity = val!)),
            const SizedBox(height: 20),
            const Text('Διατροφική Προτίμηση', style: TextStyle(fontWeight: FontWeight.w500)),
            DropdownButtonFormField<String>(initialValue: selectedDiet, isExpanded: true, items: dietTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => selectedDiet = val!)),
          ],
        ),
        isActive: _currentStep >= 2,
      ),
      Step(
        title: Text('Συνήθειες & Υγεία', style: TextStyle(color: slateGrey, fontWeight: FontWeight.bold)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Πόσο συχνά τρώτε απ\' έξω;', style: TextStyle(fontWeight: FontWeight.w500)),
            DropdownButtonFormField<String>(initialValue: eatingOutFreq, isExpanded: true, items: eatingOutOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => eatingOutFreq = val!)),
            const SizedBox(height: 25),
            const Text('Πόσο νερό πίνετε καθημερινά;', style: TextStyle(fontWeight: FontWeight.w500)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(5, (i) => GestureDetector(onTap: () => setState(() => waterDrops = i + 1), child: Icon(Icons.water_drop, size: 38, color: i < waterDrops ? waterBlue : Colors.grey.shade300)))),
            Center(child: Text(_waterText, style: TextStyle(color: slateGrey, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Τσιμπολογάτε συχνά;'), value: snacksOften, activeThumbColor: sageGreen, onChanged: (v) => setState(() => snacksOften = v)),
            const Divider(height: 40),

            const Text('Προβλήματα Υγείας:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: healthOptions.map((opt) {
                final isS = selectedHealthIssues.contains(opt);
                return FilterChip(label: Text(opt), selected: isS, onSelected: (v) => setState(() => v ? selectedHealthIssues.add(opt) : selectedHealthIssues.remove(opt)), selectedColor: sageGreen, checkmarkColor: Colors.white, labelStyle: TextStyle(color: isS ? Colors.white : slateGrey));
              }).toList(),
            ),
            const SizedBox(height: 20),

            const Text('Αλλεργίες & Δυσανεξίες:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ...selectedAllergies.map((extraIng) => InputChip(
                      label: Text(extraIng),
                      backgroundColor: sageGreen,
                      deleteIconColor: Colors.white,
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      onDeleted: () => setState(() => selectedAllergies.remove(extraIng)),
                    )),
                        
                ActionChip(
                  avatar: const Icon(Icons.search, size: 16, color: Colors.white),
                  label: const Text('Υλικό', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: slateGrey,
                  onPressed: () async {
                    final selectedData = await Navigator.push(context, MaterialPageRoute(builder: (context) => const IngredientsListScreen(isSelectionMode: true)));
                    if (selectedData != null && selectedData is Map<String, dynamic>) {
                      String ingName = selectedData['name'];
                      if (!selectedAllergies.contains(ingName)) setState(() => selectedAllergies.add(ingName));
                    }
                  },
                ),

                ActionChip(
                  avatar: const Icon(Icons.category, size: 16, color: Colors.white),
                  label: const Text('Κατηγορία', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: sageGreen.withValues(alpha: 0.8),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Επιλογή Κατηγορίας'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView(
                            shrinkWrap: true,
                            children: foodCategories.map((cat) => ListTile(
                              title: Text(cat),
                              trailing: selectedAllergies.contains(cat) ? Icon(Icons.check, color: sageGreen) : null,
                              onTap: () {
                                setState(() {
                                  if (!selectedAllergies.contains(cat)) selectedAllergies.add(cat);
                                });
                                Navigator.pop(context); 
                              },
                            )).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (selectedAllergies.isEmpty) 
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Δεν έχετε προσθέσει αλλεργίες.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
        isActive: _currentStep >= 3,
      ),
    ];
  }
}

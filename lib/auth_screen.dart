import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'registration_screen.dart';
import 'home_screen.dart'; 

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool showLoginForm = false; 
  final TextEditingController loginInputController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  // Συνάρτηση login 
  Future<void> _login() async {
    setState(() => isLoading = true);
    try {
      String input = loginInputController.text.trim();
      String password = passwordController.text.trim();
      String loginEmail = input;

      if (input.isEmpty || password.isEmpty) {
        throw 'Παρακαλώ συμπληρώστε όλα τα πεδία.';
      }

      // Αν δεν έχει @, ψάχνουμε το email μέσω του username στο Firestore
      if (!input.contains('@')) {
        var querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: input)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw 'Δεν βρέθηκε χρήστης με αυτό το Username.';
        }
        loginEmail = querySnapshot.docs.first['email'];
      }

      // Σύνδεση στο Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: loginEmail,
        password: password,
      );

      // Αν η σύνδεση πετύχει πάμε στο HomeScreen
      if (mounted) {
        loginInputController.clear();
        passwordController.clear();
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
      // ----------------------------------------

    } on FirebaseAuthException catch (e) {
      String msg = "Σφάλμα σύνδεσης.";
      if (e.code == 'wrong-password') msg = "Λάθος κωδικός πρόσβασης.";
      if (e.code == 'user-not-found') msg = "Ο χρήστης δεν βρέθηκε.";
      _showSnackBar(msg);
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: showLoginForm ? _buildLoginForm() : _buildWelcomeScreen(),
            ),
          ),
        ),
      ),
    );
  }

  // Οθόνη υποδοχής
  Widget _buildWelcomeScreen() {
    return Column(
      key: const ValueKey('welcome'),
      children: [
        Container(
          width: 180, height: 180,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
          ),
          child: ClipOval(
            child: Image.asset('assets/logo.jpg', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 30),

        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            children: [
              TextSpan(text: 'Nutri', style: TextStyle(color: sageGreen)),
              TextSpan(text: 'Fit', style: TextStyle(color: slateGrey)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Καλώς ήρθες στην καλύτερη εκδοχή σου',
          style: TextStyle(color: slateGrey.withValues(alpha: 0.8), fontSize: 16),
        ),
        const SizedBox(height: 60),

        ElevatedButton(
          onPressed: () => setState(() => showLoginForm = true),
          child: const Text('ΣΥΝΔΕΣΗ'),
        ),
        const SizedBox(height: 15),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 55),
            side: BorderSide(color: sageGreen, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen(initialStep: 0,)));
          },
          child: Text('ΔΗΜΙΟΥΡΓΙΑ ΛΟΓΑΡΙΑΣΜΟΥ', style: TextStyle(color: sageGreen, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // Φόρμα σύνδεσης
  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: slateGrey),
            onPressed: () => setState(() => showLoginForm = false),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Είσοδος',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: slateGrey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        TextField(
          controller: loginInputController,
          decoration: InputDecoration(
            hintText: 'Username ή Email',
            prefixIcon: Icon(Icons.person_outline, color: sageGreen),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Κωδικός',
            prefixIcon: Icon(Icons.lock_outline, color: sageGreen),
          ),
        ),
        const SizedBox(height: 30),
        isLoading 
          ? Center(child: CircularProgressIndicator(color: sageGreen))
          : ElevatedButton(onPressed: _login, child: const Text('ΕΙΣΟΔΟΣ')),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const NutriFitApp());
}

class NutriFitApp extends StatelessWidget {
  const NutriFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Η παλέτα χρωμάτων από το λογότυπό μας
    const Color beigeBackground = Color(0xFFF8F6F1);
    const Color sageGreen = Color(0xFFA8B3A0);
    const Color slateGrey = Color(0xFF8C9DA6);

    return MaterialApp(
      title: 'NutriFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: beigeBackground,
        
        // Κύρια χρώματα
        colorScheme: ColorScheme.fromSeed(
          seedColor: sageGreen,
          primary: sageGreen,
          secondary: slateGrey,
          surface: Colors.white,
        ),

        // Στυλ AppBar για όλη την εφαρμογή
        appBarTheme: const AppBarTheme(
          backgroundColor: beigeBackground,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: slateGrey, 
            fontSize: 20, 
            fontWeight: FontWeight.bold
          ),
          iconTheme: IconThemeData(color: slateGrey),
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),

        // Στυλ για τα κουμπιά
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: sageGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
          ),
        ),

        // Στυλ για τα πεδία κειμένου (TextFields)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: sageGreen, width: 2),
          ),
        ),
      ),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Όσο το Firebase ψάχνει στα αρχεία να βρει αν υπάρχει logged-in χρήστης
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: beigeBackground,
              body: Center(
                child: CircularProgressIndicator(color: sageGreen), // Δείχνει ένα κυκλάκι
              ),
            );
          }
          
          // 2. Αν βρήκε αποθηκευμένο ενεργό χρήστη!
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          
          // 3. Αν δεν βρήκε κανέναν (ή αν ο χρήστης πάτησε "Αποσύνδεση")
          return const AuthScreen();
        },
      ),
    );
  }
}
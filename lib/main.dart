import 'package:flutter/material.dart';
import 'auth_screen.dart';

void main() {
  runApp(const NutriFitApp());
}

class NutriFitApp extends StatelessWidget {
  const NutriFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color beigeBackground = Color(0xFFF8F6F1);
    const Color sageGreen = Color(0xFFA8B3A0);
    const Color slateGrey = Color(0xFF8C9DA6);

    return MaterialApp(
      title: 'NutriFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: beigeBackground,

        colorScheme: ColorScheme.fromSeed(
          seedColor: sageGreen,
          primary: sageGreen,
          secondary: slateGrey,
          surface: Colors.white,
        ),

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

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: sageGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
          ),
        ),

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

      home: const AuthScreen(),
    );
  }
}
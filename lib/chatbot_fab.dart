import 'package:flutter/material.dart';
import 'chatbot_screen.dart'; // Βεβαιώσου ότι το path είναι σωστό

class ChatbotFab extends StatelessWidget {
  const ChatbotFab({super.key});

  @override
  Widget build(BuildContext context) {
    final Color sageGreen = const Color(0xFFA8B3A0);

    return FloatingActionButton(
      heroTag: 'chatbot_fab', // Αποτρέπει σφάλματα αν υπάρχουν κι άλλα FABs στο app
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatbotScreen()),
        );
      },
      backgroundColor: sageGreen,
      elevation: 4,
      tooltip: 'NutriFit Assistant',
      child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
    );
  }
}
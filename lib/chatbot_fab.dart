import 'package:flutter/material.dart';

import 'chatbot_screen.dart';

class ChatbotFab extends StatelessWidget {
  const ChatbotFab({super.key});

  @override
  Widget build(BuildContext context) {
    const sageGreen = Color(0xFFA8B3A0);

    return FloatingActionButton(
      heroTag: 'chatbot_fab',
      backgroundColor: sageGreen,
      tooltip: 'NutriFit Assistant',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatbotScreen()),
        );
      },
      child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
    );
  }
}

import 'package:flutter/material.dart';

// UI Model to represent different message states based on the robustness diagram
enum MessageType { user, bot, error, constraint, rephrase }

class ChatMessage {
  final String text;
  final MessageType type;
  ChatMessage({required this.text, required this.type});
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);
  final Color lightBeige = const Color(0xFFF8F6F1);

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Stubbed messages to demonstrate the UI states from the sequence diagram
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Γεια σας! Είμαι ο προσωπικός σας βοηθός NutriFit. Πώς μπορώ να σας βοηθήσω σήμερα με τη διατροφή ή τη γυμναστική σας;",
      type: MessageType.bot,
    ),
  ];

  // Preset questions based on the robustness diagram
  final List<String> _presetQuestions = [
    "Πόσες θερμίδες έχει ένα μήλο;",
    "Πρότεινέ μου ένα γρήγορο πρωινό.",
    "Τι άσκηση να κάνω για πλάτη;"
  ];

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      // 1. User inputs question
      _messages.add(ChatMessage(text: text, type: MessageType.user));
      _inputController.clear();
      
      // TODO: Hook up ChatbotController.analyzeQuestion(query) here
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- UI Methods for Testing Diagram States ---
  // Call these methods from your Controller to trigger the UI changes
  
  void showResponse(String response) {
    setState(() => _messages.add(ChatMessage(text: response, type: MessageType.bot)));
    _scrollToBottom();
  }

  void showTopicConstraints() {
    setState(() => _messages.add(ChatMessage(
      text: "Παρακαλώ περιορίστε τις ερωτήσεις σας σε θέματα διατροφής, ευεξίας και γυμναστικής.", 
      type: MessageType.constraint
    )));
    _scrollToBottom();
  }

  void promptRephrase() {
    setState(() => _messages.add(ChatMessage(
      text: "Δεν κατάλαβα ακριβώς τι εννοείτε. Μπορείτε να το αναδιατυπώσετε;", 
      type: MessageType.rephrase
    )));
    _scrollToBottom();
  }

  void showConnectionError() {
    setState(() => _messages.add(ChatMessage(
      text: "Υπήρξε πρόβλημα σύνδεσης με τον διακομιστή AI. Παρακαλώ δοκιμάστε ξανά σε λίγο.", 
      type: MessageType.error
    )));
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NutriFit Assistant', style: TextStyle(color: Colors.white)),
        backgroundColor: sageGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Drawer handles the "checkHistory" and "displayHistoryOptions" from the sequence diagram
      drawer: _buildHistoryDrawer(),
      body: Column(
        children: [
          // Chat Messages Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          
          // Preset Questions Area (from Robustness Diagram)
          _buildPresetQuestionsRow(),
          
          // Input Area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: sageGreen),
            child: const Center(
              child: Text(
                'Ιστορικό Συνομιλιών',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Νέα Συνομιλία', style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _messages.clear();
                _messages.add(ChatMessage(
                  text: "Γεια σας! Ξεκινήσαμε μια νέα συνομιλία. Πώς μπορώ να βοηθήσω;", 
                  type: MessageType.bot
                ));
              });
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Πρόσφατες', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          // Stubbed history items
          Expanded(
            child: ListView.builder(
              itemCount: 3, 
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, size: 20),
                  title: Text('Συνομιλία ${index + 1}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    // TODO: Hook up ChatbotController.loadChat(chatId)
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    bool isUser = message.type == MessageType.user;
    
    // Determine styles based on message type (handling diagram states)
    Color bubbleColor;
    Color textColor = isUser ? Colors.white : Colors.black87;
    IconData? stateIcon;

    switch (message.type) {
      case MessageType.user:
        bubbleColor = sageGreen;
        break;
      case MessageType.bot:
        bubbleColor = lightBeige;
        break;
      case MessageType.constraint:
        bubbleColor = Colors.orange.shade100;
        stateIcon = Icons.warning_amber_rounded;
        break;
      case MessageType.rephrase:
        bubbleColor = Colors.blue.shade100;
        stateIcon = Icons.help_outline;
        break;
      case MessageType.error:
        bubbleColor = Colors.red.shade100;
        stateIcon = Icons.error_outline;
        break;
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stateIcon != null) ...[
              Icon(stateIcon, size: 18, color: Colors.black54),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                message.text,
                style: TextStyle(color: textColor, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetQuestionsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _presetQuestions.map((q) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(q, style: TextStyle(color: slateGrey, fontSize: 13)),
              backgroundColor: lightBeige,
              side: BorderSide(color: sageGreen.withValues(alpha: 0.3)),
              onPressed: () => _sendMessage(q),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Πληκτρολογήστε την ερώτησή σας...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: lightBeige,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: sageGreen,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () => _sendMessage(_inputController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'chatbot_controller.dart'; 

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
  
  final ChatbotController _controller = ChatbotController();

  final List<String> _presetQuestions = [
    "Πόσες θερμίδες έχει ένα μήλο;",
    "Πρότεινέ μου ένα γρήγορο πρωινό.",
    "Τι άσκηση να κάνω για πλάτη;"
  ];

  @override
  void initState() {
    super.initState();
    _controller.initializeHistory();
    _controller.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _controller.removeListener(_scrollToBottom);
    _controller.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && !_controller.showSelectionScreen) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty || _controller.isLoading) return;
    _inputController.clear();
    _controller.processUserQuery(text); 
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('NutriFit Assistant', style: TextStyle(color: Colors.white)),
            backgroundColor: sageGreen,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          // Το drawer εμφανίζεται ΜΟΝΟ όταν είμαστε μέσα στο chat (για να μπορεί να αλλάξει συνομιλία)
          endDrawer: _controller.showSelectionScreen ? null : _buildHistoryDrawer(),
          body: _controller.isLoading && _controller.currentMessages.isEmpty && _controller.history.isEmpty
              ? Center(child: CircularProgressIndicator(color: sageGreen))
              : _controller.showSelectionScreen
                  ? _buildSelectionScreen() // ΝΕΑ ΟΘΟΝΗ ΕΠΙΛΟΓΗΣ
                  : _buildActiveChatScreen(), // Η ΚΑΝΟΝΙΚΗ ΟΘΟΝΗ CHAT
        );
      },
    );
  }

  // ΝΕΑ ΜΕΘΟΔΟΣ: Οθόνη Επιλογής (Use Case Βήμα 3)
  Widget _buildSelectionScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.forum_outlined, size: 60, color: sageGreen),
          const SizedBox(height: 16),
          Text(
            'Καλώς ήρθατε ξανά!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: slateGrey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Επιλέξτε να συνεχίσετε μια παλιά συζήτηση ή ξεκινήστε μια νέα.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: sageGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('ΝΕΑ ΣΥΝΟΜΙΛΙΑ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _controller.startNewChat,
          ),
          const SizedBox(height: 32),

          Text('Ιστορικό Συνομιλιών', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateGrey)),
          const SizedBox(height: 12),
          
          Expanded(
            child: ListView.builder(
              itemCount: _controller.history.length,
              itemBuilder: (context, index) {
                final session = _controller.history[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: lightBeige,
                      child: Icon(Icons.chat_bubble_outline, color: sageGreen, size: 20),
                    ),
                    title: Text(session.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => _controller.loadChat(session.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Η κανονική οθόνη του Chat
  Widget _buildActiveChatScreen() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _controller.currentMessages.length,
            itemBuilder: (context, index) {
              return _buildMessageBubble(_controller.currentMessages[index]);
            },
          ),
        ),
        
        if (_controller.isLoading && _controller.currentMessages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Το NutriFit σκέφτεται...', style: TextStyle(color: slateGrey, fontStyle: FontStyle.italic)),
          ),

        _buildPresetQuestionsRow(),
        _buildInputArea(),
      ],
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
              _controller.startNewChat(); 
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Πρόσφατες', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _controller.history.length, 
              itemBuilder: (context, index) {
                final session = _controller.history[index];
                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, size: 20),
                  title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  selected: _controller.currentChatId == session.id,
                  selectedColor: sageGreen,
                  onTap: () {
                    Navigator.pop(context);
                    _controller.loadChat(session.id); 
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
    
    Color bubbleColor;
    Color textColor = isUser ? Colors.white : Colors.black87;
    IconData? stateIcon;

    switch (message.type) {
      case MessageType.user: 
        bubbleColor = sageGreen; 
        break;
      case MessageType.bot: 
        // ΑΛΛΑΓΗ ΕΔΩ: Το κάναμε λευκό για να κάνει αντίθεση με το μπεζ background
        bubbleColor = Colors.white; 
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
      case MessageType.connectionError:
        bubbleColor = Colors.red.shade50;
        stateIcon = Icons.wifi_off_rounded;
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
          // ΝΕΑ ΠΡΟΣΘΗΚΗ: Διακριτική σκιά για να φαίνονται τα bubbles ανάγλυφα
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, 2),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stateIcon != null) ...[
              Icon(stateIcon, size: 18, color: Colors.black54),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(message.text, style: TextStyle(color: textColor, fontSize: 15))),
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
              onPressed: _controller.isLoading ? null : () => _handleSubmitted(q), 
              disabledColor: Colors.grey.shade200,
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -2), blurRadius: 5)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                onSubmitted: _handleSubmitted,
                decoration: InputDecoration(
                  hintText: 'Πληκτρολογήστε την ερώτησή σας...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: lightBeige,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(color: sageGreen, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _controller.isLoading
                    ? null
                    : () => _handleSubmitted(_inputController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

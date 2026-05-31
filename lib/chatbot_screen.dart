import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Γεια σου! Είμαι ο NutriFit Assistant. Πώς μπορώ να βοηθήσω;',
      isUser: false,
    ),
  ];
  final List<String> _presetQuestions = [
    'Προβολή προφίλ',
    'Προτεινόμενα προγράμματα γυμναστικής',
    'Ημερήσιο πλάνο γευμάτων',
    'Δώσε μου συμβουλές αποκατάστασης μετά από προπόνηση',
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final query = (presetText ?? _inputController.text).trim();
    if (query.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: query, isUser: true));
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final answer = await _askNutriFitAi(query);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: answer, isUser: false));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage(
            text:
                'Δεν μπόρεσα να συνδεθώ με το AI αυτή τη στιγμή. Έλεγξε ότι τρέχει ο Functions emulator.',
            isUser: false,
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  Future<String> _askNutriFitAi(String query) async {
    const configuredEndpoint = String.fromEnvironment('NUTRIFIT_AI_ENDPOINT');
    final endpoint = configuredEndpoint.trim().isNotEmpty
        ? configuredEndpoint.trim()
        : 'http://${_localFunctionsHost()}:5001/'
              'nutrifit-project-2026/us-central1/askNutriFitAi';

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'query': query}),
        )
        .timeout(const Duration(seconds: 25));

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (decoded is Map && decoded['error'] != null) {
        throw Exception(decoded['error']);
      }
      throw Exception('AI request failed: ${response.statusCode}');
    }

    if (decoded is Map) {
      final answer =
          decoded['answer'] ?? decoded['text'] ?? decoded['response'];
      if (answer != null && answer.toString().trim().isNotEmpty) {
        return answer.toString().trim();
      }
    }

    throw Exception('Empty AI response');
  }

  static String _localFunctionsHost() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NutriFit Assistant'),
        backgroundColor: sageGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _ChatBubble(
                message: _messages[index],
                sageGreen: sageGreen,
                slateGrey: slateGrey,
              ),
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Το NutriFit αναζητά απάντηση...',
                style: TextStyle(color: slateGrey, fontStyle: FontStyle.italic),
              ),
            ),
          _buildPresetQuestionsRow(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Πληκτρολογήστε την ερώτησή σας...',
                        filled: true,
                        fillColor: const Color(0xFFF8F6F1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    heroTag: 'chatbot_send',
                    backgroundColor: sageGreen,
                    onPressed: _isLoading ? null : _sendMessage,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetQuestionsRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _presetQuestions
              .map(
                (question) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      question,
                      style: TextStyle(color: slateGrey, fontSize: 13),
                    ),
                    backgroundColor: const Color(0xFFF8F6F1),
                    disabledColor: Colors.grey.shade200,
                    side: BorderSide(color: sageGreen.withValues(alpha: 0.3)),
                    onPressed: _isLoading ? null : () => _sendMessage(question),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.sageGreen,
    required this.slateGrey,
  });

  final _ChatMessage message;
  final Color sageGreen;
  final Color slateGrey;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final background = message.isUser
        ? sageGreen
        : message.isError
        ? Colors.red.shade50
        : Colors.white;
    final textColor = message.isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isUser) ...[
              Icon(
                message.isError
                    ? Icons.wifi_off_rounded
                    : Icons.auto_awesome_outlined,
                size: 18,
                color: message.isError ? Colors.red.shade300 : slateGrey,
              ),
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
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}

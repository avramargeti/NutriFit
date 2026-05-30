import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ai_api_client.dart';
import 'chat_history_repository.dart';
import 'chatbot_models.dart';
import 'local_data_repository.dart';

export 'chatbot_models.dart';
export 'local_data_repository.dart';

class ChatbotController extends ChangeNotifier {
  ChatbotController({
    FirebaseAuth? auth,
    ChatHistoryRepository? historyRepository,
    LocalDataRepository? localDataRepository,
    AiApiClient? aiApiClient,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _historyRepository = historyRepository ?? ChatHistoryRepository(),
        _localDataRepository = localDataRepository ?? LocalDataRepository(),
        _aiApiClient = aiApiClient ?? AiApiClient();

  final FirebaseAuth _auth;
  final ChatHistoryRepository _historyRepository;
  final LocalDataRepository _localDataRepository;
  final AiApiClient _aiApiClient;

  List<ChatMessage> currentMessages = [];
  List<ChatSession> history = [];
  bool isLoading = false;
  bool showSelectionScreen = false;
  String? currentChatId;

  Future<void> initializeHistory() async {
    isLoading = true;
    notifyListeners();

    await _localDataRepository.loadData();
    final user = _auth.currentUser;

    if (user != null) {
      try {
        history = await _historyRepository.fetchHistory();
      } catch (e) {
        debugPrint("Σφάλμα φόρτωσης ιστορικού: $e");
      }
    } else {
      history = [];
      currentChatId = null;
    }

    if (history.isEmpty) {
      showSelectionScreen = false;
      currentMessages = [
        ChatMessage(
          text: "Καλώς ήρθατε στο NutriFit Assistant! Μπορώ να αναζητήσω συνταγές, υλικά, macros, θερμίδες, προγράμματα γυμναστικής και στοιχεία από το προφίλ σας. Πώς μπορώ να βοηθήσω;",
          type: MessageType.bot,
        ),
      ];
    } else {
      showSelectionScreen = true;
      currentMessages = [];
    }

    isLoading = false;
    notifyListeners();
  }

  void startNewChat() {
    showSelectionScreen = false;
    currentChatId = null;
    currentMessages = [
      ChatMessage(
        text: "Γεια σας! Είμαι ο προσωπικός σας βοηθός NutriFit. Πώς μπορώ να σας βοηθήσω σήμερα;",
        type: MessageType.bot,
      ),
    ];
    notifyListeners();
  }

  void loadChat(String id) {
    final session = history.firstWhere((s) => s.id == id);
    showSelectionScreen = false;
    currentChatId = session.id;
    currentMessages = List<ChatMessage>.from(session.messages);
    notifyListeners();
  }

  Future<void> processUserQuery(String text) async {
    final query = text.trim();
    if (query.isEmpty || isLoading) return;

    currentMessages.add(ChatMessage(text: query, type: MessageType.user));
    isLoading = true;
    notifyListeners();

    try {
      await _localDataRepository.loadData(forceRefresh: true);
      final normalizedText = _localDataRepository.normalize(query);
      late final ChatMessage response;

      if (_isOutOfTopic(normalizedText)) {
        response = ChatMessage(
          text: "Παρακαλώ περιορίστε τις ερωτήσεις σας σε θέματα διατροφής, ευεξίας και γυμναστικής.",
          type: MessageType.constraint,
        );
      } else if (_localDataRepository.isGibberish(query) ||
          _understandingFailed(normalizedText)) {
        response = ChatMessage(
          text: "Δεν μπόρεσα να καταλάβω το μήνυμά σας. Μπορείτε να το αναδιατυπώσετε με περισσότερες λεπτομέρειες;",
          type: MessageType.rephrase,
        );
      } else {
        final localResponse = _localDataRepository.retrieveInformation(normalizedText);

        if (localResponse != null) {
          response = ChatMessage(text: localResponse, type: MessageType.bot);
        } else {
          response = await _askExternalAi(query);
        }
      }

      currentMessages.add(response);
      if (response.type == MessageType.bot) {
        await _saveCurrentSessionToHistory();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  bool _isOutOfTopic(String normalizedText) {
    final outOfTopicWords = [
      "καιρος",
      "πολιτικη",
      "ταινι",
      "ποδοσφαιρο",
      "μουσικη",
      "ταξιδι",
    ];

    return outOfTopicWords.any(normalizedText.contains);
  }

  bool _understandingFailed(String normalizedText) {
    return normalizedText.length < 2;
  }

  Future<ChatMessage> _askExternalAi(String query) async {
    try {
      final responseText = await _aiApiClient.ask(query).timeout(
            const Duration(seconds: 10),
          );
      return ChatMessage(text: responseText, type: MessageType.bot);
    } on TimeoutException {
      return ChatMessage(
        text: "Υπήρξε καθυστέρηση στην επικοινωνία με την εξωτερική υπηρεσία AI. Δοκίμασε ξανά σε λίγο.",
        type: MessageType.connectionError,
      );
    } catch (e) {
      debugPrint("Σφάλμα εξωτερικού AI API: $e");
      return ChatMessage(
        text: "Υπήρξε πρόβλημα σύνδεσης με την εξωτερική υπηρεσία AI. Η συνομιλία αποθηκεύτηκε και μπορείς να ξαναδοκιμάσεις.",
        type: MessageType.connectionError,
      );
    }
  }

  Future<void> _saveCurrentSessionToHistory() async {
    final user = _auth.currentUser;
    if (user == null || currentMessages.isEmpty) return;

    try {
      final title = _buildSessionTitle();
      final savedChatId = await _historyRepository.saveConversation(
        chatId: currentChatId,
        title: title,
        messages: currentMessages,
      );

      currentChatId = savedChatId;
      final session = ChatSession(savedChatId, title, List.from(currentMessages));
      final index = history.indexWhere((s) => s.id == savedChatId);

      if (index == -1) {
        history.insert(0, session);
      } else {
        history[index] = session;
      }
    } catch (e) {
      debugPrint("Σφάλμα αποθήκευσης συνομιλίας: $e");
    }
  }

  String _buildSessionTitle() {
    for (final message in currentMessages) {
      if (message.type == MessageType.user) {
        return message.text.length > 25
            ? "${message.text.substring(0, 25)}..."
            : message.text;
      }
    }
    return "Νέα Συνομιλία";
  }
}

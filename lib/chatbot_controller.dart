import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ai_api_client.dart';
import 'chat_history_repository.dart';
import 'chatbot_models.dart';
import 'local_data_repository.dart';
export 'chatbot_models.dart';

class ChatbotController extends ChangeNotifier {
  ChatbotController()
    : _auth = FirebaseAuth.instance,
      _historyRepository = ChatHistoryRepository(),
      _localDataRepository = LocalDataRepository(),
      _aiApiClient = AiApiClient();

  final FirebaseAuth _auth;
  final ChatHistoryRepository _historyRepository;
  final LocalDataRepository _localDataRepository;
  final AiApiClient _aiApiClient;

  List<ChatMessage> currentMessages = [];
  List<ChatSession> history = [];
  bool isLoading = false;
  bool showSelectionScreen = false;
  String? currentChatId;

  String get _userId => _auth.currentUser?.uid ?? '';

  Future<void> checkHistory(String userId) async {
    isLoading = true;
    notifyListeners();

    if (userId.isNotEmpty) {
      history = await _historyRepository.fetchHistory(userId);
    }

    if (history.isEmpty) {
      showSelectionScreen = false;
      currentMessages = [
        ChatMessage(
          text: "Καλώς ήρθατε στο NutriFit Assistant! Πώς μπορώ να βοηθήσω;",
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
        text: "Γεια σας! Είμαι ο βοηθός NutriFit. Πώς μπορώ να σας βοηθήσω;",
        type: MessageType.bot,
      ),
    ];
    notifyListeners();
  }

  Future<void> loadChat(String chatId) async {
    isLoading = true;
    notifyListeners();

    currentChatId = chatId;
    showSelectionScreen = false;
    currentMessages = await _historyRepository.fetchMessages(_userId, chatId);

    isLoading = false;
    notifyListeners();
  }

  Future<void> analyzeQuestion(String query) async {
  if (query.trim().isEmpty || isLoading) return;

  currentMessages.add(ChatMessage(text: query, type: MessageType.user));
  isLoading = true;
  notifyListeners();

  if (checkTopic(query)) {
    rejectAndReturnConstraints();
  } else {
    if (!checkUnderstanding(query)) {
      handleUnderstandingError();
    } else {
      final intent = _localDataRepository.normalize(query);
      final localData = await _localDataRepository.retrieveInformation(intent);

      dynamic responseData;
      MessageType responseType = MessageType.bot;

      if (localData != null) {
        responseData = localData;
        responseType = MessageType.bot; // Local database response
      } else {
        try {
          responseData = await _aiApiClient.callExternalAPI(query);
          responseType = MessageType.externalAi; // API / Gemini response
        } catch (e) {
          cancelProcess();
          connectionProblem();
          isLoading = false;
          notifyListeners();
          return;
        }
      }

      final finalResponse = synthesizeResponse(
        responseData,
        type: responseType,
      );

      currentMessages.add(finalResponse);

      currentChatId = await _historyRepository.saveConversation(
        userId: _userId,
        query: query,
        response: finalResponse.text,
        chatId: currentChatId,
        title: _buildSessionTitle(),
        allMessages: currentMessages,
      );
    }
  }

  isLoading = false;
  notifyListeners();
}

  bool checkTopic(String query) {
    final normalizedText = _localDataRepository.normalize(query);
    final outOfTopicWords = [
      "καιρος",
      "πολιτικη",
      "ταινι",
      "ποδοσφαιρο",
      "μουσικη",
      "ταξιδι",
    ];
    return outOfTopicWords.any(
      normalizedText.contains,
    ); // Επιστρέφει true αν είναι εκτός θέματος
  }

  void rejectAndReturnConstraints() {
    currentMessages.add(
      ChatMessage(
        text:
            "Παρακαλώ περιορίστε τις ερωτήσεις σας σε θέματα διατροφής, ευεξίας και γυμναστικής.",
        type: MessageType.constraint,
      ),
    );
  }

  bool checkUnderstanding(String query) {
    final normalizedText = _localDataRepository.normalize(query);
    return !_localDataRepository.isGibberish(query) &&
        normalizedText.length >= 2;
  }

  void handleUnderstandingError() {
    currentMessages.add(
      ChatMessage(
        text:
            "Δεν μπόρεσα να καταλάβω το μήνυμά σας. Μπορείτε να το αναδιατυπώσετε;",
        type: MessageType.rephrase,
      ),
    );
  }

  void cancelProcess() {
    debugPrint("Διαδικασία AI ακυρώθηκε λόγω σφάλματος/timeout.");
  }

  void connectionProblem() {
    currentMessages.add(
      ChatMessage(
        text:
            "Υπήρξε πρόβλημα σύνδεσης με την εξωτερική υπηρεσία AI. Δοκίμασε ξανά σε λίγο.",
        type: MessageType.connectionError,
      ),
    );
  }

  ChatMessage synthesizeResponse(
  dynamic data, {
  MessageType type = MessageType.bot,
}) {
  return ChatMessage(
    text: data.toString(),
    type: type,
  );
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

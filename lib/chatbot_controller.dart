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
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || isLoading) return;

    currentMessages.add(
      ChatMessage(text: trimmedQuery, type: MessageType.user),
    );
    isLoading = true;
    notifyListeners();

    try {
      final finalResponse = await _buildResponseFor(trimmedQuery);
      currentMessages.add(finalResponse);
      await _saveConversation(trimmedQuery, finalResponse);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<ChatMessage> _buildResponseFor(String query) async {
    if (checkTopic(query)) {
      return _constraintMessage();
    }

    if (!checkUnderstanding(query)) {
      return _rephraseMessage();
    }

    final intent = _localDataRepository.normalize(query);
    String? localData;

    try {
      localData = await _localDataRepository.retrieveInformation(intent);
    } catch (error) {
      debugPrint("Σφάλμα ανάκτησης τοπικών δεδομένων chatbot: $error");
    }

    if (localData != null) {
      return synthesizeResponse(localData);
    }

    try {
      final externalResponse = await _aiApiClient.callExternalAPI(query);
      return synthesizeResponse(externalResponse, type: MessageType.externalAi);
    } on AiApiException catch (error) {
      cancelProcess();
      return _externalAiErrorMessage(error);
    }
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
    currentMessages.add(_constraintMessage());
  }

  ChatMessage _constraintMessage() {
    return ChatMessage(
      text:
          "Παρακαλώ περιορίστε τις ερωτήσεις σας σε θέματα διατροφής, "
          "ευεξίας και γυμναστικής.",
      type: MessageType.constraint,
    );
  }

  bool checkUnderstanding(String query) {
    final normalizedText = _localDataRepository.normalize(query);
    return !_localDataRepository.isGibberish(query) &&
        normalizedText.length >= 2;
  }

  void handleUnderstandingError() {
    currentMessages.add(_rephraseMessage());
  }

  ChatMessage _rephraseMessage() {
    return ChatMessage(
      text:
          "Δεν μπόρεσα να καταλάβω το μήνυμά σας. "
          "Μπορείτε να το αναδιατυπώσετε;",
      type: MessageType.rephrase,
    );
  }

  void cancelProcess() {
    debugPrint("Διαδικασία AI ακυρώθηκε λόγω σφάλματος/timeout.");
  }

  void connectionProblem() {
    currentMessages.add(
      _externalAiErrorMessage(
        AiApiException(
          "Υπήρξε πρόβλημα σύνδεσης με την εξωτερική υπηρεσία AI. "
          "Δοκίμασε ξανά σε λίγο.",
          code: "connection_error",
        ),
      ),
    );
  }

  ChatMessage synthesizeResponse(
    dynamic data, {
    MessageType type = MessageType.bot,
  }) {
    return ChatMessage(text: data.toString(), type: type);
  }

  ChatMessage _externalAiErrorMessage(AiApiException error) {
    final text = switch (error.code) {
      'provider_config_missing' =>
        "Η υπηρεσία AI δεν έχει ρυθμιστεί. Έλεγξε το GEMINI_API_KEY "
            "στο functions/.env και ξανατρέξε τον emulator.",
      'invalid_api_key' =>
        "Το Gemini API key δεν είναι έγκυρο. Έλεγξε το GEMINI_API_KEY "
            "στο functions/.env.",
      'resource_exhausted' =>
        "Το Gemini API έφτασε προσωρινά το διαθέσιμο quota ή rate limit. "
            "Δοκίμασε αργότερα.",
      'invalid_request' =>
        "Το αίτημα προς το Gemini API δεν έγινε δεκτό. Έλεγξε το "
            "GEMINI_MODEL στο functions/.env.",
      'timeout' =>
        "Η εξωτερική υπηρεσία AI άργησε να απαντήσει. Δοκίμασε ξανά.",
      _ =>
        error.message.isNotEmpty
            ? error.message
            : "Υπήρξε πρόβλημα σύνδεσης με την εξωτερική υπηρεσία AI. "
                  "Δοκίμασε ξανά σε λίγο.",
    };

    return ChatMessage(text: text, type: MessageType.connectionError);
  }

  Future<void> _saveConversation(
    String query,
    ChatMessage finalResponse,
  ) async {
    if (_userId.isEmpty) {
      debugPrint("Παράλειψη αποθήκευσης συνομιλίας: δεν υπάρχει userId.");
      return;
    }

    try {
      currentChatId = await _historyRepository.saveConversation(
        userId: _userId,
        query: query,
        response: finalResponse.text,
        chatId: currentChatId,
        title: _buildSessionTitle(),
        allMessages: currentMessages,
      );
      history = await _historyRepository.fetchHistory(_userId);
    } catch (error) {
      debugPrint("Σφάλμα αποθήκευσης ιστορικού chatbot: $error");
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

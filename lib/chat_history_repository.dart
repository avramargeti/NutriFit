import 'package:cloud_firestore/cloud_firestore.dart';
import 'chatbot_models.dart';

class ChatHistoryRepository {
  ChatHistoryRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<List<ChatSession>> fetchHistory(String userId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('chatbot_history')
        .orderBy('timestamp', descending: true)
        .get();

    final sessions = <ChatSession>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      sessions.add(ChatSession(doc.id, data['title'] ?? 'Συνομιλία', []));
    }
    return sessions;
  }

  Future<List<ChatMessage>> fetchMessages(String userId, String chatId) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('chatbot_history')
        .doc(chatId)
        .get();

    if (!doc.exists) return [];
    
    final data = doc.data()!;
    final rawMessages = data['messages'];
    if (rawMessages is List) {
      return List<ChatMessage>.from(
        rawMessages.whereType<Map>().map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m))),
      );
    }
    return [];
  }

  Future<String> saveConversation({
    required String userId,
    required String query,
    required String response,
    required String? chatId,
    required String title,
    required List<ChatMessage> allMessages, // Χρησιμοποιείται για το Firebase update
  }) async {
    final data = {
      'title': title,
      'messages': allMessages.map((m) => m.toMap()).toList(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    final historyRef = _db.collection('users').doc(userId).collection('chatbot_history');

    if (chatId == null) {
      final docRef = await historyRef.add(data);
      return docRef.id;
    }

    await historyRef.doc(chatId).set(data, SetOptions(merge: true));
    return chatId;
  }
}
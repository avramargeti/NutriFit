import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chatbot_models.dart';

class ChatHistoryRepository {
  ChatHistoryRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Future<List<ChatSession>> fetchHistory() async {
    final userId = _currentUserId();
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('chatbot_history')
        .orderBy('timestamp', descending: true)
        .get();

    final sessions = <ChatSession>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final rawMessages = data['messages'];
      final messages = rawMessages is List
          ? List<ChatMessage>.from(
              rawMessages
                  .whereType<Map>()
                  .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m))),
            )
          : <ChatMessage>[];

      sessions.add(ChatSession(doc.id, data['title'] ?? 'Συνομιλία', messages));
    }

    return sessions;
  }

  Future<String> saveConversation({
    required String? chatId,
    required String title,
    required List<ChatMessage> messages,
  }) async {
    final userId = _currentUserId();
    final data = {
      'title': title,
      'messages': messages.map((m) => m.toMap()).toList(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    final historyRef = _db
        .collection('users')
        .doc(userId)
        .collection('chatbot_history');

    if (chatId == null) {
      final docRef = await historyRef.add(data);
      return docRef.id;
    }

    await historyRef.doc(chatId).set(data, SetOptions(merge: true));
    return chatId;
  }

  String _currentUserId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Απαιτείται σύνδεση χρήστη για το ιστορικό συνομιλιών.');
    }
    return user.uid;
  }
}

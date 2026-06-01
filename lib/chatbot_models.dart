enum MessageType {
  user,
  bot,
  externalAi,
  error,
  constraint,
  rephrase,
  connectionError,
}

class ChatMessage {
  final String text;
  final MessageType type;

  ChatMessage({required this.text, required this.type});

  Map<String, dynamic> toMap() => {
    'text': text,
    'type': type.name,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.bot,
      ),
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final List<ChatMessage> messages;

  ChatSession(this.id, this.title, this.messages);
}

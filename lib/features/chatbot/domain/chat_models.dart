import '../data/sign_repository.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.lookup,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;

  /// Present on assistant replies after [sendMessage].
  final SignLookupResult? lookup;
}

class ChatState {
  ChatState({required this.messages, this.isBotTyping = false});

  final List<ChatMessage> messages;
  final bool isBotTyping;
}

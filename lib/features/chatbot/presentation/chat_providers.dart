import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sign_repository.dart';
import '../domain/chat_models.dart';

final signRepositoryProvider = Provider<SignRepository>((ref) => SignRepository());

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.read(signRepositoryProvider));
});

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._repository) : super(ChatState(messages: []));

  final SignRepository _repository;

  void clear() {
    state = ChatState(messages: []);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final userMsg = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = ChatState(messages: [userMsg, ...state.messages], isBotTyping: true);

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final lookup = _repository.lookup(text);

    final botMsg = ChatMessage(
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      lookup: lookup,
    );
    state = ChatState(messages: [botMsg, ...state.messages], isBotTyping: false);
  }
}

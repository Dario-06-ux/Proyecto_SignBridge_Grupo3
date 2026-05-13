import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:detector_senas/core/theme/app_theme.dart';
import '../data/bundled_placeholder_gif.dart';
import '../data/sign_repository.dart';
import '../domain/chat_models.dart';
import 'chat_providers.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _textController = TextEditingController();

  void _handleSend() {
    ref.read(chatProvider.notifier).sendMessage(_textController.text);
    _textController.clear();
  }

  String _formatTime(DateTime time) {
    String hour = time.hour > 12 ? '${time.hour - 12}' : '${time.hour}';
    if (hour == '0') hour = '12';
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acerca de SignBridge'),
        content: const Text(
          'SignBridge AI te ayuda a explorar frases LSO de demostración con GIFs de ejemplo. '
          'En la pestaña Visión, Android puede ejecutar MediaPipe + TFLite opcional; en web e iOS la cámara es limitada o de vista previa. '
          'Añade tus propios assets según README.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.surface,
              Color.lerp(cs.surface, cs.primary, 0.04)!,
            ],
          ),
        ),
        child: Column(
          children: [
            _buildGlassAppBar(context),
            Expanded(
              child: messages.isEmpty && !chatState.isBotTyping
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: messages.length + (chatState.isBotTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (chatState.isBotTyping && index == 0) {
                          return _buildTypingIndicator(context);
                        }
                        final msgIndex = chatState.isBotTyping ? index - 1 : index;
                        return _buildMessageBubble(messages[msgIndex], context);
                      },
                    ),
            ),
            _buildInputArea(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassAppBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.82),
            border: Border(
              bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 12,
              left: 16,
              right: 4,
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.primary.withOpacity(0.45), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(Icons.smart_toy_rounded, color: cs.onPrimaryContainer, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SignBridge AI',
                        style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.15,
                              color: cs.onSurface,
                            ) ??
                            TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: 0.15,
                              color: cs.onSurface,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.tertiary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: cs.tertiary.withOpacity(0.45),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Asistente en línea',
                            style: tt.labelMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ) ??
                                TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
                  onSelected: (value) {
                    if (value == 'clear') {
                      ref.read(chatProvider.notifier).clear();
                    } else if (value == 'about') {
                      _showAbout();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'clear', child: Text('Borrar chat')),
                    PopupMenuItem(value: 'about', child: Text('Acerca de')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final samples = SignRepository.knownPhrases.join(', ');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer,
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Icon(Icons.sign_language_rounded, size: 64, color: cs.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '¡Hola! Soy tu intérprete.',
              textAlign: TextAlign.center,
              style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    height: 1.2,
                  ) ??
                  TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Escribe una frase corta y, si está en el diccionario demo, verás un GIF de ejemplo.',
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ) ??
                  TextStyle(
                    fontSize: 16,
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.55),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Prueba: $samples',
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ) ??
                      TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4, right: 48),
        child: Material(
          color: cs.surfaceContainerHigh,
          elevation: 1,
          shadowColor: Colors.black26,
          surfaceTintColor: cs.surfaceTint,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  'Traduciendo a señas…',
                  style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ) ??
                      TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: SafeArea(
        top: false,
        child: Material(
          elevation: 2,
          shadowColor: Colors.black26,
          surfaceTintColor: cs.surfaceTint,
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 6, 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.mic_none_rounded, color: cs.onSurfaceVariant),
                  tooltip: 'Entrada por voz',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('La entrada por voz no está disponible en esta versión.')),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    style: TextStyle(color: cs.onSurface, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje…',
                      hintStyle: TextStyle(color: cs.onSurfaceVariant),
                      filled: false,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                  ),
                  onPressed: _handleSend,
                  icon: const Icon(Icons.send_rounded, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, BuildContext context) {
    final isUser = message.isUser;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = AppTheme.radiusLg;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              elevation: isUser ? 2 : 0,
              shadowColor: Colors.black26,
              surfaceTintColor: isUser ? Colors.transparent : cs.surfaceTint,
              color: isUser ? cs.primary : cs.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(r),
                  topRight: Radius.circular(r),
                  bottomLeft: Radius.circular(isUser ? r : 6),
                  bottomRight: Radius.circular(isUser ? 6 : r),
                ),
                side: isUser ? BorderSide.none : BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                child: isUser ? _buildUserContent(message, context) : _buildBotContent(message, context),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUser) Icon(Icons.done_all_rounded, size: 14, color: cs.primary),
                  if (isUser) const SizedBox(width: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ) ??
                        TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserContent(ChatMessage message, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Text(
        message.text,
        style: tt.bodyLarge?.copyWith(
              color: cs.onPrimary,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ) ??
            TextStyle(
              fontSize: 16,
              color: cs.onPrimary,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  Widget _buildBotContent(ChatMessage message, BuildContext context) {
    final lookup = message.lookup;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.translate_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Traducción LSO',
                style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                      letterSpacing: 0.2,
                    ) ??
                    TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      letterSpacing: 0.2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (lookup != null && lookup.isMatch && lookup.assetPath != null)
            _buildGifBlock(context, lookup.assetPath!)
          else if (lookup != null)
            _buildUnknownPhrase(context, lookup)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildGifBlock(BuildContext context, String assetPath) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Image.asset(
            SignRepository.normalizeBundleAssetPath(assetPath),
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 180,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.memory(
                      kBundledPlaceholderGifBytes,
                      height: 120,
                      width: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Demo placeholder — add this file under assets and declare it in pubspec.yaml:\n${SignRepository.normalizeBundleAssetPath(assetPath)}',
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ) ??
                            TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Si la imagen se ve en blanco, sustituye el GIF en assets/gifs por tu propio clip.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.35) ??
              TextStyle(fontSize: 11, color: cs.onSurfaceVariant, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildUnknownPhrase(BuildContext context, SignLookupResult lookup) {
    final phrase = lookup.normalizedPhrase.isEmpty ? '…' : "'${lookup.normalizedPhrase}'";
    final hints = SignRepository.knownPhrases.map((e) => '• $e').join('\n');
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: cs.outline.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: cs.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Todavía no tengo un GIF de ejemplo para $phrase.',
                  style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ) ??
                      TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Prueba una de estas frases en el diccionario demo:',
            style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant) ??
                TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            hints,
            style: tt.bodySmall?.copyWith(
                  color: cs.onSurface,
                  height: 1.45,
                ) ??
                TextStyle(fontSize: 12, color: cs.onSurface, height: 1.45),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../services/voice_response_service.dart';
import 'animated_assistant_character.dart';
import 'chat_message.dart';

/// تب دستیار — چت با یک آواتار متحرک کوچک که انگار کارها را انجام می‌دهد.
///
/// آواتار با وضعیت لحظه‌ای هماهنگ می‌شود:
/// - گوش دادن (میکروفون فعال) → [AssistantMood.listening]
/// - در حال پردازش پاسخ → [AssistantMood.thinking]
/// - پس از انجام کار → [AssistantMood.writing] و بعد [AssistantMood.happy]
class AssistantTab extends StatefulWidget {
  const AssistantTab({
    super.key,
    required this.controller,
    required this.messages,
    required this.isTyping,
    required this.speechReady,
    required this.isListening,
    required this.lastVoiceText,
    required this.voiceStatus,
    required this.soundLevel,
    required this.voiceResponseEnabled,
    required this.assistantVoiceGender,
    required this.onAsk,
    required this.onVoiceDown,
    required this.onVoiceUp,
    required this.onVoiceResponseEnabledChanged,
    required this.onVoiceGenderChanged,
    required this.onTestVoice,
    this.assistantStatusLabel = 'هوش قانونی (بدون LLM)',
  });

  final TextEditingController controller;
  final List<ChatMessage> messages;
  final bool isTyping;
  final bool speechReady;
  final bool isListening;
  final String lastVoiceText;
  final String voiceStatus;
  final double soundLevel;
  final bool voiceResponseEnabled;
  final AssistantVoiceGender assistantVoiceGender;
  final VoidCallback onAsk;
  final VoidCallback onVoiceDown;
  final VoidCallback onVoiceUp;
  final ValueChanged<bool> onVoiceResponseEnabledChanged;
  final ValueChanged<AssistantVoiceGender> onVoiceGenderChanged;
  final VoidCallback onTestVoice;
  final String assistantStatusLabel;

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<AssistantTab> {
  final ScrollController _scroll = ScrollController();
  AssistantMood _mood = AssistantMood.idle;

  AssistantMood _computeMood() {
    if (widget.isListening) return AssistantMood.listening;
    if (widget.isTyping) {
      // در حال پردازش یک فرمان/سؤال
      final lastUser = widget.messages.isNotEmpty
          ? widget.messages.last.isUser
          : false;
      return lastUser ? AssistantMood.writing : AssistantMood.thinking;
    }
    // پس از آخرین پاسخ دستیار، لحظه‌ای happy
    final last = widget.messages.isNotEmpty ? widget.messages.last : null;
    if (last != null && !last.isUser) {
      final age = DateTime.now().difference(last.time).inSeconds;
      if (age < 4) return AssistantMood.happy;
    }
    return AssistantMood.idle;
  }

  @override
  void didUpdateWidget(covariant AssistantTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages.length != widget.messages.length ||
        oldWidget.isTyping != widget.isTyping ||
        oldWidget.isListening != widget.isListening) {
      _mood = _computeMood();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reversed = widget.messages.reversed.toList();
    final statusText = _mood == AssistantMood.listening
        ? 'دارم گوش می‌دهم...'
        : _mood == AssistantMood.thinking
            ? 'در حال فکر کردن...'
            : _mood == AssistantMood.writing
                ? 'در حال انجام کارت...'
                : _mood == AssistantMood.happy
                    ? 'انجام شد! 😊'
                    : 'سلام، من دستیارت هستم';

    return Column(
      children: [
        // ─── هدر آواتار متحرک ───
        Container(
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      // وضعیت هوش
                      _StatusChip(label: widget.assistantStatusLabel),
                      const Spacer(),
                      PopupMenuButton<String>(
                        color: Colors.white,
                        icon: const Icon(Icons.volume_up_outlined,
                            color: Colors.white),
                        tooltip: 'پاسخ صوتی',
                        onSelected: (v) {
                          if (v == 'toggle') {
                            widget.onVoiceResponseEnabledChanged(
                                !widget.voiceResponseEnabled);
                          } else if (v == 'test') {
                            widget.onTestVoice();
                          }
                        },
                        itemBuilder: (_) => [
                          CheckedPopupMenuItem(
                            value: 'toggle',
                            checked: widget.voiceResponseEnabled,
                            child: const Text('پاسخ صوتی دستیار'),
                          ),
                          const PopupMenuItem(
                              value: 'test', child: Text('تست صدا')),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // آواتار متحرک کوچک
                  SizedBox(
                    height: 150,
                    child: AnimatedAssistantCharacter(
                      mood: _mood,
                      size: 130,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      statusText,
                      key: ValueKey(statusText),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),

        // ─── لیست پیام‌ها ───
        Expanded(
          child: widget.messages.isEmpty
              ? _EmptyChat(onSuggestion: (t) {
                  widget.controller.text = t;
                  widget.onAsk();
                })
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.all(14),
                  itemCount: reversed.length + (widget.isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (widget.isTyping && index == 0) {
                      return const _TypingBubble();
                    }
                    final msg = reversed[index - (widget.isTyping ? 1 : 0)];
                    return _MessageBubble(
                      text: msg.text,
                      isUser: msg.isUser,
                    );
                  },
                ),
        ),

        // ─── نوار ورودی ───
        _InputBar(
          controller: widget.controller,
          speechReady: widget.speechReady,
          isListening: widget.isListening,
          soundLevel: widget.soundLevel,
          onAsk: widget.onAsk,
          onVoiceDown: widget.onVoiceDown,
          onVoiceUp: widget.onVoiceUp,
        ),

        if (widget.isListening && widget.lastVoiceText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
            child: Text(
              '🎤 ${widget.lastVoiceText}',
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (widget.voiceStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              widget.voiceStatus,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// حباب یک پیام در چت.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isUser});
  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor =
        isUser ? AppTheme.primary : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        isUser ? Colors.white : theme.colorScheme.onSurface;
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: SelectableText(
          text,
          style: TextStyle(color: textColor, height: 1.5),
        ),
      ),
    );
  }
}

/// حباب «در حال فکر کردن...».
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primary),
            ),
            SizedBox(width: 10),
            Text('در حال انجام...', style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

/// حالت خالی چت با پیشنهادها.
class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onSuggestion});
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const suggestions = [
      'من امروز یک میلیون پول دارم و هفته دیگه باید با دوست دخترم برم بیرون',
      'یک قرار برای هفته دیگه ست کن',
      'کار جدید: تماس با مشتری',
      'برای رسیدن به دو میلیون تا آخر ماه چقدر باید کار کنم؟',
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.waving_hand, size: 40, color: AppTheme.primary),
        const SizedBox(height: 8),
        Text(
          'چی می‌خوای امروز انجام بدم؟',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'بپرس، فرمان بده یا با صدا صحبت کن. می‌توانم کارها را زمان‌بندی کنم، '
          'موجودی را مدیریت کنم و هدف مالی روزانه‌ات را حساب کنم.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ActionChip(
              avatar: const Icon(Icons.auto_awesome,
                  size: 16, color: AppTheme.primary),
              label: Text(s, style: const TextStyle(fontSize: 12)),
              onPressed: () => onSuggestion(s),
            ),
          ),
      ],
    );
  }
}

/// نوار ورودی: میکروفون + متن + ارسال.
class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.speechReady,
    required this.isListening,
    required this.soundLevel,
    required this.onAsk,
    required this.onVoiceDown,
    required this.onVoiceUp,
  });

  final TextEditingController controller;
  final bool speechReady;
  final bool isListening;
  final double soundLevel;
  final VoidCallback onAsk;
  final VoidCallback onVoiceDown;
  final VoidCallback onVoiceUp;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  @override
  Widget build(BuildContext context) {
    final color =
        widget.isListening ? Colors.red : AppTheme.primary;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      shadowColor: Colors.black12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              // میکروفون (نگه دار تا صحبت کنی)
              GestureDetector(
                onLongPressStart:
                    widget.speechReady ? (_) => widget.onVoiceDown() : null,
                onLongPressEnd:
                    widget.speechReady ? (_) => widget.onVoiceUp() : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: widget.isListening
                        ? [
                            BoxShadow(
                              color: color.withValues(
                                  alpha: 0.25 +
                                      widget.soundLevel.abs().clamp(0, 30) / 60),
                              blurRadius:
                                  14 + widget.soundLevel.abs().clamp(0, 30),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    widget.isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // فیلد متن
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onAsk(),
                  decoration: InputDecoration(
                    hintText: 'بپرس یا فرمان بده...',
                    filled: true,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // دکمه ارسال
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: widget.onAsk,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// نشانگر وضعیت موتور هوش.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  bool get _isOnline => label.contains('آنلاین');
  bool get _isHybrid => label.contains('ترکیبی');

  @override
  Widget build(BuildContext context) {
    final color = _isOnline
        ? const Color(0xFF69F0AE)
        : _isHybrid
            ? Colors.tealAccent
            : Colors.white70;
    final icon = _isOnline
        ? Icons.cloud_done_outlined
        : _isHybrid
            ? Icons.memory
            : Icons.rule;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

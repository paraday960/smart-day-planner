import 'package:flutter/material.dart';

import '../../services/voice_response_service.dart';
import 'chat_message.dart';

/// تب دستیار — یک چت ساده مثل اپ‌های هوش مصنوعی: متن یا صدا می‌دهی، جواب می‌گیری.
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

  @override
  void didUpdateWidget(covariant AssistantTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages.length != widget.messages.length ||
        oldWidget.isTyping != widget.isTyping) {
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
    // پیام‌ها به‌صورت معکوس برای چت (جدیدترین پایین).
    final reversed = widget.messages.reversed.toList();

    return Column(
      children: [
        // نوار وضعیت هوش
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              _StatusChip(label: widget.assistantStatusLabel),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.volume_up_outlined),
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
                  const PopupMenuItem(value: 'test', child: Text('تست صدا')),
                ],
              ),
            ],
          ),
        ),

        // لیست پیام‌ها
        Expanded(
          child: widget.messages.isEmpty
              ? _EmptyChat(
                  onSuggestion: (t) {
                    widget.controller.text = t;
                    widget.onAsk();
                  },
                )
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.all(12),
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

        // نوار ورودی (میکروفون + متن + ارسال)
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
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
        isUser ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
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
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('در حال فکر کردن...'),
          ],
        ),
      ),
    );
  }
}

/// حالت خالی چت با چند پیشنهاد.
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
        const SizedBox(height: 24),
        Icon(Icons.auto_awesome, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          'سلام! من دستیار هوشمندت هستم.',
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
        const SizedBox(height: 20),
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ActionChip(
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
        widget.isListening ? Colors.red : Theme.of(context).colorScheme.primary;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: widget.isListening
                        ? [
                            BoxShadow(
                              color: color.withValues(
                                  alpha: 0.25 + widget.soundLevel.abs().clamp(0, 30) / 60),
                              blurRadius: 12 + widget.soundLevel.abs().clamp(0, 30),
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
              const SizedBox(width: 8),
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // دکمه ارسال
              IconButton.filled(
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
        ? Colors.green
        : _isHybrid
            ? Colors.teal
            : Colors.blueGrey;
    final icon = _isOnline
        ? Icons.cloud_done_outlined
        : _isHybrid
            ? Icons.memory
            : Icons.rule;
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

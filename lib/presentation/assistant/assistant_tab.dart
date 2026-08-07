import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/voice_response_service.dart';
import 'animated_assistant_character.dart';
import 'assistant_3d_viewer.dart';

class AssistantTab extends ConsumerStatefulWidget {
  const AssistantTab({super.key, 
    required this.controller,
    required this.answer,
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
  final String answer;
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
  ConsumerState<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends ConsumerState<AssistantTab> {
  AssistantMood _mood = AssistantMood.idle;

  @override
  void didUpdateWidget(covariant AssistantTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // تشخیص حالت بر اساس متن جواب
    if (widget.isListening) {
      _mood = AssistantMood.listening;
    } else if (widget.answer.contains('خودکار انجام شد') || widget.answer.contains('📒') || widget.answer.contains('ثبت شد')) {
      _mood = AssistantMood.writing;
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _mood = AssistantMood.happy);
      });
      Future.delayed(const Duration(milliseconds: 4000), () {
        if (mounted) setState(() => _mood = AssistantMood.idle);
      });
    } else if (widget.answer.contains('فکر') || widget.answer.contains('...')) {
      _mood = AssistantMood.thinking;
    } else if (widget.answer.isNotEmpty) {
      _mood = AssistantMood.happy;
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _mood = AssistantMood.idle);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // به‌روزرسانی mood بر اساس listening
    if (widget.isListening && _mood != AssistantMood.listening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _mood = AssistantMood.listening);
      });
    } else if (!widget.isListening && _mood == AssistantMood.listening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _mood = AssistantMood.idle);
      });
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // 🧑‍💼 کاراکتر زنده دستیار
        Center(
          child: Assistant3DViewer(mood: _mood, height: 240),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _mood == AssistantMood.listening ? 'دارم گوش می‌دم...' : _mood == AssistantMood.writing ? 'دارم یادداشت می‌کنم... 📒' : _mood == AssistantMood.thinking ? 'دارم فکر می‌کنم...' : _mood == AssistantMood.happy ? 'انجام شد! 😊' : 'سلام، من دستیارت هستم!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
          ),
        ),
        const SizedBox(height: 12),
        Text('دستیار فارسی', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: _AssistantStatusChip(label: widget.assistantStatusLabel),
        ),
        const SizedBox(height: 8),
        const Text('نمونه فرمان‌ها: «همه اطلاعات رو نشون بده» • «کار جدید تماس با مشتری» • «درآمد/هزینه ثبت کن» • «همه تراکنش‌ها» • «وضعیت کلی» — همه توسط دستیار 🤖'),
        const SizedBox(height: 12),
        PushToTalkCard(
          speechReady: widget.speechReady,
          isListening: widget.isListening,
          lastVoiceText: widget.lastVoiceText,
          voiceStatus: widget.voiceStatus,
          soundLevel: widget.soundLevel,
          onVoiceDown: widget.onVoiceDown,
          onVoiceUp: widget.onVoiceUp,
        ),
        const SizedBox(height: 12),
        VoiceResponseSettingsCard(
          enabled: widget.voiceResponseEnabled,
          gender: widget.assistantVoiceGender,
          onEnabledChanged: widget.onVoiceResponseEnabledChanged,
          onGenderChanged: widget.onVoiceGenderChanged,
          onTestVoice: widget.onTestVoice,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.controller,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => widget.onAsk(),
          decoration: InputDecoration(
            hintText: 'از دستیار بپرس...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: widget.onAsk,
              icon: const Icon(Icons.send),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(widget.answer.isEmpty ? 'در حال آماده‌سازی...' : widget.answer),
          ),
        ),
        const SizedBox(height: 12),
        const Card.outlined(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'نکته: همه‌چیز روی همین گوشی و بدون سرور کار می‌کند. تشخیص صوت می‌تواند برای دقت بهتر از سرویس رایگان گوشی استفاده کند. مدل زبانی محلی (llama.cpp) هم پشتیبانی می‌شود — اگر LLM فعال باشد، در بالای همین صفحه نشان داده می‌شود.',
            ),
          ),
        ),
      ],
    );
  }
}

class VoiceResponseSettingsCard extends StatelessWidget {
  const VoiceResponseSettingsCard({super.key, 
    required this.enabled,
    required this.gender,
    required this.onEnabledChanged,
    required this.onGenderChanged,
    required this.onTestVoice,
  });

  final bool enabled;
  final AssistantVoiceGender gender;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<AssistantVoiceGender> onGenderChanged;
  final VoidCallback onTestVoice;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              value: enabled,
              onChanged: onEnabledChanged,
              contentPadding: EdgeInsets.zero,
              title: const Text('پاسخ صوتی دستیار'),
              subtitle: const Text('بعد از اجرای فرمان، دستیار جواب را با صدای فارسی می‌خواند.'),
            ),
            const SizedBox(height: 8),
            Text('انتخاب صدا', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<AssistantVoiceGender>(
              segments: AssistantVoiceGender.values
                  .map((voice) => ButtonSegment(
                        value: voice,
                        label: Text(voice.faLabel),
                        icon: Icon(voice == AssistantVoiceGender.feminine ? Icons.face_3 : Icons.face),
                      ))
                  .toList(),
              selected: {gender},
              onSelectionChanged: enabled ? (value) => onGenderChanged(value.first) : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: enabled ? onTestVoice : null,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('تست صدا'),
            ),
            const SizedBox(height: 8),
            const Text(
              'صدای زن و مرد از موتور گفتار خود گوشی انتخاب می‌شود. برای صدای کاملاً ثابت و بدون وابستگی به گوشی، باید بعداً یک موتور گفتار فارسی محلی یا سرویس رایگان/اختیاری اضافه شود.',
            ),
          ],
        ),
      ),
    );
  }
}

class PushToTalkCard extends StatelessWidget {
  const PushToTalkCard({super.key, 
    required this.speechReady,
    required this.isListening,
    required this.lastVoiceText,
    required this.voiceStatus,
    required this.soundLevel,
    required this.onVoiceDown,
    required this.onVoiceUp,
  });

  final bool speechReady;
  final bool isListening;
  final String lastVoiceText;
  final String voiceStatus;
  final double soundLevel;
  final VoidCallback onVoiceDown;
  final VoidCallback onVoiceUp;

  @override
  Widget build(BuildContext context) {
    final color = isListening ? Colors.red : Theme.of(context).colorScheme.primary;
    final level = soundLevel.abs().clamp(0, 30) / 30;

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onLongPressStart: speechReady ? (_) => onVoiceDown() : null,
              onLongPressEnd: speechReady ? (_) => onVoiceUp() : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: isListening ? Colors.red.shade600 : color,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    if (isListening)
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.25 + level * 0.35),
                        blurRadius: 18 + level * 18,
                        spreadRadius: 2 + level * 6,
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 34),
                    const SizedBox(height: 8),
                    Text(
                      isListening ? 'گوش می‌دهم... دکمه را رها کن تا اجرا کنم' : 'برای فرمان صوتی نگه دار',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(voiceStatus),
            if (lastVoiceText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('تشخیص داده شد: $lastVoiceText', style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (!speechReady) ...[
              const SizedBox(height: 8),
              const Text('اگر فعال نشد، دسترسی میکروفون و زبان فارسی تشخیص گفتار را در گوشی بررسی کن.'),
            ],
          ],
        ),
      ),
    );
  }
}


/// نشانگر وضعیت موتور هوش (LLM محلی / قانونی).
class _AssistantStatusChip extends StatelessWidget {
  const _AssistantStatusChip({required this.label});

  final String label;

  bool get _isHybrid => label.contains('ترکیبی');

  @override
  Widget build(BuildContext context) {
    final color = _isHybrid ? Colors.green : Colors.blueGrey;
    final icon = _isHybrid ? Icons.memory : Icons.rule;
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

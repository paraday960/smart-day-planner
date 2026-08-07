import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/models/assistant_voice_gender.dart';
import 'package:smart_day_planner/presentation/assistant/assistant_tab.dart';
import 'package:smart_day_planner/services/voice_response_service.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    ),
  );
}

Widget _tab({String statusLabel = 'هوش قانونی (بدون LLM)'}) {
  return _wrap(
    AssistantTab(
      controller: TextEditingController(),
      messages: const [],
      isTyping: false,
      speechReady: false,
      isListening: false,
      lastVoiceText: '',
      voiceStatus: '',
      soundLevel: 0,
      voiceResponseEnabled: true,
      assistantVoiceGender: AssistantVoiceGender.feminine,
      onAsk: () {},
      onVoiceDown: () {},
      onVoiceUp: () {},
      onVoiceResponseEnabledChanged: (_) {},
      onVoiceGenderChanged: (_) {},
      onTestVoice: () {},
      assistantStatusLabel: statusLabel,
    ),
  );
}

void main() {
  testWidgets('وضعیت «هوش قانونی» در تب دستیار نمایش داده می‌شود',
      (tester) async {
    await tester.pumpWidget(_tab(statusLabel: 'هوش قانونی (بدون LLM)'));
    expect(find.text('هوش قانونی (بدون LLM)'), findsOneWidget);
  });

  testWidgets('وضعیت «هوش ترکیبی» (LLM فعال) نمایش داده می‌شود',
      (tester) async {
    await tester.pumpWidget(_tab(statusLabel: 'هوش ترکیبی (LLM محلی فعال)'));
    expect(find.text('هوش ترکیبی (LLM محلی فعال)'), findsOneWidget);
  });

  testWidgets('مقدار پیش‌فرض statusLabel «هوش قانونی» است',
      (tester) async {
    await tester.pumpWidget(_tab());
    expect(find.text('هوش قانونی (بدون LLM)'), findsOneWidget);
  });
}

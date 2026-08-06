import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/services/dialogue_memory.dart';

void main() {
  group('DialogueMemory', () {
    test('آخرین نوبت را به خاطر می‌سپارد', () {
      final memory = DialogueMemory();
      memory.remember(
          prompt: 'برنامه امروز',
          response: 'برنامه: ...',
          intent: 'today_plan');
      expect(memory.lastIntent, 'today_plan');
      expect(memory.lastPrompt, 'برنامه امروز');
      expect(memory.length, 1);
    });

    test('با خالی بودن، last برابر null است', () {
      final memory = DialogueMemory();
      expect(memory.last, isNull);
      expect(memory.lastIntent, isNull);
    });

    test('پاک‌کردن حافظه', () {
      final memory = DialogueMemory();
      memory.remember(prompt: 'a', response: 'b', intent: 'x');
      memory.clear();
      expect(memory.length, 0);
      expect(memory.last, isNull);
    });

    test('سقف نوبت‌ها (۸ تا) رعایت می‌شود', () {
      final memory = DialogueMemory();
      for (var i = 0; i < 20; i++) {
        memory.remember(prompt: 'p$i', response: 'r$i', intent: 'i$i');
      }
      expect(memory.length, 8);
      expect(memory.lastIntent, 'i19');
    });

    test('lastWas بررسی می‌کند آخرین قصد چیست', () {
      final memory = DialogueMemory();
      memory.remember(prompt: 'a', response: 'b', intent: 'repayment_plan');
      expect(memory.lastWas('repayment_plan'), isTrue);
      expect(memory.lastWas('today_plan'), isFalse);
    });
  });
}

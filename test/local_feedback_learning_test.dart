import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/services/local_feedback_learning.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IntentFeedbackStats', () {
    test('successRate خنثی وقتی داده نیست', () {
      expect(IntentFeedbackStats().successRate, 0.5);
    });
    test('successRate درست', () {
      final s = IntentFeedbackStats(success: 3, failure: 1);
      expect(s.successRate, 0.75);
      expect(s.total, 4);
    });
    test('سریال/دسریال', () {
      final s = IntentFeedbackStats(success: 2, failure: 3, ambiguity: 1, score: -1.5);
      final s2 = IntentFeedbackStats.fromJson(s.toJson());
      expect(s2.success, 2);
      expect(s2.failure, 3);
      expect(s2.score, -1.5);
    });
  });

  group('IntentFeedbackStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('موفقیت ضریب را بالا می‌برد', () {
      final s = IntentFeedbackStore(seed: 1);
      s.recordSuccess('a');
      s.recordSuccess('a');
      s.recordFailure('a');
      expect(s.isDiscouraged('a'), isFalse);
      expect(s.confidenceMultiplier('a'), greaterThan(1.0));
    });

    test('شکست مکرر دلسرد می‌کند', () {
      final s = IntentFeedbackStore(seed: 2);
      for (var i = 0; i < 5; i++) s.recordFailure('risk');
      s.recordSuccess('risk');
      expect(s.isDiscouraged('risk'), isTrue);
      expect(s.confidenceMultiplier('risk'), lessThan(1.0));
    });

    test('tieBreak موفق‌تر را برمی‌گزیند', () {
      final s = IntentFeedbackStore(seed: 1);
      s.recordSuccess('a');
      s.recordFailure('b');
      expect(s.tieBreak(['a', 'b']), 'a');
    });

    test('ذخیره و لود متقارن است', () async {
      final s = IntentFeedbackStore(seed: 1);
      s.recordSuccess('x');
      s.recordFailure('y');
      await Future.delayed(const Duration(milliseconds: 60));
      final s2 = IntentFeedbackStore(seed: 9, storageKey: s.storageKey);
      await s2.load();
      expect(s2.stats['x']!.success, 1);
      expect(s2.stats['y']!.failure, 1);
    });

    test('summary کار می‌کند', () {
      final s = IntentFeedbackStore(seed: 1);
      s.recordSuccess('today_plan');
      expect(s.summary(), contains('today_plan'));
    });
  });
}

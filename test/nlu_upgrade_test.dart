// تست‌های مستقل برای ارتقای هوش محلی.
import 'package:smart_day_planner/services/persian_nlu.dart';
import 'package:smart_day_planner/services/conversation_router.dart';
import 'package:smart_day_planner/services/local_feedback_learning.dart';
import 'package:test/test.dart';

void main() {
  group('PersianNormalizer.tokenize', () {
    test('شکستن بر اساس فاصله و نیم‌فاصله', () {
      expect(PersianNormalizer.tokenize('برنامه امروز را می‌چینم'),
          containsAll(['برنامه', 'امروز', 'را', 'میچینم']));
    });
    test('نرمال‌سازی حروف عربی', () {
      expect(PersianNormalizer.tokenize('كيف ميكني'),
          equals(['کیف', 'میکنی']));
    });
    test('حذف توکن‌های خالی', () {
      expect(PersianNormalizer.tokenize('  سلام   دنیا  '),
          equals(['سلام', 'دنیا']));
    });
  });

  group('PersianMatcher', () {
    test('hasWord کلمهٔ کامل', () {
      expect(PersianMatcher.hasWord('من کار می‌کنم', 'کار'), isTrue);
      expect(PersianMatcher.hasWord('بیکارم', 'کار'), isFalse);
    });
  });

  group('IntentDetector', () {
    const d = IntentDetector(intents: [
      NluIntent(id: 'today_plan', patterns: ['برنامه امروز', 'امروز چی کار کنم'],
          keywords: ['برنامه', 'امروز'], priority: 40),
      NluIntent(id: 'overdue', patterns: ['عقب مونده', 'عقب افتاده'],
          keywords: ['عقب'], priority: 30),
    ]);
    test('کلمات کلیدی', () {
      final m = d.detectWithScore('برنامه امروز چیه');
      expect(m?.id, 'today_plan');
      expect(m!.confidence, greaterThan(0.5));
    });
    test('نامرتبط null', () {
      expect(d.detectWithScore('سینما رفتن'), isNull);
    });
    test('عبارت قوی confidence بالا', () {
      expect(d.detectWithScore('برنامه امروز')!.confidence >= 0.8, isTrue);
    });
  });

  group('classifier/anaphora/sim', () {
    test('نوع پول/زمان', () {
      expect(PersianQuestionClassifier.classify('چقدر پول دارم'),
          QuestionType.money);
      expect(PersianQuestionClassifier.classify('کی تموم میشه'),
          QuestionType.time);
    });
    test('آنافورا', () {
      expect(AnaphoraDetector.isFollowUp('ادامه‌اش چیه'), isTrue);
      expect(AnaphoraDetector.isFollowUp('بعدش چی'), isTrue);
      expect(AnaphoraDetector.isFollowUp('سلام'), isFalse);
    });
    test('هم‌معناها', () {
      expect(
          PersianSemanticSimilarity.score('قرض فرهاد', 'بدهی فرهاد') > 0.5,
          isTrue);
    });
  });

  group('router', () {
    const intents = [
      NluIntent(id: 'today_plan', patterns: ['برنامه امروز'], priority: 40),
      NluIntent(id: 'overdue', patterns: ['عقب مونده'], priority: 30),
    ];
    test('محلی', () {
      final r = LocalAssistantRouter(
          detector: const IntentDetector(intents: intents),
          context: ConversationContext());
      final d = r.route('برنامه امروز');
      expect(d.kind, RouteKind.local);
      expect(d.intentId, 'today_plan');
    });
    test('پیگیری', () {
      final ctx = ConversationContext();
      final r = LocalAssistantRouter(
          detector: const IntentDetector(intents: intents), context: ctx);
      ctx.addUser('برنامه امروز', intentId: 'today_plan');
      final d = r.route('ادامه‌اش چیه');
      expect(d.kind, RouteKind.followUp);
      expect(d.intentId, 'today_plan');
    });
    test('خالی fallback', () {
      final r = LocalAssistantRouter(
          detector: const IntentDetector(intents: intents),
          context: ConversationContext());
      expect(r.route('   ').kind, RouteKind.fallback);
    });
  });

  group('conversation', () {
    const intents = [
      NluIntent(id: 'today_plan', patterns: ['برنامه امروز'], priority: 40),
    ];
    test('پاسخ', () async {
      final c = LocalAssistantConversation(
        router: LocalAssistantRouter(
            detector: const IntentDetector(intents: intents),
            context: ConversationContext()),
        generateForIntent: (id, _) async => 'پاسخ $id',
      );
      final r = await c.respond(text: 'برنامه امروز', tasks: const []);
      expect(r.source, 'local');
      expect(r.text, 'پاسخ today_plan');
    });
    test('پیگیری پس از intent', () async {
      final ctx = ConversationContext();
      final c = LocalAssistantConversation(
        router: LocalAssistantRouter(
            detector: const IntentDetector(intents: intents), context: ctx),
        generateForIntent: (id, _) async => 'پاسخ $id',
      );
      await c.respond(text: 'برنامه امروز', tasks: const []);
      final r = await c.respond(text: 'ادامه‌اش چیه', tasks: const []);
      expect(r.clarified, isTrue);
      expect(r.text, contains('today_plan'));
    });
  });

  group('feedback', () {
    test('موفقیت/شکست', () {
      final s = IntentFeedbackStore(seed: 1);
      s.recordSuccess('a');
      s.recordSuccess('a');
      s.recordFailure('a');
      expect(s.isDiscouraged('a'), isFalse);
      expect(s.confidenceMultiplier('a') > 1.0, isTrue);
    });
    test('دلسردی', () {
      final s = IntentFeedbackStore(seed: 1);
      for (var i = 0; i < 5; i++) {
        s.recordFailure('b');
      }
      s.recordSuccess('b');
      expect(s.isDiscouraged('b'), isTrue);
    });
    test('tieBreak و سریال', () {
      final s = IntentFeedbackStore(seed: 1);
      s.recordSuccess('a');
      s.recordFailure('b');
      expect(s.tieBreak(['a', 'b']), 'a');
      final s2 = IntentFeedbackStore(seed: 2)..loadJson(s.toJson());
      expect(s2.stats['a']!.success, 1);
    });
    test('decay', () {
      final s = IntentFeedbackStore(seed: 1, decay: 0.5);
      s.recordSuccess('z');
      final before = s.stats['z']!.score;
      s.applyDecay();
      expect(s.stats['z']!.score, lessThan(before));
    });
  });
}

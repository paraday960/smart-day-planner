import 'dart:async';

import '../models/task.dart';
import 'persian_nlu.dart';

class ConversationTurn {
  const ConversationTurn({
    required this.role,
    required this.text,
    required this.intentId,
    DateTime? at,
  }) : at = at;
  final String role;
  final String text;
  final String? intentId;
  final DateTime? at;
  bool get isUser => role == 'user';
}

class ResolvedReference {
  const ResolvedReference({required this.originalText, required this.intentId});
  final String originalText;
  final String intentId;
}

class RouteDecision {
  const RouteDecision({
    required this.kind,
    this.intentId,
    this.confidence = 0,
    this.candidates = const [],
    this.reference,
    this.clarificationQuestion,
  });
  final RouteKind kind;
  final String? intentId;
  final double confidence;
  final List<String> candidates;
  final ResolvedReference? reference;
  final String? clarificationQuestion;
}

enum RouteKind { local, clarify, followUp, fallback }

class ConversationContext {
  ConversationContext({this.maxTurns = 12});
  final int maxTurns;
  final List<ConversationTurn> _turns = [];
  List<ConversationTurn> get turns => List.unmodifiable(_turns);

  void addUser(String text, {String? intentId}) {
    _turns.add(ConversationTurn(
        role: 'user', text: text, intentId: intentId, at: DateTime.now()));
    _trim();
  }

  void addAssistant(String text, {String? intentId}) {
    _turns.add(ConversationTurn(
        role: 'assistant', text: text, intentId: intentId, at: DateTime.now()));
    _trim();
  }

  void _trim() {
    if (_turns.length > maxTurns) {
      _turns.removeRange(0, _turns.length - maxTurns);
    }
  }

  ConversationTurn? lastUserTurn() {
    for (final t in _turns.reversed) {
      if (t.isUser) return t;
    }
    return null;
  }

  ResolvedReference? resolveFollowUp(String currentText) {
    if (!AnaphoraDetector.isFollowUp(currentText)) return null;
    final last = lastUserTurn();
    if (last == null) return null;
    if (AnaphoraDetector.isFollowUp(last.text)) return null;
    return ResolvedReference(
      originalText: last.text,
      intentId: last.intentId ?? '',
    );
  }

  void clear() => _turns.clear();
}

class LocalAssistantRouter {
  LocalAssistantRouter({
    required this.detector,
    required this.context,
    this.confidenceThreshold = 0.7,
    this.ambiguityGap = 0.08,
  });

  final IntentDetector detector;
  final ConversationContext context;
  final double confidenceThreshold;
  final double ambiguityGap;

  RouteDecision route(String text) {
    if (text.trim().isEmpty) {
      return const RouteDecision(kind: RouteKind.fallback);
    }

    final followUp = context.resolveFollowUp(text);
    if (followUp != null) {
      if (followUp.intentId.isNotEmpty) {
        return RouteDecision(
            kind: RouteKind.followUp,
            intentId: followUp.intentId,
            reference: followUp);
      }
      final match = detector.detectWithScore(followUp.originalText);
      if (match != null) {
        return RouteDecision(
            kind: RouteKind.followUp,
            intentId: match.id,
            confidence: match.confidence,
            reference: followUp);
      }
      return RouteDecision(kind: RouteKind.followUp, reference: followUp);
    }

    final candidates = detector.detectCandidates(text, top: 3);
    if (candidates.isEmpty) {
      return const RouteDecision(kind: RouteKind.fallback);
    }
    final best = candidates.first;

    final raw = best.score;
    final confidence = raw >= 200
        ? 0.95
        : raw >= 100
            ? 0.8
            : raw >= 50
                ? 0.55
                : 0.35;

    if (candidates.length >= 2) {
      final denom = best.score.abs() < 1 ? 1.0 : best.score.abs();
      final gap = (best.score - candidates[1].score) / denom;
      if (gap < ambiguityGap) {
        return RouteDecision(
          kind: RouteKind.clarify,
          candidates: candidates.map((c) => c.id).toList(),
          clarificationQuestion: _clarifyText(candidates),
        );
      }
    }

    if (confidence >= confidenceThreshold) {
      return RouteDecision(
          kind: RouteKind.local,
          intentId: best.id,
          confidence: confidence);
    }
    return RouteDecision(
        kind: RouteKind.fallback,
        intentId: best.id,
        confidence: confidence);
  }

  String _clarifyText(List<IntentMatch> candidates) {
    final labels = candidates
        .take(3)
        .map((c) => _label(c.id))
        .where((s) => s.isNotEmpty)
        .toList();
    if (labels.length < 2) return 'منظورت دقیقاً چی بود؟ کمی واضح‌تر بگو.';
    if (labels.length == 2) {
      return 'منظورت «${labels[0]}» بود یا «${labels[1]}»؟';
    }
    return 'کدوم منظورت بود: ${labels.join('، ')}؟';
  }

  String _label(String id) {
    const labels = {
      'greeting': 'احوال‌پرسی',
      'next_task': 'پیشنهاد کار بعدی',
      'today_plan': 'برنامهٔ امروز',
      'week_plan': 'برنامهٔ هفته',
      'overdue': 'کارهای عقب‌افتاده',
      'risk_alerts': 'ریسک‌ها',
      'done_today': 'کارهای امروز',
      'income_forecast': 'پیش‌بینی درآمد',
      'budget_status': 'وضعیت بودجه',
      'finance_advice': 'مشاورهٔ مالی',
      'best_time': 'بهترین زمان کار',
      'catch_up': 'برنامهٔ جبران',
      'motivation': 'انگیزه',
      'repayment_plan': 'برنامهٔ پرداخت بدهی',
      'habit_analysis': 'تحلیل عادت',
      'prediction': 'پیش‌بینی',
      'habit_suggestion': 'پیشنهاد عادت',
      'brain_status': 'وضعیت کلی',
      'morning_briefing': 'بریفینگ صبح',
      'forecast_30': 'پیش‌بینی هفته',
      'weekly_forecast': 'پیش‌بینی هفتهٔ آینده',
      'feedback_positive': 'بازخورد مثبت',
      'feedback_negative': 'بازخورد منفی',
      'show_all_data': 'نمایش همهٔ داده‌ها',
      'manage_tasks': 'مدیریت کارها',
      'manage_finance': 'مدیریت مالی',
      'debt_query': 'پرسش بدهی',
      'skill_status': 'وضعیت مهارت',
      'learning_history': 'تاریخچهٔ یادگیری',
      'offline_status': 'وضعیت آفلاین',
      'small_talk': 'صحبت کوتاه',
      'help': 'راهنما',
      'thanks': 'تشکر',
      'focus_suggestion': 'پیشنهاد تمرکز',
      'reschedule': 'بازچیدن برنامه',
      'free_time': 'وقت آزاد',
      'productivity_tip': 'نکتهٔ بهره‌وری',
      'cancel_or_stop': 'توقف',
      'capability_query': 'قابلیت‌ها',
    };
    return labels[id] ?? id;
  }
}

class AssistantReply {
  const AssistantReply({
    required this.text,
    required this.source,
    this.intentId,
    this.confidence = 0,
    this.clarified = false,
  });
  final String text;
  final String source;
  final String? intentId;
  final double confidence;
  final bool clarified;
}

class LocalAssistantConversation {
  LocalAssistantConversation({
    required this.router,
    required this.generateForIntent,
  });
  final LocalAssistantRouter router;
  final FutureOr<String> Function(String intentId, List<Task> tasks)
      generateForIntent;

  Future<AssistantReply> respond({
    required String text,
    required List<Task> tasks,
  }) async {
    final decision = router.route(text);
    switch (decision.kind) {
      case RouteKind.clarify:
        router.context.addUser(text);
        final q = decision.clarificationQuestion ?? 'منظورت چی بود؟ واضح‌تر بگو.';
        router.context.addAssistant(q);
        return AssistantReply(text: q, source: 'clarification');
      case RouteKind.followUp:
        final intentId = decision.intentId;
        if (intentId == null || intentId.isEmpty) {
          const fb =
              'متوجه نشدم به چی اشاره می‌کنی. کمی واضح‌تر بگو تا کمکت کنم.';
          router.context.addUser(text);
          router.context.addAssistant(fb);
          return const AssistantReply(text: fb, source: 'clarification');
        }
        final answer = await generateForIntent(intentId, tasks);
        router.context.addUser(text, intentId: intentId);
        router.context.addAssistant(answer, intentId: intentId);
        return AssistantReply(
            text: answer,
            source: 'local',
            intentId: intentId,
            confidence: decision.confidence,
            clarified: true);
      case RouteKind.local:
        final intentId = decision.intentId!;
        final answer = await generateForIntent(intentId, tasks);
        router.context.addUser(text, intentId: intentId);
        router.context.addAssistant(answer, intentId: intentId);
        return AssistantReply(
            text: answer,
            source: 'local',
            intentId: intentId,
            confidence: decision.confidence);
      case RouteKind.fallback:
        return AssistantReply(
            text: '',
            source: 'fallback',
            intentId: decision.intentId,
            confidence: decision.confidence);
    }
  }
}

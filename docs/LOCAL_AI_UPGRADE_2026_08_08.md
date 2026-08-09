# ارتقای هوش مصنوعی محلی — ۲۰۲۶-۰۸-۰۸

ارتقای هوش محلی بدون نیاز به آنلاین یا LLM سنگین.

## افزوده‌ها

### NLU قوی‌تر (`persian_nlu.dart`)
- توکنایزر فارسی و تطبیق در سطح کلمه
- `NluIntent.keywords/requiresKeywords` و `IntentMatch.confidence`
- `detectCandidates` برای شفاف‌سازی ابهام
- `PersianQuestionClassifier` (نوع سؤال)
- `AnaphoraDetector` (پیگیری «ادامه‌اش چیه؟»)
- `PersianSemanticSimilarity` (Jaccard + هم‌معناها + بایگرام)

### مسیریاب مکالمه (جدید `conversation_router.dart`)
- `ConversationContext`، `LocalAssistantRouter`
- تصمیم: محلی / شفاف‌سازی / پیگیری / fallback
- `LocalAssistantConversation`

### یادگیری از بازخورد محلی (جدید `local_feedback_learning.dart`)
- `IntentFeedbackStore`: آمار موفقیت/شکست، ضریب اطمینان پویا، سریال‌سازی

### دستیار قانون‌محور (`local_assistant.dart`)
- `canHandle` مبتنی بر آستانهٔ اطمینان، `detectIntent`، `answerIntent`،
  `respondConversationally`
- ۶ intent جدید: تمرکز، بازچیدن برنامه، وقت آزاد، نکتهٔ بهره‌وری، توقف، قابلیت‌ها

## تست‌ها
- `test/nlu_upgrade_test.dart` (۱۶ تست مستقل)
- `test/local_assistant_upgrade_test.dart` (۹ تست فلاتری)

هیچ API موجودی تغییر شکلی نکرده است.

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/services/feedback_learning_service.dart';

void main() {
  test('detect positive', () {
    expect(FeedbackLearningService.detectFromText('خوب بود'), FeedbackType.positive);
    expect(FeedbackLearningService.detectFromText('عالی بود دمت گرم'), FeedbackType.positive);
    expect(FeedbackLearningService.detectFromText('👍'), FeedbackType.positive);
  });

  test('detect negative', () {
    expect(FeedbackLearningService.detectFromText('بد بود'), FeedbackType.negative);
    expect(FeedbackLearningService.detectFromText('به درد نخورد'), FeedbackType.negative);
    expect(FeedbackLearningService.detectFromText('مزخرف بود'), FeedbackType.negative);
  });

  test('detect neutral', () {
    expect(FeedbackLearningService.detectFromText('سلام'), FeedbackType.neutral);
  });

  test('isFeedback', () {
    expect(FeedbackLearningService.isFeedback('خوب بود'), isTrue);
    expect(FeedbackLearningService.isFeedback('سلام'), isFalse);
  });
}

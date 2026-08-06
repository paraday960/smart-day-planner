import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/services/command_confidence_service.dart';

void main() {
  group('CommandConfidenceService', () {
    test('requires confirmation for large financial amount', () {
      const service = CommandConfidenceService();

      final result = service.evaluate(
        text: 'هزینه یک میلیون تومان ثبت کن',
        intent: 'expense',
        amount: 1000000,
      );

      expect(service.shouldConfirm(result, amount: 1000000), isTrue);
    });

    test('lowers confidence for ambiguous spoken money', () {
      const service = CommandConfidenceService();

      final result = service.evaluate(
        text: 'پونصد براش کنار بذار',
        intent: 'allocation',
        amount: 500000,
      );

      expect(result.score, lessThan(0.75));
      expect(service.shouldConfirm(result, amount: 500000), isTrue);
    });
  });
}

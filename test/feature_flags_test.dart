import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/app/feature_flags.dart';

void main() {
  test('feature flags expose default release configuration', () {
    final flags = FeatureFlags.asMap();

    expect(flags.containsKey('voiceInput'), isTrue);
    expect(flags.containsKey('calendar'), isTrue);
    expect(flags.containsKey('pdfExport'), isTrue);
    expect(FeatureFlags.hasRiskyPlatformFeatureEnabled, isTrue);
  });
}

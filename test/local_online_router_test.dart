import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/services/local_online_router.dart';

void main() {
  late LocalOnlineRouter router;

  setUp(() {
    router = LocalOnlineRouter(confidenceThreshold: 0.8, maxLocalLength: 60);
  });

  test('intent قوی و کوتاه → محلی', () {
    final d = router.decide(
      text: 'برنامه امروز',
      localConfidence: 0.95,
      localCanHandle: true,
      localSuccessCount: 5,
      localFailureCount: 0,
    );
    expect(d, RouteTarget.localOnly);
  });

  test('intent با اطمینان پایین → localFirst', () {
    final d = router.decide(
      text: 'برنامه امروز چطوره',
      localConfidence: 0.55,
      localCanHandle: true,
      localSuccessCount: 10,
      localFailureCount: 1,
    );
    expect(d, RouteTarget.localFirst);
  });

  test('سؤال مالی که محلی نمی‌فهمد → آنلاین', () {
    final d = router.decide(
      text: 'چطور پس‌انداز کنم؟',
      localConfidence: null,
      localCanHandle: false,
      localSuccessCount: 0,
      localFailureCount: 0,
    );
    expect(d, RouteTarget.online);
  });

  test('شکست مکرر یک intent محلی → آنلاین', () {
    final d = router.decide(
      text: 'برنامه امروز',
      localConfidence: 0.9,
      localCanHandle: true,
      localSuccessCount: 1,
      localFailureCount: 5,
    );
    expect(d, RouteTarget.online);
  });

  test('متن خالی → محلی', () {
    final d = router.decide(
      text: '',
      localConfidence: null,
      localCanHandle: false,
      localSuccessCount: 0,
      localFailureCount: 0,
    );
    expect(d, RouteTarget.localOnly);
  });

  test('سؤال چرایی که محلی نمی‌فهمد → آنلاین', () {
    final d = router.decide(
      text: 'چرا اینقدر استرس دارم؟',
      localConfidence: null,
      localCanHandle: false,
      localSuccessCount: 0,
      localFailureCount: 0,
    );
    expect(d, RouteTarget.online);
  });
}

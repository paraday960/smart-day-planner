import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/services/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = SecurityService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> reset() async {
    await service.disablePin();
  }

  group('SecurityService: هش امن PIN', () {
    test('تنظیم PIN با هش جدید (PBKDF2) و تأیید با رمز درست', () async {
      await service.setPin('1234');
      expect(service.pinEnabled, isTrue);
      expect(await service.verifyPin('1234'), isTrue);
      expect(service.unlocked, isTrue);
      await reset();
    });

    test('رمز اشتباه تأیید نمی‌شود', () async {
      await service.setPin('1234');
      expect(await service.verifyPin('9876'), isFalse);
      expect(service.unlocked, isFalse);
      await reset();
    });

    test('هش ذخیره‌شده قالب SHA-256 hex نیست (یعنی از PBKDF2 است)', () async {
      await service.setPin('1234');
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('smart_day_planner.security.pin_hash')!;
      // خروجی PBKDF2 به‌صورت base64 ذخیره می‌شود، نه ۶۴ کاراکتر hex.
      expect(stored.length, isNot(64));
      expect(() => base64Decode(stored), returnsNormally);
      await reset();
    });

    test('قفل و باز کردن با رمز درست', () async {
      await service.setPin('1234');
      await service.lock();
      expect(service.unlocked, isFalse);
      expect(await service.verifyPin('1234'), isTrue);
      expect(service.unlocked, isTrue);
      await reset();
    });

    test('غیرفعال کردن PIN', () async {
      await service.setPin('1234');
      await service.disablePin();
      expect(service.pinEnabled, isFalse);
      expect(service.unlocked, isTrue);
    });

    test('مهاجرت: PIN قدیمی (SHA-256) با اولین ورود تأیید و به PBKDF2 ارتقا می‌شود',
        () async {
      const salt = 'legacy-salt-for-test';
      const pin = '1234';
      final legacyHash =
          sha256.convert(utf8.encode('$salt|$pin|smart_day_planner')).toString();

      SharedPreferences.setMockInitialValues({
        'smart_day_planner.security.pin_enabled': true,
        'smart_day_planner.security.pin_salt': salt,
        'smart_day_planner.security.pin_hash': legacyHash,
      });

      await service.load();
      expect(service.pinEnabled, isTrue);

      // با PIN قبلی باید باز شود (از طریق مسیر مهاجرت).
      expect(await service.verifyPin(pin), isTrue);
      expect(service.unlocked, isTrue);

      // بعد از مهاجرت، هش ذخیره‌شده باید به فرمت جدید (PBKDF2) به‌روز شود.
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('smart_day_planner.security.pin_hash')!;
      expect(stored, isNot(legacyHash));

      await reset();
    });
  });
}

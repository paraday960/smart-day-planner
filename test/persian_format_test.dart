import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/utils/persian_format.dart';

void main() {
  group('PersianFormat', () {
    test('converts English digits to Persian digits', () {
      expect(PersianFormat.digits('1234567890'), '۱۲۳۴۵۶۷۸۹۰');
    });

    test('converts Persian digits to English digits', () {
      expect(PersianFormat.englishDigits('۱۲۳۴۵۶۷۸۹۰'), '1234567890');
    });

    test('formats money in toman', () {
      expect(PersianFormat.money(1250000), '۱٬۲۵۰٬۰۰۰ تومان');
    });

    test('formats minutes', () {
      expect(PersianFormat.minutes(90), '۹۰ دقیقه');
    });
  });
}

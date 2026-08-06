import 'package:shamsi_date/shamsi_date.dart';

class PersianFormat {
  const PersianFormat._();

  static const List<String> _weekDays = [
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
    'شنبه',
    'یکشنبه',
  ];

  static const List<String> _months = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  static String digits(Object? value) {
    if (value == null) return '';
    const en = '0123456789';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    var result = value.toString();
    for (var i = 0; i < en.length; i++) {
      result = result.replaceAll(en[i], fa[i]);
    }
    return result;
  }

  static String englishDigits(String value) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var result = value;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    return result;
  }

  static String money(num value, {bool withCurrency = true}) {
    final negative = value < 0;
    final absValue = value.abs().round().toString();
    final grouped = absValue.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '٬',
    );
    final result = '${negative ? '−' : ''}${digits(grouped)}${withCurrency ? ' تومان' : ''}';
    return result;
  }

  static String minutes(int value) => '${digits(value)} دقیقه';
  static String hourRate(int value) => '${money(value)} در ساعت';

  static String time(DateTime value) {
    return '${digits(value.hour.toString().padLeft(2, '0'))}:${digits(value.minute.toString().padLeft(2, '0'))}';
  }

  static String jalaliDate(DateTime value) {
    final j = Jalali.fromDateTime(value);
    return '${digits(j.year)}/${digits(j.month.toString().padLeft(2, '0'))}/${digits(j.day.toString().padLeft(2, '0'))}';
  }

  static String jalaliDateTime(DateTime value) {
    return '${jalaliDate(value)} ساعت ${time(value)}';
  }

  static String jalaliLong(DateTime value) {
    final j = Jalali.fromDateTime(value);
    final weekDay = _weekDays[value.weekday - 1];
    final month = _months[j.month - 1];
    return '$weekDay ${digits(j.day)} $month ${digits(j.year)}، ساعت ${time(value)}';
  }

  static String todayJalali() => jalaliLong(DateTime.now());

  static String relativeDue(DateTime dueAt) {
    final now = DateTime.now();
    final diff = dueAt.difference(now);
    if (diff.inMinutes < 0) return 'عقب‌افتاده';
    if (diff.inMinutes < 60) return '${digits(diff.inMinutes)} دقیقه دیگر';
    if (diff.inHours < 24) return '${digits(diff.inHours)} ساعت دیگر';
    return '${digits(diff.inDays)} روز دیگر';
  }
}

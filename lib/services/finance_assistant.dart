import '../models/task.dart';
import '../utils/persian_format.dart';
import 'finance_repository.dart';

class FinanceAssistant {
  const FinanceAssistant();

  bool isWorkTask(Task task) {
    final text = '${task.title} ${task.category} ${task.notes}'.toLowerCase();
    const keywords = [
      'کار',
      'درآمد',
      'پروژه',
      'مشتری',
      'فروش',
      'فریلنس',
      'تدریس',
      'شیفت',
      'حقوق',
      'جلسه',
      'قرارداد',
      'سفارش',
      'work',
      'client',
      'project',
      'freelance',
    ];
    return keywords.any(text.contains);
  }

  List<String> suggestions(FinanceRepository repository) {
    final result = <String>[];
    final incomeToday = repository.incomeToday();
    final expenseToday = repository.expenseToday();
    final incomeMonth = repository.incomeThisMonth();
    final netMonth = repository.netThisMonth();
    final hourly = repository.averageHourlyRate();

    if (incomeToday == 0) {
      result.add('امروز هنوز درآمدی ثبت نشده. اگر بازه کاری داشتی، بعد از تکمیل کار مبلغش را وارد کن.');
    } else {
      result.add('درآمد امروزت ${PersianFormat.money(incomeToday)} است.');
    }

    if (expenseToday > incomeToday && expenseToday > 0) {
      result.add('هزینه امروز از درآمد امروز بیشتر شده؛ خریدهای غیرضروری را برای فردا نگه دار.');
    }

    if (hourly > 0) {
      result.add('میانگین درآمد ساعتی ثبت‌شده‌ات حدود ${PersianFormat.hourRate(hourly.round())} است؛ برای تخمین ارزش زمانت از این عدد استفاده کن.');
    }

    if (incomeMonth > 0) {
      result.add('درآمد این ماه ${PersianFormat.money(incomeMonth)} و خالص ماه ${PersianFormat.money(netMonth)} است.');
    }

    if (result.isEmpty) {
      result.add('برای شروع، درآمد و هزینه‌های روزانه را ثبت کن تا تحلیل مالی دقیق‌تر شود.');
    }

    return result.take(4).toList();
  }
}

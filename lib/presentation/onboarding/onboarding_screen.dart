import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  static const _key = 'smart_day_planner.onboarding_completed_v1';

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  void _next() {
    if (_index < 2) {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await OnboardingScreen.setCompleted();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: _finish, child: const Text('رد کردن')),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: const [
                    _OnboardPage(
                      icon: Icons.smart_toy_outlined,
                      color: Color(0xFF6C63FF),
                      title: 'سلام! من دستیار خودکارتم 🤖',
                      desc: 'همه کارها رو خودم انجام می‌دم — فقط کافیه بگی. فقط موارد حساس مثل مبالغ بالا تایید می‌خوام.',
                      hint: 'مثال: «به علی ۲ میلیون بدهکارم» → خودکار ثبت + برنامه پرداخت',
                    ),
                    _OnboardPage(
                      icon: Icons.mic_none,
                      color: Color(0xFFFF6B6B),
                      title: 'با صدا بگو، من می‌نویسم 📒',
                      desc: 'دکمه میکروفون رو نگه دار و فارسی بگو. من دفترم رو درمیارم و یادداشت می‌کنم!',
                      hint: 'امتحان کن: «کار جدید: تماس با مشتری فردا ساعت ۱۰»',
                    ),
                    _OnboardPage(
                      icon: Icons.track_changes,
                      color: Color(0xFF00BFA6),
                      title: 'هدفت چیه؟ 🎯',
                      desc: 'مغز هوشمندم از عادت‌هات یاد می‌گیره، پیش‌بینی می‌کنه و هر روز صبح برات برنامه می‌چینه.',
                      hint: 'بگو: «همه اطلاعات رو نشون بده» یا «وضعیت کلی»',
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _index == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _index == i ? const Color(0xFF6C63FF) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                )),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(_index == 2 ? 'شروع کنیم 🚀' : 'بعدی'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({required this.icon, required this.color, required this.title, required this.desc, required this.hint});
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, size: 56, color: color),
          ),
          const SizedBox(height: 24),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(desc, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Text(hint, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }
}

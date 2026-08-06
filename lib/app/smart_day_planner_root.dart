import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/onboarding/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../widgets/lock_gate.dart';
import 'app_providers.dart';

class SmartDayPlannerRoot extends ConsumerStatefulWidget {
  const SmartDayPlannerRoot({super.key});

  @override
  ConsumerState<SmartDayPlannerRoot> createState() => _SmartDayPlannerRootState();
}

class _SmartDayPlannerRootState extends ConsumerState<SmartDayPlannerRoot> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final done = await OnboardingScreen.isCompleted();
    if (mounted) setState(() => _onboardingDone = done);
  }

  void _onOnboardingDone() {
    setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (_onboardingDone == false) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: OnboardingScreen(onDone: _onOnboardingDone),
      );
    }
    final securityService = ref.watch(securityServiceProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LockGate(
        securityService: securityService,
        child: const HomeScreen(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/home_screen.dart';
import '../widgets/lock_gate.dart';
import 'app_providers.dart';

class SmartDayPlannerRoot extends ConsumerWidget {
  const SmartDayPlannerRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

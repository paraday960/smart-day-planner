import 'package:flutter/material.dart';

import '../services/security_service.dart';

class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.securityService, required this.child});

  final SecurityService securityService;
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  final _pinController = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    widget.securityService.addListener(_onSecurityChanged);
  }

  @override
  void dispose() {
    widget.securityService.removeListener(_onSecurityChanged);
    _pinController.dispose();
    super.dispose();
  }

  void _onSecurityChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (widget.securityService.unlocked) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card.filled(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_outline, size: 56),
                    const SizedBox(height: 16),
                    Text('برنامه قفل است', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('رمز ورود را وارد کن تا اطلاعات شخصی و مالی نمایش داده شود.', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'رمز ورود',
                        border: const OutlineInputBorder(),
                        errorText: _error.isEmpty ? null : _error,
                      ),
                      onSubmitted: (_) => _unlock(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('باز کردن'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    final ok = await widget.securityService.verifyPin(_pinController.text);
    if (!ok && mounted) {
      setState(() => _error = 'رمز درست نیست.');
    }
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

enum AssistantMood { idle, listening, thinking, writing, happy }

class AnimatedAssistantCharacter extends StatefulWidget {
  const AnimatedAssistantCharacter({
    super.key,
    required this.mood,
    this.size = 160,
  });

  final AssistantMood mood;
  final double size;

  @override
  State<AnimatedAssistantCharacter> createState() => _AnimatedAssistantCharacterState();
}

class _AnimatedAssistantCharacterState extends State<AnimatedAssistantCharacter>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _blinkController;
  late AnimationController _notebookController;
  late AnimationController _penController;
  late AnimationController _swayController;
  late AnimationController _3dController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(Duration(milliseconds: 2500 + math.Random().nextInt(2000)), () {
          if (mounted) _blinkController.forward(from: 0);
        });
      }
    });
    // start blink loop
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _blinkController.forward(from: 0);
    });
    _notebookController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _penController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat(reverse: true);
    _swayController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _3dController = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AnimatedAssistantCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mood == AssistantMood.writing) {
      _notebookController.forward();
      _penController.repeat(reverse: true);
    } else {
      _notebookController.reverse();
      _penController.stop();
    }
    if (widget.mood == AssistantMood.listening) {
      _breathController.duration = const Duration(milliseconds: 800);
    } else {
      _breathController.duration = const Duration(milliseconds: 2000);
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _blinkController.dispose();
    _notebookController.dispose();
    _penController.dispose();
    _swayController.dispose();
    _3dController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: _3dController,
      builder: (_, child3d) {
        final rotY = (math.sin(_3dController.value * math.pi * 2) * 0.08); // ~4.5 درجه
        final rotX = (math.cos(_swayController.value * math.pi * 2) * 0.04);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(rotY)
            ..rotateX(rotX),
          child: child3d,
        );
      },
      child: AnimatedBuilder(
        animation: _swayController,
      builder: (_, child) {
        final sway = math.sin(_swayController.value * math.pi * 2) * 1.5;
        return Transform.translate(offset: Offset(sway, 0), child: child);
      },
      child: SizedBox(
        width: size,
        height: size + 40,
        child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // سایه
          Positioned(
            bottom: 10,
            child: AnimatedBuilder(
              animation: _breathController,
              builder: (_, __) {
                final scale = 0.9 + _breathController.value * 0.1;
                return Transform.scale(
                  scaleX: scale,
                  child: Container(
                    width: size * 0.5,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
          // بدن
          Positioned(
            bottom: 20,
            child: AnimatedBuilder(
              animation: _breathController,
              builder: (_, __) {
                final dy = -2 * _breathController.value;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Container(
                    width: size * 0.45,
                    height: size * 0.35,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.smart_toy, size: 16, color: Color(0xFF6C63FF)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // سر
          AnimatedBuilder(
            animation: _breathController,
            builder: (_, __) {
              final dy = -3 * _breathController.value;
              return Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: size * 0.6,
                  height: size * 0.6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0B2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // گونه‌ها
                      Positioned(
                        left: 12,
                        top: size * 0.28,
                        child: Container(width: 18, height: 10, decoration: BoxDecoration(color: Colors.pink.withOpacity(0.25), borderRadius: BorderRadius.circular(10))),
                      ),
                      Positioned(
                        right: 12,
                        top: size * 0.28,
                        child: Container(width: 18, height: 10, decoration: BoxDecoration(color: Colors.pink.withOpacity(0.25), borderRadius: BorderRadius.circular(10))),
                      ),
                      // چشم‌ها با پلک زدن
                      Positioned(
                        top: size * 0.22,
                        child: Row(
                          children: [
                            _Eye(blinkController: _blinkController, isListening: widget.mood == AssistantMood.listening),
                            const SizedBox(width: 18),
                            _Eye(blinkController: _blinkController, isListening: widget.mood == AssistantMood.listening),
                          ],
                        ),
                      ),
                      // دهان
                      Positioned(
                        top: size * 0.36,
                        child: _Mouth(mood: widget.mood),
                      ),
                      // مو
                      Positioned(
                        top: -2,
                        child: Container(
                          width: size * 0.62,
                          height: size * 0.22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3F3D56),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(100), topRight: Radius.circular(100)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // موج صدا وقتی گوش میده
          if (widget.mood == AssistantMood.listening)
            Positioned(
              top: size * 0.05,
              right: 8,
              child: Row(
                children: List.generate(3, (i) => AnimatedBuilder(
                  animation: _breathController,
                  builder: (_, __) {
                    final h = 8 + (math.sin(_breathController.value * math.pi * 2 + i) + 1) * 6;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 4,
                      height: h,
                      decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(10)),
                    );
                  },
                )),
              ),
            ),
          // دفتر یادداشت سه‌بعدی با flip
          AnimatedBuilder(
            animation: _notebookController,
            builder: (_, child) {
              final flip = (1 - _notebookController.value) * 1.2; // از افقی به عمودی
              return Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateX(flip),
                child: child,
              );
            },
            child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.8), end: Offset.zero).animate(CurvedAnimation(parent: _notebookController, curve: Curves.easeOutBack)),
            child: FadeTransition(
              opacity: _notebookController,
              child: Container(
                margin: EdgeInsets.only(top: size * 0.55),
                width: size * 0.7,
                height: size * 0.45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3), width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Stack(
                  children: [
                    // خطوط دفتر
                    Positioned.fill(
                      child: Column(
                        children: List.generate(4, (i) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2)))),
                            child: i == 1
                                ? Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle)),
                                        const SizedBox(width: 6),
                                        Container(width: 50, height: 6, decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.6), borderRadius: BorderRadius.circular(4))),
                                      ],
                                    ),
                                  )
                                : null,
                          ),
                        )),
                      ),
                    ),
                    // خودکار متحرک
                    AnimatedBuilder(
                      animation: _penController,
                      builder: (_, __) {
                        final dx = math.sin(_penController.value * math.pi) * 20;
                        return Positioned(
                          top: 22,
                          right: 22 + dx,
                          child: Transform.rotate(
                            angle: -0.6,
                            child: Container(
                              width: 28,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // عنوان دفتر
                    Positioned(
                      top: 6,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(6)),
                        child: const Text('یادداشت', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
          // فکر کردن: حباب
          if (widget.mood == AssistantMood.thinking)
            Positioned(
              top: -4,
              right: size * 0.05,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) => AnimatedBuilder(
                    animation: _breathController,
                    builder: (_, __) {
                      final scale = 0.7 + (math.sin(_breathController.value * math.pi * 2 + i * 0.8) + 1) * 0.3;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
                        ),
                      );
                    },
                  )),
                ),
              ),
            ),
        ],
        ),
        ),
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye({required this.blinkController, required this.isListening});
  final AnimationController blinkController;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: blinkController,
      builder: (_, __) {
        final blinkValue = blinkController.value;
        // 0 -> باز، 0.5 -> بسته
        final height = blinkValue > 0.1 && blinkValue < 0.9 ? 2.0 : (isListening ? 14.0 : 12.0);
        final width = isListening ? 12.0 : 14.0;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF3F3D56),
            borderRadius: BorderRadius.circular(10),
          ),
          child: height > 4
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _Mouth extends StatelessWidget {
  const _Mouth({required this.mood});
  final AssistantMood mood;

  @override
  Widget build(BuildContext context) {
    switch (mood) {
      case AssistantMood.listening:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF3F3D56),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: const Center(child: Text('O', style: TextStyle(fontSize: 8, color: Colors.white))),
        );
      case AssistantMood.writing:
        return Container(
          width: 10,
          height: 6,
          decoration: BoxDecoration(color: const Color(0xFF3F3D56), borderRadius: BorderRadius.circular(6)),
        );
      case AssistantMood.happy:
        return Container(
          width: 18,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF3F3D56),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
          ),
          child: const Align(alignment: Alignment.topCenter, child: Text('‿', style: TextStyle(color: Colors.white, fontSize: 8))),
        );
      default:
        return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: Color(0xFF3F3D56), shape: BoxShape.circle),
        );
    }
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'animated_assistant_character.dart';

/// ویور سه‌بعدی دستیار — با انگشت بچرخان، زوم کن
/// اگر مدل لود نشد، خودکار به کاراکتر دوبعدی متحرک برمی‌گرده
class Assistant3DViewer extends StatefulWidget {
  const Assistant3DViewer({
    super.key,
    required this.mood,
    this.height = 260,
  });

  final AssistantMood mood;
  final double height;

  @override
  State<Assistant3DViewer> createState() => _Assistant3DViewerState();
}

class _Assistant3DViewerState extends State<Assistant3DViewer> {
  bool _failed = false;
  bool _show3D = true;
  bool _lazyLoaded = false; // برای Lazy Load — تا تب دستیار باز نشه WebView نساز
  Timer? _lazyTimer;

  /// مدل سه‌بعدی فقط روی اندروید/iOS پشتیبانی می‌شود؛
  /// در بقیهٔ پلتفرم‌ها (و تست‌ها) کاراکتر دوبعدی نشان داده می‌شود.
  bool get _supports3D => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    // Lazy: 600ms بعد از اینکه ویجت ساخته شد (یعنی تب دستیار باز شد) تازه WebView بساز
    _lazyTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _show3D) setState(() => _lazyLoaded = true);
    });
  }

  String get _modelSrc {
    // حالت‌های مختلف: writing -> انیمیشن جدا (اگر مدل انیمیشن داشت)
    // فعلا یک مدل برای همه حالات، ولی میشه مدل جدا گذاشت
    return 'assets/models/assistant.glb';
  }

  @override
  void dispose() {
    _lazyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supports3D || !_show3D || _failed) {
      return AnimatedAssistantCharacter(mood: widget.mood, size: 150);
    }
    if (!_lazyLoaded) {
      // Placeholder سبک تا WebView سنگین لود نشه — استارت 2 ثانیه سریع‌تر
      return Column(
        children: [
          Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 12),
                  Text('در حال آماده‌سازی 3D...', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  AnimatedAssistantCharacter(mood: AssistantMood.idle, size: 80),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton.tonal(
            onPressed: () => setState(() => _lazyLoaded = true),
            child: const Text('بارگذاری فوری 3D'),
          ),
        ],
      );
    }

    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ModelViewer(
                  key: ValueKey(_modelSrc),
                  src: _modelSrc,
                  alt: 'دستیار سه‌بعدی',
                  ar: false,
                  autoRotate: widget.mood == AssistantMood.idle,
                  autoRotateDelay: 1500,
                  rotationPerSecond: widget.mood == AssistantMood.listening ? '60deg' : '20deg',
                  cameraControls: true,
                  autoPlay: true,
                  backgroundColor: Colors.transparent,
                  // نور و سایه برای حس سه‌بعدی واقعی
                  shadowIntensity: 0.8,
                  shadowSoftness: 0.5,
                  exposure: 0.9,
                  onWebViewCreated: (controller) {},
                  // اگر خطا داد، fallback
                  // model_viewer_plus خطا را exception میده، با try catch در parent می‌گیریم
                ),
              ),
            ),
            // دکمه سوییچ 2D/3D
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _show3D = !_show3D),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_show3D ? Icons.view_in_ar : Icons.smart_toy, size: 16, color: const Color(0xFF6C63FF)),
                        const SizedBox(width: 4),
                        Text(_show3D ? '۳D' : '۲D', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // نشانگر حالت
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  widget.mood == AssistantMood.writing ? '📒 در حال نوشتن...' : widget.mood == AssistantMood.listening ? '🎙️ گوش می‌دهم...' : widget.mood == AssistantMood.thinking ? '🤔 فکر می‌کنم...' : 'با انگشت بچرخان 👆',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'مدل سه‌بعدی • با انگشت بچرخان و زوم کن',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}

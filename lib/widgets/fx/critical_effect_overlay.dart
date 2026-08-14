import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/settings_provider.dart';
import '../../services/haptic_service.dart';

enum CritEffectType { critSuccess, critFumble }

/// Controller to trigger critical hit or fumble canvas effects
class CriticalEffectController {
  _CriticalEffectOverlayState? _state;
  void _attach(_CriticalEffectOverlayState state) => _state = state;
  void _detach() => _state = null;

  void trigger(CritEffectType type) => _state?.trigger(type);
}

/// Canvas overlay that renders radiant golden embers (Nat 20) or chaotic rumble + blood embers (Nat 1)
class CriticalEffectOverlay extends StatefulWidget {
  final Widget child;
  final CriticalEffectController controller;

  const CriticalEffectOverlay({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<CriticalEffectOverlay> createState() => _CriticalEffectOverlayState();
}

class _Particle {
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double size = 0;
  double alpha = 1.0;
}

class _CriticalEffectOverlayState extends State<CriticalEffectOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  CritEffectType _activeType = CritEffectType.critSuccess;
  final List<_Particle> _particlePool = List.generate(40, (_) => _Particle());
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    widget.controller._detach();
    _animController.dispose();
    super.dispose();
  }

  void trigger(CritEffectType type) {
    bool areCritAllowed = true;
    try {
      areCritAllowed = SettingsScope.of(context).settings.areCritFxAllowed;
    } catch (_) {}

    if (!areCritAllowed) return;

    _activeType = type;
    _spawnParticles();
    _animController.forward(from: 0.0);

    if (type == CritEffectType.critSuccess) {
      HapticService.critRumble(context);
    } else {
      HapticService.heavyImpact(context);
    }
  }

  void _spawnParticles() {
    for (final p in _particlePool) {
      p.x = 0.5 + (_rng.nextDouble() - 0.5) * 0.4;
      p.y = 0.5 + (_rng.nextDouble() - 0.5) * 0.2;
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.25 + _rng.nextDouble() * 0.65;
      p.vx = cos(angle) * speed;
      p.vy = sin(angle) * speed - (_activeType == CritEffectType.critSuccess ? 0.35 : 0.0);
      p.size = 3.0 + _rng.nextDouble() * 5.0;
      p.alpha = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemDisableAnimations = MediaQuery.disableAnimationsOf(context);
    bool areCritAllowed = !systemDisableAnimations;
    try {
      areCritAllowed = areCritAllowed && SettingsScope.of(context).settings.areCritFxAllowed;
    } catch (_) {}

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final isAnimating = _animController.isAnimating && areCritAllowed;
        final progress = _animController.value;
        final isFumble = _activeType == CritEffectType.critFumble;

        // Spring-damped screen shake for Critical Fumbles (disabled when animations are disabled)
        final shakeDecay = (1.0 - progress);
        final dx = (isAnimating && isFumble && !systemDisableAnimations) ? sin(progress * 35) * 10.0 * shakeDecay : 0.0;
        final dy = (isAnimating && isFumble && !systemDisableAnimations) ? cos(progress * 28) * 6.0 * shakeDecay : 0.0;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Stack(
            children: [
              child!,
              if (isAnimating)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _CritParticlePainter(
                          particles: _particlePool,
                          progress: progress,
                          type: _activeType,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _CritParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final CritEffectType type;
  final Paint _paint = Paint()..isAntiAlias = true;

  _CritParticlePainter({
    required this.particles,
    required this.progress,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isCrit = type == CritEffectType.critSuccess;
    final baseColor = isCrit ? const Color(0xFFFFD54F) : const Color(0xFFFF5252);

    // Radiant screen boundary flash
    final flashAlpha = ((1.0 - progress) * 0.3).clamp(0.0, 1.0);
    if (flashAlpha > 0) {
      _paint.color = baseColor.withValues(alpha: flashAlpha);
      _paint.style = PaintingStyle.stroke;
      _paint.strokeWidth = 8;
      canvas.drawRect(Offset.zero & size, _paint);
    }

    // Particle render pass (zero memory allocation)
    _paint.style = PaintingStyle.fill;
    for (final p in particles) {
      final currentX = (p.x + p.vx * progress * 0.35) * size.width;
      final currentY = (p.y + p.vy * progress * 0.35) * size.height;
      final alpha = ((1.0 - progress) * p.alpha).clamp(0.0, 1.0);

      _paint.color = baseColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(currentX, currentY), p.size * (1.0 - progress * 0.4), _paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CritParticlePainter oldDelegate) => true;
}

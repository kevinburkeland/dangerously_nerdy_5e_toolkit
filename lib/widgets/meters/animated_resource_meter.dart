import 'package:flutter/material.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Dynamic animated resource meter with fluid width interpolation and low-resource pulse alerts
class AnimatedResourceMeter extends StatefulWidget {
  final int currentValue;
  final int maxValue;
  final String label;
  final Color fillColor;
  final Color? lowResourceColor;
  final double height;
  final Widget? trailing;

  const AnimatedResourceMeter({
    super.key,
    required this.currentValue,
    required this.maxValue,
    required this.label,
    required this.fillColor,
    this.lowResourceColor,
    this.height = 18,
    this.trailing,
  });

  @override
  State<AnimatedResourceMeter> createState() => _AnimatedResourceMeterState();
}

class _AnimatedResourceMeterState extends State<AnimatedResourceMeter> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final systemDisableAnimations = MediaQuery.disableAnimationsOf(context);
    final performanceMode = SettingsScope.maybeOf(context)?.settings.performanceMode ?? false;

    if (systemDisableAnimations || performanceMode) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    } else {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final systemDisableAnimations = MediaQuery.disableAnimationsOf(context);
    final performanceMode = SettingsScope.of(context).settings.performanceMode;
    final tabletop = Theme.of(context).extension<TabletopColors>();
    final ratio = widget.maxValue > 0 ? (widget.currentValue / widget.maxValue).clamp(0.0, 1.0) : 0.0;
    final isCritical = ratio <= 0.25 && widget.currentValue > 0;
    final activeColor = isCritical ? (widget.lowResourceColor ?? tabletop?.fumbleRed ?? Colors.red) : widget.fillColor;

    final semanticDescription =
        '${widget.label}: ${widget.currentValue} of ${widget.maxValue}${isCritical ? ", Warning: Low resource critical alert" : ""}. ${(ratio * 100).toInt()} percent remaining.';

    return Semantics(
      label: semanticDescription,
      value: '${widget.currentValue}',
      maxValue: '${widget.maxValue}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              widget.trailing ??
                  Text(
                    '${widget.currentValue} / ${widget.maxValue}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: isCritical ? activeColor.withValues(alpha: 0.6) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.height / 2),
              child: Stack(
                children: [
                  AnimatedFractionallySizedBox(
                    duration: systemDisableAnimations ? Duration.zero : const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    widthFactor: ratio,
                    alignment: Alignment.centerLeft,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final opacity = (!performanceMode && !systemDisableAnimations && isCritical)
                            ? _pulseAnimation.value
                            : 1.0;
                        return Opacity(
                          opacity: opacity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [activeColor.withValues(alpha: 0.75), activeColor],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

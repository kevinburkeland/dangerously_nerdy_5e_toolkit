import 'package:flutter/material.dart';
import '../../providers/settings_provider.dart';
import '../../services/rules/dnd_5e_rules_engine.dart';
import '../../theme/app_theme.dart';

/// Dynamic animated resource meter with fluid width interpolation and low-resource pulse alerts
class AnimatedResourceMeter extends StatefulWidget {
  final int currentValue;
  final int maxValue;
  final int tempValue;
  final String label;
  final Color fillColor;
  final Color? lowResourceColor;
  final Color? tempResourceColor;
  final double lowResourceThreshold;
  final bool enableLowResourceAlert;
  final double height;
  final Widget? trailing;

  const AnimatedResourceMeter({
    super.key,
    required this.currentValue,
    required this.maxValue,
    this.tempValue = 0,
    required this.label,
    required this.fillColor,
    this.lowResourceColor,
    this.tempResourceColor,
    this.lowResourceThreshold = 0.25,
    this.enableLowResourceAlert = true,
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
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AnimatedResourceMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentValue != widget.currentValue ||
        oldWidget.maxValue != widget.maxValue ||
        oldWidget.tempValue != widget.tempValue ||
        oldWidget.enableLowResourceAlert != widget.enableLowResourceAlert ||
        oldWidget.lowResourceThreshold != widget.lowResourceThreshold) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final systemDisableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final performanceMode = SettingsScope.settingsOf(context, listen: false).performanceMode;
    final effectiveCurrent = widget.currentValue > widget.maxValue ? widget.maxValue : widget.currentValue;
    final ratio = effectiveCurrent.ratioOf(widget.maxValue);
    final isCritical = widget.enableLowResourceAlert &&
        ratio <= widget.lowResourceThreshold &&
        widget.currentValue > 0;

    if (systemDisableAnimations || performanceMode || !isCritical) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 1.0;
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
    final performanceMode = SettingsScope.settingsOf(context).performanceMode;
    final tabletop = Theme.of(context).extension<TabletopColors>();
    final excessTemp = (widget.currentValue > widget.maxValue ? widget.currentValue - widget.maxValue : 0) +
        (widget.tempValue > 0 ? widget.tempValue : 0);
    final effectiveCurrent = widget.currentValue > widget.maxValue ? widget.maxValue : widget.currentValue;
    final ratio = effectiveCurrent.ratioOf(widget.maxValue);
    final totalTempRatio =
        ((effectiveCurrent + excessTemp) / (widget.maxValue <= 0 ? 1 : widget.maxValue)).clamp(0.0, 1.0);
    final effectiveTempColor = widget.tempResourceColor ?? tabletop?.tempHpCyan ?? const Color(0xFF18FFFF);

    final isCritical = widget.enableLowResourceAlert &&
        ratio <= widget.lowResourceThreshold &&
        widget.currentValue > 0;
    final activeColor = isCritical
        ? (widget.lowResourceColor ?? tabletop?.fumbleRed ?? const Color(0xFFFF5252))
        : widget.fillColor;

    final semanticDescription =
        '${widget.label}: $effectiveCurrent of ${widget.maxValue}${excessTemp > 0 ? ", plus $excessTemp temporary hit points" : ""}${isCritical ? ", Warning: Low resource critical alert" : ""}. ${(ratio * 100).toInt()} percent remaining.';

    return Semantics(
      label: semanticDescription,
      value: '$effectiveCurrent',
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
                    excessTemp > 0
                        ? '$effectiveCurrent / ${widget.maxValue} (+$excessTemp TEMP)'
                        : '${widget.currentValue} / ${widget.maxValue}',
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
                  if (excessTemp > 0)
                    AnimatedFractionallySizedBox(
                      duration: systemDisableAnimations ? Duration.zero : const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      widthFactor: totalTempRatio,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: effectiveTempColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
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

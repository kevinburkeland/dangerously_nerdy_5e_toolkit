import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';

/// Interactive card wrapper providing smooth 60/120fps spring scaling on press and haptic feedback
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double pressedScale;
  final Color? color;
  final ShapeBorder? shape;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.pressedScale = 0.97,
    this.color,
    this.shape,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
      HapticService.lightImpact(context);
    }
  }

  void _handleTapUp(TapUpDetails _) => _controller.reverse();
  void _handleTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null || widget.onLongPress != null;

    final card = Card(
      color: widget.color,
      shape: widget.shape,
      margin: widget.margin ?? EdgeInsets.zero,
      child: Padding(
        padding: widget.padding ?? const EdgeInsets.all(12),
        child: widget.child,
      ),
    );

    if (!isInteractive) return card;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: card,
      ),
    );
  }
}

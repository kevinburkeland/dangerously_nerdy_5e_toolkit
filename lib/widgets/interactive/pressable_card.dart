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
  final String? semanticLabel;
  final String? semanticHint;
  final bool? excludeChildSemantics;
  final bool isButton;

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
    this.semanticLabel,
    this.semanticHint,
    this.excludeChildSemantics,
    this.isButton = true,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isFocused = false;

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
    final theme = Theme.of(context);
    final isInteractive = widget.onTap != null || widget.onLongPress != null;
    final shouldExcludeChildSemantics = widget.excludeChildSemantics ?? (widget.semanticLabel != null);

    ShapeBorder effectiveShape = widget.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    if (_isFocused) {
      effectiveShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary, width: 2.5),
      );
    }

    final card = Card(
      color: widget.color,
      shape: effectiveShape,
      margin: widget.margin ?? EdgeInsets.zero,
      child: Padding(
        padding: widget.padding ?? const EdgeInsets.all(12),
        child: widget.child,
      ),
    );

    if (!isInteractive) {
      if (widget.semanticLabel != null) {
        return Semantics(
          label: widget.semanticLabel,
          hint: widget.semanticHint,
          excludeSemantics: shouldExcludeChildSemantics,
          container: true,
          child: card,
        );
      }
      return card;
    }

    final interactiveWidget = InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
      },
      borderRadius: BorderRadius.circular(16),
      focusColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: card,
      ),
    );

    return Semantics(
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      button: widget.isButton,
      enabled: isInteractive,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      container: true,
      excludeSemantics: shouldExcludeChildSemantics,
      explicitChildNodes: !shouldExcludeChildSemantics,
      child: interactiveWidget,
    );
  }
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_theme.dart';

class AppSpring {
  const AppSpring._();

  static const double stiffness = 400;
  static const double damping = 28;
  static const double mass = 1;

  static const description = SpringDescription(
    mass: mass,
    stiffness: stiffness,
    damping: damping,
  );

  static const Curve curve = _SpringTimingCurve(
    stiffness: stiffness,
    damping: damping,
    mass: mass,
  );
}

class LaunchFade extends StatefulWidget {
  const LaunchFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.08),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<LaunchFade> createState() => _LaunchFadeState();
}

class _LaunchFadeState extends State<LaunchFade> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : widget.offset,
      duration: AppRoutesDuration.value,
      curve: AppSpring.curve,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: AppRoutesDuration.value,
        curve: AppSpring.curve,
        child: widget.child,
      ),
    );
  }
}

class AppRoutesDuration {
  const AppRoutesDuration._();

  static const value = Duration(milliseconds: 220);
}

class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    required this.borderRadius,
    required this.color,
    this.sigma = 20,
    this.borderColor,
    this.boxShadow = const [],
  });

  final Widget child;
  final double borderRadius;
  final Color color;
  final double sigma;
  final Color? borderColor;
  final List<BoxShadow> boxShadow;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final primaryAnimation = route?.animation;
    final transitionRoute = route is TransitionRoute<dynamic> ? route : null;
    final secondaryAnimation = transitionRoute?.secondaryAnimation;
    final listeners = <Listenable>[?primaryAnimation, ?secondaryAnimation];
    if (listeners.isEmpty) {
      return _buildGlass(sigma);
    }
    return AnimatedBuilder(
      animation: Listenable.merge(listeners),
      builder: (context, _) {
        final routeIsAnimating =
            (primaryAnimation != null &&
                primaryAnimation.status != AnimationStatus.completed) ||
            (secondaryAnimation != null && secondaryAnimation.value > 0.001);
        return _buildGlass(routeIsAnimating ? 0 : sigma);
      },
    );
  }

  Widget _buildGlass(double effectiveSigma) {
    final content = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.3),
        ),
        boxShadow: boxShadow,
      ),
      child: child,
    );
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: effectiveSigma <= 0
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveSigma,
                  sigmaY: effectiveSigma,
                ),
                child: content,
              ),
      ),
    );
  }
}

class _SpringTimingCurve extends Curve {
  const _SpringTimingCurve({
    required this.stiffness,
    required this.damping,
    required this.mass,
  });

  final double stiffness;
  final double damping;
  final double mass;

  @override
  double transformInternal(double t) {
    final normalized = t.clamp(0.0, 1.0);
    final dampingRatio = damping / (2 * math.sqrt(stiffness * mass));
    if (dampingRatio >= 1) {
      return Curves.easeOut.transform(normalized);
    }
    final angularFrequency = math.sqrt(stiffness / mass);
    final dampedFrequency =
        angularFrequency * math.sqrt(1 - dampingRatio * dampingRatio);
    final time = normalized * 0.5;
    final envelope = math.exp(-dampingRatio * angularFrequency * time);
    final oscillation =
        math.cos(dampedFrequency * time) +
        (dampingRatio / math.sqrt(1 - dampingRatio * dampingRatio)) *
            math.sin(dampedFrequency * time);
    return (1 - envelope * oscillation).clamp(0.0, 1.0);
  }
}

class SpringTap extends StatefulWidget {
  const SpringTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = AppRadii.card,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;

  @override
  State<SpringTap> createState() => _SpringTapState();
}

class _SpringTapState extends State<SpringTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _animateTo(double target) {
    _controller.animateWith(
      SpringSimulation(AppSpring.description, _controller.value, target, 0),
    );
  }

  void _pressDown(TapDownDetails _) => _animateTo(0.97);

  void _pressUp([Object? _]) => _animateTo(1);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _enabled ? _pressDown : null,
      onTapUp: _enabled ? _pressUp : null,
      onTapCancel: _enabled ? _pressUp : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onLongPressEnd: _enabled ? _pressUp : null,
      child: ScaleTransition(scale: _controller, child: widget.child),
    );
  }
}

class IconTap extends StatefulWidget {
  const IconTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = AppRadii.pill,
  });

  static const double pressedScale = 0.82;
  static const opacityPulseDuration = Duration(milliseconds: 180);
  static const spring = SpringDescription(mass: 1, stiffness: 500, damping: 22);

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;

  @override
  State<IconTap> createState() => _IconTapState();
}

class _IconTapState extends State<IconTap> with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _opacityController;
  late final Animation<double> _opacity;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController.unbounded(vsync: this, value: 1);
    _opacityController = AnimationController(
      vsync: this,
      duration: IconTap.opacityPulseDuration,
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0.6), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 1), weight: 1),
    ]).animate(_opacityController);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  void _animateScale(double target) {
    _scaleController.animateWith(
      SpringSimulation(IconTap.spring, _scaleController.value, target, 0),
    );
  }

  void _pressDown(TapDownDetails _) {
    _animateScale(IconTap.pressedScale);
    _opacityController.forward(from: 0);
  }

  void _pressUp([Object? _]) => _animateScale(1);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? _pressDown : null,
      onTapUp: _enabled ? _pressUp : null,
      onTapCancel: _enabled ? _pressUp : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onLongPressEnd: _enabled ? _pressUp : null,
      child: ScaleTransition(
        scale: _scaleController,
        child: FadeTransition(opacity: _opacity, child: widget.child),
      ),
    );
  }
}

class PillIconButton extends StatelessWidget {
  const PillIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final button = IconTap(
      onTap: onPressed,
      borderRadius: AppRadii.pill,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? tokens.primaryTint.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Icon(icon, color: color ?? tokens.primary, size: 22),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

class FigmaStatusChip extends StatelessWidget {
  const FigmaStatusChip({
    super.key,
    required this.statusLabel,
    required this.color,
  });

  final String statusLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: AppSpring.curve,
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        statusLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

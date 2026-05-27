import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../animation/motion_constants.dart';
import '../theme/app_theme.dart';

// ── Spring constants (backward compat + derived curves) ────────────

class AppSpring {
  const AppSpring._();

  static const double stiffness = 380;
  static const double damping = 26;
  static const double mass = 1;

  static const description = AppMotion.defaultSpring;

  static const Curve curve = SpringTimingCurve(
    stiffness: stiffness,
    damping: damping,
    mass: mass,
  );

  /// Curve derived from [AppMotion.softSpring] for large element entrances.
  static const Curve softCurve = SpringTimingCurve(
    stiffness: 260,
    damping: 22,
    mass: 1,
  );

  /// Curve derived from [AppMotion.snappySpring] for micro-interactions.
  static const Curve snappyCurve = SpringTimingCurve(
    stiffness: 500,
    damping: 30,
    mass: 1,
  );

  /// Curve derived from [AppMotion.listSpring] for card entrances.
  static const Curve listCurve = SpringTimingCurve(
    stiffness: 260,
    damping: 22,
    mass: 1,
  );

  /// Curve derived from [AppMotion.gapSpring] for card removal gap closure.
  static const Curve gapCurve = SpringTimingCurve(
    stiffness: 260,
    damping: 22,
    mass: 1,
  );
}

// ── LaunchFade — spring-driven entrance ────────────────────────────

class LaunchFade extends StatefulWidget {
  const LaunchFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.translateY = AppMotion.launchFadeOffset,
  });

  final Widget child;
  final Duration delay;

  /// Vertical offset in logical pixels (not fractional).
  final double translateY;

  @override
  State<LaunchFade> createState() => _LaunchFadeState();
}

class _LaunchFadeState extends State<LaunchFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 0);
    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        _controller.animateWith(
          SpringSimulation(AppMotion.softSpring, 0, 1, 0),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.translateY * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ── SpringScaleIn — spring-driven scale entrance ──────────────────

class SpringScaleIn extends StatefulWidget {
  const SpringScaleIn({
    super.key,
    required this.child,
    this.from = AppMotion.emptyStateFromScale,
    this.spring = AppMotion.softSpring,
    this.delay = Duration.zero,
  });

  final Widget child;
  final double from;
  final SpringDescription spring;
  final Duration delay;

  @override
  State<SpringScaleIn> createState() => _SpringScaleInState();
}

class _SpringScaleInState extends State<SpringScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 0);
    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        _controller.animateWith(
          SpringSimulation(widget.spring, 0, 1, 0),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value.clamp(0.0, 1.0);
        final scale = widget.from + (1.0 - widget.from) * t;
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: widget.child,
    );
  }
}

// ── Transition-aware duration constant ─────────────────────────────

class SpringSwitcher extends StatefulWidget {
  const SpringSwitcher({
    super.key,
    required this.child,
    this.offset = 18,
    this.spring = AppMotion.defaultSpring,
  });

  final Widget child;
  final double offset;
  final SpringDescription spring;

  @override
  State<SpringSwitcher> createState() => _SpringSwitcherState();
}

class _SpringSwitcherState extends State<SpringSwitcher>
    with TickerProviderStateMixin {
  late Widget _current;
  Widget? _previous;
  late final AnimationController _incoming;
  late final AnimationController _outgoing;

  @override
  void initState() {
    super.initState();
    _current = widget.child;
    _incoming = AnimationController.unbounded(vsync: this, value: 1);
    _outgoing = AnimationController.unbounded(vsync: this, value: 0);
  }

  @override
  void didUpdateWidget(SpringSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.key == widget.child.key) {
      _current = widget.child;
      return;
    }
    _previous = _current;
    _current = widget.child;
    _incoming.animateWith(SpringSimulation(widget.spring, 0, 1, 0));
    _outgoing.animateWith(SpringSimulation(widget.spring, 1, 0, 0));
  }

  @override
  void dispose() {
    _incoming.dispose();
    _outgoing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (_previous != null)
            AnimatedBuilder(
              animation: _outgoing,
              builder: (context, child) {
                final t = _outgoing.value.clamp(0.0, 1.0);
                if (t == 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _previous = null);
                  });
                }
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, widget.offset * (1 - t)),
                    child: child,
                  ),
                );
              },
              child: _previous,
            ),
          AnimatedBuilder(
            animation: _incoming,
            builder: (context, child) {
              final t = _incoming.value.clamp(0.0, 1.0);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, widget.offset * (1 - t)),
                  child: child,
                ),
              );
            },
            child: _current,
          ),
        ],
      ),
    );
  }
}

class AppRoutesDuration {
  const AppRoutesDuration._();

  static const value = Duration(milliseconds: 220);
}

// ── FrostedGlass — transition-aware backdrop blur ──────────────────

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

  static bool shouldDisableBlur({
    required AnimationStatus? primaryStatus,
    required AnimationStatus? secondaryStatus,
    required double secondaryValue,
  }) {
    final primaryActive =
        primaryStatus == AnimationStatus.forward ||
        primaryStatus == AnimationStatus.reverse;
    final secondaryActive =
        secondaryStatus == AnimationStatus.forward ||
        secondaryStatus == AnimationStatus.reverse ||
        secondaryValue > 0.001;
    return primaryActive || secondaryActive;
  }

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
        final disableBlur = shouldDisableBlur(
          primaryStatus: primaryAnimation?.status,
          secondaryStatus: secondaryAnimation?.status,
          secondaryValue: secondaryAnimation?.value ?? 0,
        );
        return _buildGlass(disableBlur ? 0 : sigma);
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

// ── SpringTimingCurve — spring physics as a Curve ──────────────────

class SpringTimingCurve extends Curve {
  const SpringTimingCurve({
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
      // Over-damped: no oscillation, fall back to smooth ease-out.
      final angularFrequency = math.sqrt(stiffness / mass);
      final time = normalized * 0.6;
      return (1 - (1 + angularFrequency * time) *
          math.exp(-angularFrequency * time)).clamp(0.0, 1.0);
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

// ── SpringTap — spring-driven press scale for cards/surfaces ───────

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
      SpringSimulation(AppMotion.snappySpring, _controller.value, target, 0),
    );
  }

  void _pressDown(TapDownDetails _) =>
      _animateTo(AppMotion.buttonPressScale); // 0.96

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

// ── IconTap — spring scale + opacity pulse for icon buttons ────────

class IconTap extends StatefulWidget {
  const IconTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = AppRadii.pill,
  });

  static const double pressedScale = AppMotion.iconPressScale; // 0.96
  static const opacityPulseDuration = Duration(milliseconds: 180);
  static const spring =
      SpringDescription(mass: 1, stiffness: 500, damping: 30);

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

// ── PillIconButton — standard icon action button ───────────────────

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

// ── SectionCard — elevated surface container ───────────────────────

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

// ── FigmaStatusChip — spring-driven status indicator ───────────────

class FigmaStatusChip extends StatefulWidget {
  const FigmaStatusChip({
    super.key,
    required this.statusLabel,
    required this.color,
  });

  final String statusLabel;
  final Color color;

  @override
  State<FigmaStatusChip> createState() => _FigmaStatusChipState();
}

class _FigmaStatusChipState extends State<FigmaStatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Color _oldColor;
  late Color _newColor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 1);
    _oldColor = widget.color;
    _newColor = widget.color;
  }

  @override
  void didUpdateWidget(FigmaStatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _oldColor = oldWidget.color;
      _newColor = widget.color;
      _controller.animateWith(
        SpringSimulation(AppMotion.defaultSpring, 0, 1, 0),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value.clamp(0.0, 1.0);
        final color = Color.lerp(_oldColor, _newColor, t) ?? _newColor;
        return Container(
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
            widget.statusLabel,
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        );
      },
    );
  }
}

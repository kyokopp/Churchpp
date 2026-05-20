import 'package:flutter/physics.dart';

/// Centralized motion language for the entire app.
///
/// Every animation derives its physics from these constants.
/// Springs are tuned to feel liquid, weighted, and physically alive.
/// Larger elements use softer springs; micro-interactions use stiffer ones.
class AppMotion {
  const AppMotion._();

  // ── Default spring ── most transitions & general UI reactions
  static const defaultSpring = SpringDescription(
    mass: 1.0,
    stiffness: 380,
    damping: 26,
  );

  // ── Snappy spring ── button taps, icon presses, micro-interactions
  static const snappySpring = SpringDescription(
    mass: 1.0,
    stiffness: 500,
    damping: 30,
  );

  // ── Soft spring ── large elements entering / leaving the screen
  static const softSpring = SpringDescription(
    mass: 1.0,
    stiffness: 200,
    damping: 22,
  );

  // ── List spring ── card entrance stagger animations
  static const listSpring = SpringDescription(
    mass: 1.0,
    stiffness: 280,
    damping: 24,
  );

  // ── Liquid spring ── flowing indicator glides, tab switching
  static const liquidSpring = SpringDescription(
    mass: 1.0,
    stiffness: 400,
    damping: 28,
  );

  // ── Calm spring ── serene, focused transitions (pulpit mode)
  static const calmSpring = SpringDescription(
    mass: 1.0,
    stiffness: 180,
    damping: 20,
  );

  // ── Gap spring ── card removal height collapse
  static const gapSpring = SpringDescription(
    mass: 1.0,
    stiffness: 260,
    damping: 22,
  );

  // ── Stagger offsets (ms) ──
  static const int cardStaggerMs = 30;
  static const int sectionStaggerMs = 40;
  static const int dockDelayMs = 60;

  // ── Scale targets ──
  static const double buttonPressScale = 0.96;
  static const double iconPressScale = 0.82;
  static const double cardPressScale = 0.96;
  static const double fabPulseMin = 0.92;
  static const double fabPulseMax = 1.08;
  static const double emptyStateFromScale = 0.88;

  // ── Pixel offsets ──
  static const double cardEntranceOffset = 24.0;
  static const double launchFadeOffset = 24.0;
}

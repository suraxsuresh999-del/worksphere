import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Reusable page wrapper that applies a premium entry animation (fade-in & slide-up)
/// to the page content when it loads.
class WsAnimatedPage extends StatelessWidget {
  final Widget child;

  const WsAnimatedPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _WsPageBackdrop(),
        RepaintBoundary(
          child: child
              .animate()
              .fadeIn(duration: 420.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.025,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              )
              .scale(
                begin: const Offset(.985, .985),
                end: const Offset(1, 1),
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
      ],
    );
  }
}

/// A calm, layered blue canvas used behind every routed screen. It is kept
/// separate from individual pages so forms, lists and dashboards all feel like
/// part of one visual system.
class _WsPageBackdrop extends StatelessWidget {
  const _WsPageBackdrop();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF0B1220), Color(0xFF111C2E), Color(0xFF0F172A)]
              : const [Color(0xFFFFFFFF), Color(0xFFEAF8FF), Color(0xFFF8FDFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: _GlowOrb(
              size: 280,
              color: isDark ? const Color(0x1A55C8F5) : const Color(0x3355C8F5),
            ),
          ),
          Positioned(
            top: 260,
            left: -145,
            child: _GlowOrb(
              size: 260,
              color: isDark ? const Color(0x1266CC35) : const Color(0x1F66CC35),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

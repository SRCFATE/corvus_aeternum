import 'dart:async';

import 'package:flutter/material.dart';

class CorvusPageTransition extends StatelessWidget {
  final String pageKey;
  final Widget child;

  const CorvusPageTransition({
    super.key,
    required this.pageKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(pageKey),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, animatedChild) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(8 * (1 - value), 10 * (1 - value)),
          child: animatedChild,
        ),
      ),
    );
  }
}

class CorvusReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  const CorvusReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.beginOffset = const Offset(0, 14),
  });

  @override
  State<CorvusReveal> createState() => _CorvusRevealState();
}

class _CorvusRevealState extends State<CorvusReveal> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          _visible ? 0 : widget.beginOffset.dx,
          _visible ? 0 : widget.beginOffset.dy,
          0,
        ),
        child: widget.child,
      ),
    );
  }
}

class CorvusHoverLift extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final double lift;

  const CorvusHoverLift({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 1.012,
    this.lift = 3,
  });

  @override
  State<CorvusHoverLift> createState() => _CorvusHoverLiftState();
}

class _CorvusHoverLiftState extends State<CorvusHoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final active = _hovered && !reduceMotion;
    return MouseRegion(
      cursor:
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: active ? widget.scale : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform:
                Matrix4.translationValues(0, active ? -widget.lift : 0, 0),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

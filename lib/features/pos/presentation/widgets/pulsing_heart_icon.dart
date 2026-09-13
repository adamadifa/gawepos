import 'package:flutter/material.dart';

/// Widget animasi halus nafas lembut (Smooth Breathing / Fade In - Fade Out)
/// Efek sangat elegan, santai, dan tidak menyilaukan mata
class PulsingHeartIcon extends StatefulWidget {
  final double size;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;

  const PulsingHeartIcon({
    super.key,
    this.size = 22,
    this.color = const Color(0xFFEF4444),
    this.onTap,
    this.tooltip,
  });

  @override
  State<PulsingHeartIcon> createState() => _PulsingHeartIconState();
}

class _PulsingHeartIconState extends State<PulsingHeartIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    // Durasi lembut dan rileks (2.2 detik per siklus bolak-balik)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Skala sangat halus (1.0 -> 1.08)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    // Fade in / Fade out lembut (0.65 -> 1.0)
    _opacityAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );
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
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: widget.onTap != null
                ? IconButton(
                    icon: Icon(Icons.favorite_rounded, color: widget.color, size: widget.size),
                    tooltip: widget.tooltip,
                    onPressed: widget.onTap,
                  )
                : Icon(Icons.favorite_rounded, color: widget.color, size: widget.size),
          ),
        );
      },
    );
  }
}

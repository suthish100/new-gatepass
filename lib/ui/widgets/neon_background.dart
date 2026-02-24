import 'package:flutter/material.dart';

class NeonBackground extends StatefulWidget {
  const NeonBackground({super.key, required this.child});

  final Widget child;

  @override
  State<NeonBackground> createState() => _NeonBackgroundState();
}

class _NeonBackgroundState extends State<NeonBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat(reverse: true);

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
        final progress = _controller.value;

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + progress, -1),
              end: Alignment(1, 1 - progress),
              colors: const <Color>[
                Color(0xFF050912),
                Color(0xFF0B1240),
                Color(0xFF0A3A42),
                Color(0xFF1B0836),
              ],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -120,
                right: -80,
                child: _GlowOrb(size: 260, color: const Color(0x552D7BFF)),
              ),
              Positioned(
                bottom: -120,
                left: -90,
                child: _GlowOrb(size: 230, color: const Color(0x6616F5C6)),
              ),
              Positioned(
                top: 260,
                left: 140,
                child: _GlowOrb(size: 180, color: const Color(0x44FF4FC7)),
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: <BoxShadow>[
          BoxShadow(color: color, blurRadius: 60, spreadRadius: 12),
        ],
      ),
    );
  }
}

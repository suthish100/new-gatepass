import 'package:flutter/material.dart';

class NeonButton extends StatefulWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      child: SizedBox(
        width: widget.fullWidth ? double.infinity : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF2D7BFF), Color(0xFF16F5C6)],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x662D7BFF),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ElevatedButton.icon(
            style:
                ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 18,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: borderRadius),
                ).copyWith(
                  overlayColor: WidgetStateProperty.all(
                    Colors.white.withValues(alpha: 0.15),
                  ),
                ),
            onPressed: widget.onPressed,
            onHover: (hovered) {
              setState(() {
                _pressed = hovered;
              });
            },
            icon: widget.icon == null
                ? const SizedBox.shrink()
                : Icon(widget.icon, size: 18),
            label: Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

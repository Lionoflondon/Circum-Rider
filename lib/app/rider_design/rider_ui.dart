import 'dart:ui';

import 'package:flutter/material.dart';

abstract final class RiderPalette {
  static const background = Color(0xFF07090F);
  static const panel = Color(0xFF0D111C);
  static const blue = Color(0xFF3B82F6);
  static const paper = Color(0xFFF5F7FB);
  static const muted = Color(0xFF9CA8B8);
  static const green = Color(0xFF34D399);
  static const amber = Color(0xFFF5A623);
  static const red = Color(0xFFF87171);
  static const purple = Color(0xFFA78BFA);
}

class RiderGlassCard extends StatelessWidget {
  const RiderGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: RiderPalette.panel.withOpacity(.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(.09)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 28,
                  offset: Offset(0, 14)),
            ],
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return card;
    return Semantics(
        button: true,
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: card));
  }
}

class RiderStatusBadge extends StatelessWidget {
  const RiderStatusBadge(this.label,
      {super.key, this.color = RiderPalette.blue});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.14),
          border: Border.all(color: color.withOpacity(.42)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class RiderMoney extends StatelessWidget {
  const RiderMoney(this.value, {super.key, this.label, this.size = 32});
  final String value;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: RiderPalette.paper,
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'OpenSans')),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(label!,
                style:
                    const TextStyle(color: RiderPalette.muted, fontSize: 13)),
          ],
        ],
      );
}

class RiderSectionTitle extends StatelessWidget {
  const RiderSectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: RiderPalette.paper,
                    fontSize: 22,
                    fontWeight: FontWeight.w700))),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ]);
}

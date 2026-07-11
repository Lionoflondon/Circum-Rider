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

abstract final class RiderTypography {
  static const heading = 'DM Serif Display';
  static const body = 'Inter';
  static const mono = 'JetBrains Mono';
}

class RiderMobileFrame extends StatelessWidget {
  const RiderMobileFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF04060A),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ColoredBox(color: RiderPalette.background, child: child),
          ),
        ),
      );
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

class RiderPrimaryButton extends StatelessWidget {
  const RiderPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.color = RiderPalette.blue,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton.icon(
          onPressed: busy ? null : onPressed,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
          label: Text(label,
              style: const TextStyle(
                  fontFamily: RiderTypography.body,
                  fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withOpacity(.35),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}

class RiderEmptyState extends StatelessWidget {
  const RiderEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => RiderGlassCard(
        child: Column(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: RiderPalette.blue.withOpacity(.12),
              border: Border.all(color: RiderPalette.blue.withOpacity(.25)),
            ),
            child: Icon(icon, color: RiderPalette.blue),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.heading,
                fontSize: 20,
              )),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: RiderPalette.muted,
                  fontFamily: RiderTypography.body,
                  height: 1.4)),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      );
}

class RiderRankProgress extends StatelessWidget {
  const RiderRankProgress({
    super.key,
    required this.rank,
    required this.trustPoints,
  });

  final String rank;
  final int trustPoints;

  static const _ranks = ['Agent', 'Sentinel', 'Warden', 'Knight', 'Veteran'];
  static const _thresholds = [0, 100, 300, 700, 1500];

  @override
  Widget build(BuildContext context) {
    var index = _ranks
        .indexWhere((item) => item.toLowerCase() == rank.trim().toLowerCase());
    if (index < 0) index = 0;
    final current = _thresholds[index];
    final next =
        index == _ranks.length - 1 ? _thresholds.last : _thresholds[index + 1];
    final progress = index == _ranks.length - 1
        ? 1.0
        : ((trustPoints - current) / (next - current)).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        RiderStatusBadge(_ranks[index].toUpperCase(),
            color: _rankColor(_ranks[index])),
        const Spacer(),
        Text('$trustPoints TRUST',
            style: const TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.mono,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 11),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 5,
          backgroundColor: Colors.white.withOpacity(.07),
          color: _rankColor(_ranks[index]),
        ),
      ),
      const SizedBox(height: 7),
      Text(
        index == _ranks.length - 1
            ? 'Highest Rider rank achieved'
            : '${(next - trustPoints).clamp(0, next)} points to ${_ranks[index + 1]}',
        style: const TextStyle(
            color: RiderPalette.muted,
            fontFamily: RiderTypography.body,
            fontSize: 11),
      ),
    ]);
  }

  static Color _rankColor(String rank) => switch (rank) {
        'Sentinel' => RiderPalette.blue,
        'Warden' => RiderPalette.green,
        'Knight' => RiderPalette.purple,
        'Veteran' => RiderPalette.amber,
        _ => RiderPalette.muted,
      };
}

class RiderMetric extends StatelessWidget {
  const RiderMetric({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.075)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.mono,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: RiderPalette.muted,
                  fontFamily: RiderTypography.body,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

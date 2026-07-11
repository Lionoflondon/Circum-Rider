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

class RiderGlassSurface extends StatelessWidget {
  const RiderGlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.opacity = .64,
    this.blur = 20,
    this.borderColor,
    this.edgeColor = RiderPalette.blue,
    this.width,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double opacity;
  final double blur;
  final Color? borderColor;
  final Color edgeColor;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final effectiveBlur = reduceMotion ? blur * .55 : blur;
    final clampedOpacity = opacity.clamp(.50, .82).toDouble();
    final shape = BorderRadius.circular(radius);
    final content = ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: effectiveBlur,
          sigmaY: effectiveBlur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .105),
                RiderPalette.panel.withValues(alpha: clampedOpacity),
                const Color(0xFF050814).withValues(alpha: clampedOpacity + .08),
              ],
              stops: const [0, .42, 1],
            ),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: .16),
            ),
            boxShadow: [
              BoxShadow(
                color: edgeColor.withValues(alpha: .18),
                blurRadius: 34,
                spreadRadius: -8,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: .32),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Container(
            width: width,
            padding: padding,
            foregroundDecoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.white.withValues(alpha: .10),
                  Colors.white.withValues(alpha: .012),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          child: content,
        ),
      ),
    );
  }
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
    final card = RiderGlassSurface(
      padding: padding,
      radius: 22,
      opacity: .66,
      onTap: onTap,
      child: child,
    );
    if (onTap == null) return card;
    return card;
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
          color: color.withValues(alpha: .14),
          border: Border.all(color: color.withValues(alpha: .42)),
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
            disabledBackgroundColor: color.withValues(alpha: .35),
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
              color: RiderPalette.blue.withValues(alpha: .12),
              border:
                  Border.all(color: RiderPalette.blue.withValues(alpha: .25)),
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
          backgroundColor: Colors.white.withValues(alpha: .07),
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
          color: Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .075)),
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

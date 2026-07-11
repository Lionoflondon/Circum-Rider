import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../rider_account/rider_account_state.dart';
import '../rider_design/rider_ui.dart';

class RiderGuideView extends StatefulWidget {
  const RiderGuideView({
    super.key,
    required this.authenticated,
    this.progress,
    this.onGetStarted,
    this.onSignIn,
    this.onContinue,
    this.onClose,
  });

  static const viewedPreferenceKey = 'circum_rider_intro_viewed';

  final bool authenticated;
  final RiderApprovalProgress? progress;
  final VoidCallback? onGetStarted;
  final VoidCallback? onSignIn;
  final VoidCallback? onContinue;
  final VoidCallback? onClose;

  static Future<bool> hasViewedIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(viewedPreferenceKey) ?? false;
  }

  static Future<void> markIntroViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(viewedPreferenceKey, true);
  }

  @override
  State<RiderGuideView> createState() => _RiderGuideViewState();
}

class _RiderGuideViewState extends State<RiderGuideView> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const slides = _slides;
    return Scaffold(
      backgroundColor: const Color(0xFF04060A),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(38),
                child: Stack(
                  children: [
                    Positioned.fill(child: _GuideBackground(page: _page)),
                    Column(
                      children: [
                        _GuideTopBar(
                          authenticated: widget.authenticated,
                          onClose: _close,
                          onSkip: () => _goTo(slides.length - 1),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _controller,
                            onPageChanged: (value) =>
                                setState(() => _page = value),
                            itemCount: slides.length,
                            itemBuilder: (context, index) {
                              return _GuideSlide(slide: slides[index]);
                            },
                          ),
                        ),
                        if (widget.authenticated && widget.progress != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                            child: RiderGuideProgressCard(
                              progress: widget.progress!,
                              compact: true,
                            ),
                          ),
                        _GuideFooter(
                          page: _page,
                          count: slides.length,
                          authenticated: widget.authenticated,
                          onNext: _next,
                          onGetStarted: _getStarted,
                          onSignIn: _signIn,
                          onContinue: _continue,
                          onClose: _close,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markViewed() => RiderGuideView.markIntroViewed();

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _goTo(_page + 1);
      return;
    }
    widget.authenticated ? _continue() : _getStarted();
  }

  Future<void> _getStarted() async {
    await _markViewed();
    widget.onGetStarted?.call();
  }

  Future<void> _signIn() async {
    await _markViewed();
    widget.onSignIn?.call();
  }

  Future<void> _continue() async {
    await _markViewed();
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      _close();
    }
  }

  Future<void> _close() async {
    await _markViewed();
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }
}

class RiderGuideProgressCard extends StatelessWidget {
  const RiderGuideProgressCard({
    super.key,
    required this.progress,
    this.compact = false,
  });

  final RiderApprovalProgress progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Account created', progress.accountCreated),
      ('Phone verified', progress.phoneVerified),
      ('Identity and documents', progress.documentsSubmitted),
      ('Vehicle details', progress.vehicleDetails),
      ('Roth wallet setup', progress.rothWalletSetup),
      ('Payout setup', progress.payoutSetup),
      ('Application submitted', progress.applicationSubmitted),
      ('Admin review', progress.underReview),
      ('Approved', progress.approved),
    ];
    return _GuideGlass(
      padding: EdgeInsets.all(compact ? 14 : 16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application progress',
            style: TextStyle(
              color: RiderPalette.paper,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items.take(compact ? 5 : items.length))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    item.$2
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: item.$2 ? RiderPalette.green : RiderPalette.muted,
                    size: 17,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        color:
                            item.$2 ? RiderPalette.paper : RiderPalette.muted,
                        fontSize: compact ? 11.5 : 12.5,
                        fontWeight: item.$2 ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (compact && items.length > 5)
            const Text(
              'Open the guide to see every application step.',
              style: TextStyle(color: RiderPalette.muted, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class RiderGuideEntryCard extends StatelessWidget {
  const RiderGuideEntryCard({
    super.key,
    required this.onTap,
    this.progress,
    this.compact = false,
  });

  final VoidCallback onTap;
  final RiderApprovalProgress? progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final approved = progress?.approved == true;
    return _GuideGlass(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? 14 : 16),
      radius: compact ? 18 : 20,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: RiderPalette.blue.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.explore_outlined,
                color: RiderPalette.blue, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rider Guide',
                  style: TextStyle(
                    color: RiderPalette.paper,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  approved
                      ? 'Learn how Circum Rider works.'
                      : 'Track your application and learn how Rider works.',
                  style: const TextStyle(
                    color: RiderPalette.muted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: RiderPalette.muted),
        ],
      ),
    );
  }
}

class _GuideFooter extends StatelessWidget {
  const _GuideFooter({
    required this.page,
    required this.count,
    required this.authenticated,
    required this.onNext,
    required this.onGetStarted,
    required this.onSignIn,
    required this.onContinue,
    required this.onClose,
  });

  final int page;
  final int count;
  final bool authenticated;
  final VoidCallback onNext;
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;
  final VoidCallback onContinue;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final last = page == count - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              count,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: index == page ? 22 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3.5),
                decoration: BoxDecoration(
                  color: index == page
                      ? RiderPalette.blue
                      : Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: authenticated
                  ? (last ? onContinue : onNext)
                  : (last ? onGetStarted : onNext),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                authenticated
                    ? (last ? 'Continue to Rider app' : 'Continue')
                    : (last ? 'Get started' : 'Continue'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: RiderPalette.blue,
                foregroundColor: Colors.white,
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (authenticated)
            TextButton(
              onPressed: onClose,
              child: const Text('Close guide'),
            )
          else
            TextButton(
              onPressed: onSignIn,
              child: const Text('Already have an account? Sign in'),
            ),
        ],
      ),
    );
  }
}

class _GuideTopBar extends StatelessWidget {
  const _GuideTopBar({
    required this.authenticated,
    required this.onClose,
    required this.onSkip,
  });

  final bool authenticated;
  final VoidCallback onClose;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
        child: Row(
          children: [
            if (authenticated || Navigator.canPop(context))
              _RoundButton(
                icon: Icons.close_rounded,
                label: 'Close Rider Guide',
                onTap: onClose,
              )
            else
              const SizedBox(width: 44),
            const Spacer(),
            TextButton(
              onPressed: authenticated ? onClose : onSkip,
              child: Text(authenticated ? 'Close' : 'Skip'),
            ),
          ],
        ),
      );
}

class _GuideSlide extends StatelessWidget {
  const _GuideSlide({required this.slide});

  final _GuideSlideData slide;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: _GuideIllustration(slide: slide))),
            Text(
              slide.eyebrow,
              style: const TextStyle(
                color: RiderPalette.blue,
                fontFamily: RiderTypography.mono,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              slide.title,
              style: const TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.heading,
                fontSize: 30,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              slide.body,
              style: const TextStyle(
                color: RiderPalette.muted,
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (slide.bullets.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final bullet in slide.bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_rounded,
                          color: RiderPalette.blue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bullet,
                          style: const TextStyle(
                            color: RiderPalette.paper,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
}

class _GuideIllustration extends StatelessWidget {
  const _GuideIllustration({required this.slide});

  final _GuideSlideData slide;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        height: 220,
        child: CustomPaint(painter: _GuideIllustrationPainter(slide)),
      );
}

class _GuideIllustrationPainter extends CustomPainter {
  _GuideIllustrationPainter(this.slide);

  final _GuideSlideData slide;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final color = slide.color;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: .28);
    canvas.drawCircle(center, size.width * .42, ring);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * .34));
    canvas.drawCircle(center, size.width * .34, glow);

    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 106, height: 72),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..color = const Color(0xFF0D111C).withValues(alpha: .82)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(card, ring..color = color.withValues(alpha: .5));

    final line = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = color.withValues(alpha: .8);
    canvas.drawLine(
        center.translate(-30, -12), center.translate(30, -12), line);
    canvas.drawLine(center.translate(-30, 4), center.translate(16, 4), line);
    canvas.drawLine(center.translate(-30, 20), center.translate(2, 20), line);

    final badge = Paint()..color = color.withValues(alpha: .18);
    canvas.drawCircle(center.translate(46, -50), 16, badge);
    canvas.drawCircle(
        center.translate(46, -50),
        16,
        Paint()
          ..color = color.withValues(alpha: .8)
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _GuideIllustrationPainter oldDelegate) =>
      oldDelegate.slide != slide;
}

class _GuideBackground extends StatelessWidget {
  const _GuideBackground({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final colors = [
      RiderPalette.blue,
      RiderPalette.purple,
      RiderPalette.green,
      RiderPalette.amber,
    ];
    final color = colors[page.clamp(0, colors.length - 1)];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RiderPalette.background,
        gradient: RadialGradient(
          center: const Alignment(-.65, -.9),
          radius: 1.3,
          colors: [
            color.withValues(alpha: .30),
            RiderPalette.background,
            const Color(0xFF04060A),
          ],
          stops: const [0, .52, 1],
        ),
      ),
    );
  }
}

class _GuideGlass extends StatelessWidget {
  const _GuideGlass({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0D111C).withValues(alpha: .68),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: .09)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .055),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .09)),
            ),
            child: Icon(icon, color: RiderPalette.paper),
          ),
        ),
      );
}

class _GuideSlideData {
  const _GuideSlideData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.color,
    this.bullets = const [],
  });

  final String eyebrow;
  final String title;
  final String body;
  final Color color;
  final List<String> bullets;
}

const _slides = [
  _GuideSlideData(
    eyebrow: 'CIRCUM RIDER',
    title: 'Work on your own schedule.',
    body:
        "Go online when you're ready. Circum surfaces eligible jobs near you and you choose what to accept.",
    color: RiderPalette.blue,
  ),
  _GuideSlideData(
    eyebrow: 'TRUST & RANK',
    title: 'Every delivery builds your rank.',
    body:
        'From Agent to Veteran, trust points unlock priority jobs, higher-value work, and better visibility across the marketplace.',
    color: RiderPalette.purple,
  ),
  _GuideSlideData(
    eyebrow: 'CASH EARNINGS',
    title: 'Get paid straight to your bank.',
    body:
        "Track every delivery, tip, and adjustment in real time, then withdraw whenever you're ready through the approved payout flow.",
    color: RiderPalette.green,
  ),
  _GuideSlideData(
    eyebrow: 'ROTH WALLET',
    title: 'Roth is separate from Rider cash.',
    body:
        'A Rider Roth wallet is created or connected during onboarding for supported Circum rewards and services.',
    color: RiderPalette.amber,
    bullets: [
      'Roth cannot be withdrawn to a bank account.',
      'Roth is not wages, delivery earnings, tips, or pending cash.',
      'Roth uses its own server-authorised wallet ledger.',
    ],
  ),
];

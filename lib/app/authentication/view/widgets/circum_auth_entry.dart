import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CircumAuthEntry extends StatelessWidget {
  const CircumAuthEntry({
    super.key,
    required this.controller,
    required this.valid,
    required this.loading,
    required this.onChanged,
    required this.onContinue,
    required this.onGoogle,
    required this.onApple,
    required this.onQr,
    this.error,
  });

  final TextEditingController controller;
  final bool valid;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onQr;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF07090F),
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth >= 720 ? 32.0 : 18.0;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 42,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 476),
                        child: AnimatedSlide(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          offset: Offset.zero,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _CircumMark(),
                              const SizedBox(height: 24),
                              _AuthGlassCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      "What's your phone number\nor email?",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'OpenSans',
                                        fontSize: 31,
                                        height: 1.08,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    Semantics(
                                      textField: true,
                                      label: 'Phone number or email',
                                      child: TextField(
                                        key: const Key(
                                          'circum_auth_identifier',
                                        ),
                                        controller: controller,
                                        enabled: !loading,
                                        onChanged: onChanged,
                                        autofillHints: const [
                                          AutofillHints.email,
                                          AutofillHints.telephoneNumber,
                                        ],
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: valid && !loading
                                            ? (_) => onContinue()
                                            : null,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Enter phone number or email',
                                          errorText: error,
                                          filled: true,
                                          fillColor: const Color(
                                            0xFF0C1320,
                                          ).withOpacity(.92),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 17,
                                                vertical: 18,
                                              ),
                                          border: _border(
                                            Colors.white.withOpacity(.14),
                                          ),
                                          enabledBorder: _border(
                                            Colors.white.withOpacity(.14),
                                          ),
                                          focusedBorder: _border(
                                            const Color(0xFF5B8CFF),
                                          ),
                                          errorBorder: _border(
                                            const Color(0xFFF87171),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      height: 56,
                                      child: FilledButton(
                                        key: const Key('circum_auth_continue'),
                                        onPressed: valid && !loading
                                            ? onContinue
                                            : null,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF3B82F6,
                                          ),
                                          disabledBackgroundColor: const Color(
                                            0xFF24344E,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: loading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Text(
                                                'Continue',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 19,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Divider(
                                              color: Color(0x24FFFFFF),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 13,
                                            ),
                                            child: Text(
                                              'or',
                                              style: TextStyle(
                                                color: Color(0xFFAAB4C3),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Divider(
                                              color: Color(0x24FFFFFF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _ProviderButton(
                                      label: 'Continue with Google',
                                      icon: SvgPicture.asset(
                                        'assets/svg/google_logo.svg',
                                        width: 19,
                                        height: 19,
                                      ),
                                      onPressed: loading ? null : onGoogle,
                                    ),
                                    const SizedBox(height: 10),
                                    _ProviderButton(
                                      label: 'Continue with Apple',
                                      icon: SvgPicture.asset(
                                        'assets/svg/apple_logo.svg',
                                        width: 19,
                                        height: 19,
                                      ),
                                      onPressed: loading ? null : onApple,
                                    ),
                                    const SizedBox(height: 10),
                                    _ProviderButton(
                                      label: 'Log in with QR code',
                                      icon: const Icon(
                                        Icons.qr_code_2_rounded,
                                        color: Colors.white,
                                        size: 21,
                                      ),
                                      onPressed: loading ? null : onQr,
                                    ),
                                    const SizedBox(height: 18),
                                    const Text(
                                      'You consent to receive a verification code by text or WhatsApp.\nMessage and data rates may apply.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF9CA8B8),
                                        fontSize: 11,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'CIRCUM  •  ROTHCROSS',
                                style: TextStyle(
                                  color: Color(0xFF718096),
                                  fontSize: 10,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color),
  );
}

class _AuthGlassCard extends StatelessWidget {
  const _AuthGlassCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(26),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: const Color(0xD90D1420),
          border: Border.all(color: const Color(0x3D8FA8FF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x382D69FF),
              blurRadius: 46,
              offset: Offset(0, 20),
            ),
          ],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x1F6EA8FF), Color(0x0FA78BFA), Color(0x050D1420)],
          ),
        ),
        child: child,
      ),
    ),
  );
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0x2EFFFFFF)),
        backgroundColor: const Color(0x0DFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );
}

class _CircumMark extends StatelessWidget {
  const _CircumMark();
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      CircleAvatar(
        radius: 24,
        backgroundColor: Color(0xFF101B2E),
        child: Icon(Icons.route_rounded, color: Color(0xFF6C9DFF), size: 25),
      ),
      SizedBox(height: 9),
      Text(
        'CIRCUM',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          letterSpacing: 3.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(-.75, -.92),
        radius: 1.25,
        colors: [Color(0x553B82F6), Color(0x182E66C4), Color(0x0007090F)],
        stops: [0, .42, 1],
      ),
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(.9, .2),
          radius: 1.1,
          colors: [Color(0x332D50B8), Color(0x0007090F)],
        ),
      ),
    ),
  );
}

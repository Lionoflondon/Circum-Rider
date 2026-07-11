import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../authentication/bloc/auth_bloc.dart';
import '../../authentication/view/signin.dart';
import '../../authentication/view/signup.dart';
import '../../authentication/view/widgets/rider_onboarding_shell.dart';
import '../../../../utils/theme/theme.dart';

/// The existing Circum authentication entry point. It intentionally delegates
/// sign-in, account creation, OTP, recovery, Google and Apple to AuthBloc.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _identity = TextEditingController();

  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  void _continue() {
    final value = _identity.text.trim();
    if (value.isEmpty) return;
    final bloc = context.read<AuthBloc>();
    bloc.add(SignupEmailChanged(email: value));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RiderOnboardingShell(
      currentStep: 0,
      showStepProgress: false,
      title: 'What\'s your email?',
      subtitle: 'Create your Rider account securely with email.',
      child: RiderGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RiderGlassTextField(
              label: 'Enter your email',
              controller: _identity,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            RiderPrimaryButton(
              label: 'Continue',
              enabled: _identity.text.trim().isNotEmpty,
              onPressed: _continue,
            ),
            const SizedBox(height: 14),
            ExistingRiderSignInLink(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SigninView()),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or continue with'),
                ),
                Expanded(child: Divider()),
              ]),
            ),
            OutlinedButton.icon(
              onPressed: () => context.read<AuthBloc>().add(SignInWithGoogle()),
              icon: SvgPicture.asset('assets/svg/google_logo.svg', height: 18),
              label: const Text('Google'),
            ),
            if (!kIsWeb && Platform.isIOS) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    context.read<AuthBloc>().add(SignInWithAppleAuth()),
                icon: SvgPicture.asset('assets/svg/apple_logo.svg', height: 18),
                label: const Text('Apple'),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'By continuing, you agree to Circum Terms and Privacy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textGrey.withOpacity(0.9), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class ExistingRiderSignInLink extends StatelessWidget {
  final VoidCallback onPressed;

  const ExistingRiderSignInLink({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    const label = 'Already have an account? Sign in';
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        key: const Key('existing_rider_sign_in'),
        width: double.infinity,
        height: 48,
        child: TextButton(
          onPressed: onPressed,
          child: const Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

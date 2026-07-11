import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../authentication/bloc/auth_bloc.dart';
import '../../authentication/view/signup.dart';
import '../../authentication/view/widgets/circum_auth_entry.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});
  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _identifier = TextEditingController();
  bool _submitting = false;
  String? _validation;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  bool get _valid {
    final value = _identifier.text.trim();
    final email = RegExp(r'^[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}$').hasMatch(value);
    final phone = RegExp(r'^\+?[0-9][0-9 ()-]{7,18}$').hasMatch(value);
    return email || phone;
  }

  void _continue() {
    if (!_valid || _submitting) return;
    final value = _identifier.text.trim();
    final email = value.contains('@');
    setState(() {
      _submitting = true;
      _validation = null;
    });
    final bloc = context.read<AuthBloc>();
    if (email) {
      bloc.add(SignupEmailChanged(email: value));
    } else {
      bloc.add(
        PhoneNumberChanged(
          phoneNumber: value.replaceAll(RegExp(r'[ ()-]'), ''),
        ),
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupView()),
    ).whenComplete(() {
      if (mounted) setState(() => _submitting = false);
    });
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) => CircumAuthEntry(
          controller: _identifier,
          valid: _valid,
          loading: _submitting || state.status == Status.loading,
          error: _validation ?? state.errorMessage,
          onChanged: (_) => setState(() => _validation = null),
          onContinue: _continue,
          onGoogle: () => context.read<AuthBloc>().add(SignInWithGoogle()),
          onApple: () => context.read<AuthBloc>().add(SignInWithAppleAuth()),
          onQr: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR login is not configured in this environment.'),
            ),
          ),
        ),
      );
}

/// Retained for the existing email sign-in route and its accessibility test.
/// The canonical entry card does not render Rider-specific wording.
class ExistingRiderSignInLink extends StatelessWidget {
  const ExistingRiderSignInLink({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Already have an account? Sign in',
        child: SizedBox(
          key: const Key('existing_rider_sign_in'),
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: onPressed,
            child: const Text('Already have an account? Sign in'),
          ),
        ),
      );
}

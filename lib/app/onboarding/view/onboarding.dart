import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../authentication/bloc/auth_bloc.dart';
import '../../rider_design/rider_ui.dart';

enum _RiderAuthStep { welcome, createAccount, signIn, phoneOtp, location }

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  _RiderAuthStep _step = _RiderAuthStep.welcome;
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _signInEmail = TextEditingController();
  final _signInPassword = TextEditingController();
  final _otp = TextEditingController();
  bool _terms = false;
  bool _privacy = false;
  bool _rightToWork = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _signInEmail.dispose();
    _signInPassword.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.isPhoneOtpSent != current.isPhoneOtpSent ||
          previous.isPhoneVerified != current.isPhoneVerified,
      listener: (context, state) {
        if (state.isPhoneOtpSent && !state.isPhoneVerified) {
          setState(() => _step = _RiderAuthStep.phoneOtp);
        }
        if (state.isPhoneVerified) {
          setState(() => _step = _RiderAuthStep.location);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF05070A),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _PhoneShell(
                    child: Column(
                      children: [
                        if (_step != _RiderAuthStep.welcome)
                          _TopBar(
                            step: _step,
                            onBack: _back,
                          )
                        else
                          const SizedBox(height: 34),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _buildStep(context, state),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep(BuildContext context, AuthState state) {
    return switch (_step) {
      _RiderAuthStep.welcome => _WelcomeStep(
          onCreate: () => setState(() => _step = _RiderAuthStep.createAccount),
          onSignIn: () => setState(() => _step = _RiderAuthStep.signIn),
          onGoogle: () => context.read<AuthBloc>().add(SignInWithGoogle()),
          onApple: _appleAvailable
              ? () => context.read<AuthBloc>().add(SignInWithAppleAuth())
              : null,
          error: _message(state),
          loading: state.status == Status.loading,
        ),
      _RiderAuthStep.createAccount => _CreateAccountStep(
          fullName: _fullName,
          email: _email,
          phone: _phone,
          password: _password,
          showPassword: _showPassword,
          terms: _terms,
          privacy: _privacy,
          rightToWork: _rightToWork,
          loading: state.status == Status.loading,
          error: _message(state),
          onChanged: _syncCreateFields,
          onTogglePassword: () =>
              setState(() => _showPassword = !_showPassword),
          onTerms: (value) => setState(() => _terms = value),
          onPrivacy: (value) => setState(() => _privacy = value),
          onRightToWork: (value) => setState(() => _rightToWork = value),
          onSubmit: () => _createAccount(state),
          onSignIn: () => setState(() => _step = _RiderAuthStep.signIn),
        ),
      _RiderAuthStep.signIn => _SignInStep(
          email: _signInEmail,
          password: _signInPassword,
          loading: state.status == Status.loading,
          error: _message(state),
          onChanged: () => setState(() {}),
          onSubmit: _signIn,
          onReset: _resetPassword,
          onCreate: () => setState(() => _step = _RiderAuthStep.createAccount),
        ),
      _RiderAuthStep.phoneOtp => _OtpStep(
          phone: _formatPhone(_phone.text),
          otp: _otp,
          countdown: state.countdown,
          loading: state.status == Status.loading,
          error: state.otpErrorMessage,
          onChanged: () {
            context.read<AuthBloc>().add(PhoneOtpChanged(otpCode: _otp.text));
            setState(() {});
          },
          onSubmit: () => context
              .read<AuthBloc>()
              .add(VerifyPhoneOtp(otpCode: _otp.text.trim())),
          onResend: state.countdown > 0
              ? null
              : () => context.read<AuthBloc>().add(ResendPhoneOtp()),
          onChangeNumber: () =>
              setState(() => _step = _RiderAuthStep.createAccount),
        ),
      _RiderAuthStep.location => _LocationStep(
          loading: state.status == Status.locationRequested ||
              state.status == Status.loading,
          error: _message(state),
          onEnable: () => context.read<AuthBloc>().add(RequestLocationData()),
          onMaybeLater: () => context
              .read<AuthBloc>()
              .add(const CompleteRiderApplication(locationEnabled: false)),
        ),
    };
  }

  bool get _appleAvailable => !kIsWeb && Platform.isIOS;

  void _back() {
    setState(() {
      _step = switch (_step) {
        _RiderAuthStep.createAccount ||
        _RiderAuthStep.signIn =>
          _RiderAuthStep.welcome,
        _RiderAuthStep.phoneOtp => _RiderAuthStep.createAccount,
        _RiderAuthStep.location => _RiderAuthStep.phoneOtp,
        _RiderAuthStep.welcome => _RiderAuthStep.welcome,
      };
    });
  }

  String? _message(AuthState state) {
    if ((state.errorMessage ?? '').isNotEmpty) return state.errorMessage;
    if (state.status == Status.unverifiedEmail) {
      return 'We sent a verification email. Verify it to continue.';
    }
    if (state.status == Status.passwordResetEmailSent) {
      return 'Password reset email sent.';
    }
    return null;
  }

  void _syncCreateFields() {
    final names = _fullName.text.trim().split(RegExp(r'\s+'));
    final first = names.isEmpty ? '' : names.first;
    final last = names.length > 1 ? names.sublist(1).join(' ') : '';
    final bloc = context.read<AuthBloc>();
    bloc.add(FirstNameChanged(firstName: first));
    bloc.add(LastNameChanged(lastName: last));
    bloc.add(SignupEmailChanged(email: _email.text.trim()));
    bloc.add(PhoneNumberChanged(phoneNumber: _formatPhone(_phone.text)));
    bloc.add(SignupPasswordChanged(password: _password.text));
    setState(() {});
  }

  void _createAccount(AuthState state) {
    _syncCreateFields();
    final error = _createValidationError();
    if (error != null) {
      context.read<AuthBloc>().add(SetErrorMessage(errorMessage: error));
      return;
    }
    context.read<AuthBloc>().add(SignUpWithEmail(
          email: _email.text.trim(),
          password: _password.text,
        ));
  }

  String? _createValidationError() {
    if (_fullName.text.trim().split(RegExp(r'\s+')).length < 2) {
      return 'Add your full name.';
    }
    if (!_email.text.trim().contains('@')) return 'Enter a valid email.';
    if (!_validUkPhone(_phone.text)) return 'Enter a valid UK mobile number.';
    if (_passwordScore(_password.text) < 2) {
      return 'Use a stronger password to protect your Rider account.';
    }
    if (!_terms) return 'Accept the Rider Terms to continue.';
    if (!_privacy) return 'Accept the Privacy Policy to continue.';
    if (!_rightToWork) {
      return 'Confirm you are legally entitled to work in the UK.';
    }
    return null;
  }

  void _signIn() {
    final email = _signInEmail.text.trim();
    final password = _signInPassword.text;
    if (!email.contains('@')) {
      context
          .read<AuthBloc>()
          .add(const SetErrorMessage(errorMessage: 'Enter a valid email.'));
      return;
    }
    if (password.isEmpty) {
      context
          .read<AuthBloc>()
          .add(const SetErrorMessage(errorMessage: 'Enter your password.'));
      return;
    }
    context
        .read<AuthBloc>()
        .add(SignInWithEmail(email: email, password: password));
  }

  void _resetPassword() {
    final email = _signInEmail.text.trim();
    if (!email.contains('@')) {
      context.read<AuthBloc>().add(const SetErrorMessage(
          errorMessage: 'Enter your email before resetting your password.'));
      return;
    }
    context.read<AuthBloc>().add(ResetPassword(email: email));
  }

  bool _validUkPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.startsWith('07') && digits.length == 11 ||
        digits.startsWith('447') && digits.length == 12;
  }

  String _formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('44')) return '+$digits';
    if (digits.startsWith('0')) return '+44${digits.substring(1)}';
    return value.trim();
  }
}

class _PhoneShell extends StatelessWidget {
  const _PhoneShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1318),
          borderRadius: BorderRadius.circular(38),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .45),
              blurRadius: 48,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(child: _AuthBackground()),
            child,
          ],
        ),
      );
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _AuthBackgroundPainter(),
      );
}

class _AuthBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(.1, -.9),
        radius: .95,
        colors: [
          RiderPalette.blue.withValues(alpha: .28),
          const Color(0xFF0F1318),
          const Color(0xFF0A0D11),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..strokeWidth = 1;
    for (var i = 0; i < 10; i++) {
      final y = size.height * (i / 9);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 28), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.step, required this.onBack});

  final _RiderAuthStep step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final index = switch (step) {
      _RiderAuthStep.createAccount => 1,
      _RiderAuthStep.signIn => 1,
      _RiderAuthStep.phoneOtp => 2,
      _RiderAuthStep.location => 3,
      _RiderAuthStep.welcome => 0,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
      child: Row(
        children: [
          _GlassIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: i < index
                          ? RiderPalette.blue
                          : Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$index/3',
            style: const TextStyle(
              color: RiderPalette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.onCreate,
    required this.onSignIn,
    required this.onGoogle,
    required this.onApple,
    required this.loading,
    this.error,
  });

  final VoidCallback onCreate;
  final VoidCallback onSignIn;
  final VoidCallback onGoogle;
  final VoidCallback? onApple;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) => _StepScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 28),
            const _BrandMark(),
            const SizedBox(height: 28),
            const Text(
              'Deliver with Circum',
              style: _AuthText.h1,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your Rider account or sign in to continue your application.',
              style: _AuthText.sub,
            ),
            const SizedBox(height: 28),
            _PrimaryAuthButton(
              label: 'Get started',
              onPressed: onCreate,
              loading: loading,
            ),
            const SizedBox(height: 12),
            _SecondaryAuthButton(
              label: 'Existing Rider sign in',
              icon: Icons.login_rounded,
              onPressed: onSignIn,
            ),
            const SizedBox(height: 18),
            const _DividerLabel(),
            const SizedBox(height: 18),
            _ProviderButton(
              label: 'Continue with Google',
              asset: 'assets/svg/google_logo.svg',
              onPressed: onGoogle,
            ),
            const SizedBox(height: 10),
            _ProviderButton(
              label: 'Continue with Apple',
              asset: 'assets/svg/apple_logo.svg',
              onPressed: onApple,
              unavailableText:
                  'Apple sign-in is available on supported Apple devices.',
            ),
            if (error != null) _AuthError(error!),
          ],
        ),
      );
}

class _CreateAccountStep extends StatelessWidget {
  const _CreateAccountStep({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.showPassword,
    required this.terms,
    required this.privacy,
    required this.rightToWork,
    required this.loading,
    required this.onChanged,
    required this.onTogglePassword,
    required this.onTerms,
    required this.onPrivacy,
    required this.onRightToWork,
    required this.onSubmit,
    required this.onSignIn,
    this.error,
  });

  final TextEditingController fullName;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController password;
  final bool showPassword;
  final bool terms;
  final bool privacy;
  final bool rightToWork;
  final bool loading;
  final VoidCallback onChanged;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool> onTerms;
  final ValueChanged<bool> onPrivacy;
  final ValueChanged<bool> onRightToWork;
  final VoidCallback onSubmit;
  final VoidCallback onSignIn;
  final String? error;

  @override
  Widget build(BuildContext context) => _StepScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create Rider account', style: _AuthText.h1),
            const Text(
              'Start with your personal details. Vehicle and document checks continue after authentication.',
              style: _AuthText.sub,
            ),
            _AuthField(
              label: 'Full name',
              controller: fullName,
              autofillHints: const [AutofillHints.name],
              onChanged: onChanged,
            ),
            _AuthField(
              label: 'Email',
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: onChanged,
            ),
            _AuthField(
              label: 'UK mobile number',
              controller: phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              prefix: '+44',
              onChanged: onChanged,
            ),
            _AuthField(
              label: 'Password',
              controller: password,
              obscureText: !showPassword,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: onChanged,
              suffix: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  showPassword ? Icons.visibility_off : Icons.visibility,
                  color: RiderPalette.blue,
                ),
              ),
            ),
            _PasswordStrength(password: password.text),
            const SizedBox(height: 12),
            _ConsentTile(
              value: terms,
              text: 'I agree to the Rider Terms.',
              onChanged: onTerms,
            ),
            _ConsentTile(
              value: privacy,
              text: 'I agree to the Privacy Policy.',
              onChanged: onPrivacy,
            ),
            _ConsentTile(
              value: rightToWork,
              text: 'I confirm I am legally entitled to work in the UK.',
              onChanged: onRightToWork,
            ),
            if (error != null) _AuthError(error!),
            const SizedBox(height: 16),
            _PrimaryAuthButton(
              label: 'Create account',
              onPressed: onSubmit,
              loading: loading,
            ),
            TextButton(
              onPressed: onSignIn,
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      );
}

class _SignInStep extends StatelessWidget {
  const _SignInStep({
    required this.email,
    required this.password,
    required this.loading,
    required this.onChanged,
    required this.onSubmit,
    required this.onReset,
    required this.onCreate,
    this.error,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool loading;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onReset;
  final VoidCallback onCreate;
  final String? error;

  @override
  Widget build(BuildContext context) => _StepScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Welcome back', style: _AuthText.h1),
            const Text(
              'Sign in with your Rider email and password.',
              style: _AuthText.sub,
            ),
            _AuthField(
              label: 'Email',
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: onChanged,
            ),
            _AuthField(
              label: 'Password',
              controller: password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onChanged: onChanged,
            ),
            if (error != null) _AuthError(error!),
            const SizedBox(height: 16),
            _PrimaryAuthButton(
              label: 'Sign in',
              onPressed: onSubmit,
              loading: loading,
            ),
            TextButton(
                onPressed: onReset, child: const Text('Forgot password')),
            TextButton(
              onPressed: onCreate,
              child: const Text('Back to create account'),
            ),
          ],
        ),
      );
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.phone,
    required this.otp,
    required this.countdown,
    required this.loading,
    required this.onChanged,
    required this.onSubmit,
    required this.onResend,
    required this.onChangeNumber,
    this.error,
  });

  final String phone;
  final TextEditingController otp;
  final int countdown;
  final bool loading;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;
  final VoidCallback? onResend;
  final VoidCallback onChangeNumber;
  final String? error;

  @override
  Widget build(BuildContext context) => _StepScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Verify your mobile', style: _AuthText.h1),
            Text('Enter the 6-digit code sent to $phone.',
                style: _AuthText.sub),
            _AuthField(
              label: 'Verification code',
              controller: otp,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              onChanged: onChanged,
            ),
            if (error != null) _AuthError(error!),
            const SizedBox(height: 16),
            _PrimaryAuthButton(
              label: 'Verify code',
              onPressed: otp.text.trim().length >= 6 ? onSubmit : null,
              loading: loading,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onResend,
              child: Text(
                onResend == null
                    ? 'Resend code in ${math.max(0, countdown)}s'
                    : 'Resend code',
              ),
            ),
            TextButton(
              onPressed: onChangeNumber,
              child: const Text('Change number'),
            ),
          ],
        ),
      );
}

class _LocationStep extends StatelessWidget {
  const _LocationStep({
    required this.loading,
    required this.onEnable,
    required this.onMaybeLater,
    this.error,
  });

  final bool loading;
  final VoidCallback onEnable;
  final VoidCallback onMaybeLater;
  final String? error;

  @override
  Widget build(BuildContext context) => _StepScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.location_searching_rounded,
                color: RiderPalette.blue, size: 48),
            const SizedBox(height: 20),
            const Text('Enable location', style: _AuthText.h1),
            const Text(
              'Circum Rider needs location for active deliveries, arrival checks and safe live tracking. You can finish account setup now, but going online requires location access.',
              style: _AuthText.sub,
            ),
            if (error != null) _AuthError(error!),
            const SizedBox(height: 22),
            _PrimaryAuthButton(
              label: 'Enable location',
              onPressed: onEnable,
              loading: loading,
            ),
            TextButton(
              onPressed: onMaybeLater,
              child: const Text('Maybe later'),
            ),
          ],
        ),
      );
}

class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: child,
      );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: RiderPalette.blue.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: RiderPalette.blue.withValues(alpha: .34)),
            ),
            child: const Icon(Icons.route_rounded, color: RiderPalette.blue),
          ),
          const SizedBox(width: 12),
          const Text(
            'CIRCUM\nRIDER',
            style: TextStyle(
              color: RiderPalette.paper,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              height: 1.05,
            ),
          ),
        ],
      );
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.prefix,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final String? prefix;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _AuthText.label),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .12)),
                  ),
                  child: Row(
                    children: [
                      if (prefix != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text(prefix!, style: _AuthText.inputPrefix),
                        ),
                        Container(
                          height: 24,
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: Colors.white.withValues(alpha: .10),
                        ),
                      ] else
                        const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: keyboardType,
                          obscureText: obscureText,
                          autofillHints: autofillHints,
                          onChanged: (_) => onChanged(),
                          style: _AuthText.input,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (suffix != null) suffix!,
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.text,
    required this.onChanged,
  });

  final bool value;
  final String text;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: RiderPalette.blue,
        title: Text(text, style: _AuthText.consent),
      );
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final score = _passwordScore(password);
    final label = switch (score) {
      0 => 'Use at least 8 characters',
      1 => 'Password strength: fair',
      2 => 'Password strength: good',
      _ => 'Password strength: strong',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: index < score
                        ? RiderPalette.blue
                        : Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: _AuthText.helper),
        ],
      ),
    );
  }
}

int _passwordScore(String value) {
  var score = 0;
  if (value.length >= 8) score++;
  if (RegExp(r'[A-Z]').hasMatch(value) &&
      RegExp(r'[a-z]').hasMatch(value) &&
      RegExp(r'\d').hasMatch(value)) {
    score++;
  }
  if (value.length >= 12 && RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
  return score;
}

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: RiderPalette.blue,
            disabledBackgroundColor: Colors.white.withValues(alpha: .12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
}

class _SecondaryAuthButton extends StatelessWidget {
  const _SecondaryAuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: RiderPalette.paper,
            side: BorderSide(color: Colors.white.withValues(alpha: .14)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.asset,
    required this.onPressed,
    this.unavailableText,
  });

  final String label;
  final String asset;
  final VoidCallback? onPressed;
  final String? unavailableText;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: SvgPicture.asset(asset, height: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: RiderPalette.paper,
                side: BorderSide(color: Colors.white.withValues(alpha: .14)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          if (onPressed == null && unavailableText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(unavailableText!, style: _AuthText.helper),
            ),
        ],
      );
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Icon(icon, color: RiderPalette.paper, size: 19),
        ),
      );
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withValues(alpha: .10))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: _AuthText.helper),
          ),
          Expanded(child: Divider(color: Colors.white.withValues(alpha: .10))),
        ],
      );
}

class _AuthError extends StatelessWidget {
  const _AuthError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          message,
          style: const TextStyle(
            color: RiderPalette.red,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _AuthText {
  static const h1 = TextStyle(
    color: RiderPalette.paper,
    fontSize: 25,
    height: 1.22,
    fontWeight: FontWeight.w900,
  );
  static const sub = TextStyle(
    color: RiderPalette.muted,
    fontSize: 13,
    height: 1.5,
  );
  static const label = TextStyle(
    color: RiderPalette.paper,
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
  );
  static const helper = TextStyle(
    color: RiderPalette.muted,
    fontSize: 11,
    height: 1.35,
  );
  static const input = TextStyle(color: RiderPalette.paper, fontSize: 14);
  static const inputPrefix = TextStyle(
    color: RiderPalette.muted,
    fontSize: 13,
    fontWeight: FontWeight.w800,
  );
  static const consent = TextStyle(
    color: RiderPalette.muted,
    fontSize: 12,
    height: 1.35,
  );
}

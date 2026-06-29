import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';

import '../../../utils/theme/theme.dart';
import '../bloc/auth_bloc.dart';
import 'verify_email.dart';
import 'widgets/rider_onboarding_shell.dart';

class EnterOTPView extends StatefulWidget {
  const EnterOTPView({Key? key}) : super(key: key);

  @override
  EnterOTPViewState createState() => EnterOTPViewState();
}

class EnterOTPViewState extends State<EnterOTPView> {
  Timer? _countdownTimer;
  int _countdown = 30;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == Status.unverifiedEmail && state.isPhoneVerified) {
          context.read<AuthBloc>().add(ResetStatus());
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VerifyEmailView()),
          );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          return RiderOnboardingShell(
            currentStep: 2,
            title: 'Verify your phone',
            subtitle:
                'Enter the 6-digit code sent to ${state.phoneNumber ?? 'your phone'}',
            child: RiderGlassCard(
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.16),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.46)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.32),
                          blurRadius: 28,
                        )
                      ],
                    ),
                    child: const Icon(Icons.sms_rounded,
                        color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(height: 22),
                  Pinput(
                    length: 6,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    hapticFeedbackType: HapticFeedbackType.lightImpact,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (pin) => context
                        .read<AuthBloc>()
                        .add(PhoneOtpChanged(otpCode: pin)),
                    onCompleted: (pin) => context
                        .read<AuthBloc>()
                        .add(VerifyPhoneOtp(otpCode: pin)),
                    defaultPinTheme: _pinTheme(focused: false),
                    focusedPinTheme: _pinTheme(focused: true),
                    submittedPinTheme: _pinTheme(focused: false).copyWith(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.52)),
                      ),
                    ),
                  ),
                  if (state.otpErrorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: AppText.text(
                        state.otpErrorMessage!,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 18),
                  RiderSecondaryButton(
                    enabled: _countdown == 0,
                    onPressed: () {
                      context.read<AuthBloc>().add(ResendPhoneOtp());
                      _startCountdown();
                    },
                    label: _countdown == 0
                        ? 'Resend code'
                        : 'Resend in $_countdown seconds',
                  ),
                  if (state.status == Status.loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(color: AppColors.primary),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PinTheme _pinTheme({required bool focused}) {
    return PinTheme(
      width: 48,
      height: 58,
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontFamily: 'OpenSans',
        fontSize: 19,
      ),
      decoration: BoxDecoration(
        color: focused
            ? AppColors.primary.withOpacity(0.16)
            : const Color(0xFF101722).withOpacity(0.86),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: focused ? AppColors.primary : Colors.white.withOpacity(0.12),
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.28),
                  blurRadius: 18,
                )
              ]
            : null,
      ),
    );
  }
}

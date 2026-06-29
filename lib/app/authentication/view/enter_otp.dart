import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';

import '../../../utils/theme/theme.dart';
import '../bloc/auth_bloc.dart';
import 'verify_email.dart';
import 'widgets/step_progress.dart';

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
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == Status.unverifiedEmail && state.isPhoneVerified) {
            context.read<AuthBloc>().add(ResetStatus());
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const VerifyEmailView()),
            );
          }
        },
        child: SafeArea(
          child: BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StepProgress(currentStep: 2),
                  const SizedBox(height: 28),
                  AppText.text(
                    'Verify your phone',
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                  const SizedBox(height: 10),
                  AppText.text(
                    'Enter the 6-digit code sent to ${state.phoneNumber ?? 'your phone'}',
                    color: AppColors.textGrey,
                    fontSize: 15,
                  ),
                  const SizedBox(height: 28),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                          ),
                        ),
                        child: Column(
                          children: [
                            Pinput(
                              length: 6,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              hapticFeedbackType:
                                  HapticFeedbackType.lightImpact,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (pin) => context
                                  .read<AuthBloc>()
                                  .add(PhoneOtpChanged(otpCode: pin)),
                              onCompleted: (pin) => context
                                  .read<AuthBloc>()
                                  .add(VerifyPhoneOtp(otpCode: pin)),
                              defaultPinTheme: PinTheme(
                                width: 48,
                                height: 56,
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'OpenSans',
                                  fontSize: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.input,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.10),
                                  ),
                                ),
                              ),
                              focusedPinTheme: PinTheme(
                                width: 48,
                                height: 56,
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'OpenSans',
                                  fontSize: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primary,
                                  ),
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
                            TextButton(
                              onPressed: _countdown == 0
                                  ? () {
                                      context
                                          .read<AuthBloc>()
                                          .add(ResendPhoneOtp());
                                      _startCountdown();
                                    }
                                  : null,
                              child: AppText.text(
                                _countdown == 0
                                    ? 'Resend code'
                                    : 'Resend in $_countdown seconds',
                                color: _countdown == 0
                                    ? AppColors.primary
                                    : AppColors.textGrey,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (state.status == Status.loading)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: LinearProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

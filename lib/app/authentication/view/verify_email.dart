import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../utils/theme/theme.dart';
import '../bloc/auth_bloc.dart';
import 'enable_location.dart';
import 'widgets/step_progress.dart';

class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({Key? key}) : super(key: key);

  @override
  VerifyEmailViewState createState() => VerifyEmailViewState();
}

class VerifyEmailViewState extends State<VerifyEmailView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      context.read<AuthBloc>().add(ConfirmEmailVerification());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == Status.success) {
            _timer?.cancel();
            context.read<AuthBloc>().add(ResetStatus());
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const EnableLocation()),
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
                  const StepProgress(currentStep: 3),
                  const SizedBox(height: 28),
                  AppText.text(
                    'Check your email',
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                  const SizedBox(height: 10),
                  AppText.text(
                    'We sent a secure verification link to ${state.email ?? 'your email'}',
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
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(30),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.14)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              CupertinoIcons.envelope_badge,
                              color: AppColors.primary,
                              size: 42,
                            ),
                            const SizedBox(height: 18),
                            AppText.text(
                              'Open the link in your inbox, then come back here.',
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                            const SizedBox(height: 10),
                            AppText.text(
                              'We will keep checking automatically every few seconds.',
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(height: 22),
                            AppButton.button(
                              isLoading: state.status == Status.loading,
                              onPressed: () => context
                                  .read<AuthBloc>()
                                  .add(ConfirmEmailVerification()),
                              widget: AppText.text(
                                "I've verified — continue",
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => context
                                  .read<AuthBloc>()
                                  .add(ResendVerificationEmail()),
                              child: AppText.text(
                                'Resend verification email',
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
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

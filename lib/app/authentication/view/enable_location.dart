import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../utils/theme/theme.dart';
import '../bloc/auth_bloc.dart';
import 'application_submitted.dart';
import 'widgets/step_progress.dart';

class EnableLocation extends StatelessWidget {
  const EnableLocation({Key? key}) : super(key: key);

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<void> locationAllowed() async {
    await storage.write(key: 'location', value: 'allowed');
  }

  void _goSubmitted(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ApplicationSubmittedView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state.status == Status.locationRequested) {
            context.read<AuthBloc>().add(ResetStatus());
            await locationAllowed();
            _goSubmitted(context);
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StepProgress(currentStep: 4),
                const SizedBox(height: 28),
                AppText.text(
                  'Stay close to opportunity.',
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
                const SizedBox(height: 10),
                AppText.text(
                  'Enable location so Circum can surface nearby work, support safer deliveries, and keep active journeys accurate.',
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
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            color: AppColors.primary,
                            size: 46,
                          ),
                          const SizedBox(height: 22),
                          AppButton.button(
                            onPressed: () {
                              context
                                  .read<AuthBloc>()
                                  .add(RequestLocationData());
                            },
                            widget: AppText.text(
                              'Enable location',
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.read<AuthBloc>().add(
                                  const CompleteRiderApplication(
                                    locationEnabled: false,
                                  ),
                                ),
                            child: AppText.text(
                              'Maybe later',
                              color: AppColors.textGrey,
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
          ),
        ),
      ),
    );
  }
}

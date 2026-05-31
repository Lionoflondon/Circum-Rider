import 'dart:io';

import 'package:circum_rider/app/authentication/bloc/auth_bloc.dart';
import 'package:circum_rider/app/bottom_nav/view/index.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/svg.dart';

import '../../../utils/theme/theme.dart';

class EnableLocation extends StatelessWidget {
  const EnableLocation({Key? key}) : super(key: key);

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  locationAllowed() async {
    await storage.write(key: 'location', value: 'allowed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.secondary,
        body: BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state.status == Status.locationRequested) {
                context.read<AuthBloc>().add(ResetStatus());
                // context.read<AuthBloc>().add(StartCountDown());
                locationAllowed();
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            child: WillPopScope(
              // Intercept the back button press
              onWillPop: () async {
                return false;
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/svg/map_pin.svg'),
                  const SizedBox(height: 64),
                  AppText.text(
                      'Get the most out of Circum by\nenabling location services.',
                      textAlign: TextAlign.center,
                      fontSize: 20,
                      fontWeight: FontWeight.w600),
                  if (!kIsWeb && Platform.isAndroid)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 14),
                            AppText.text(
                                'We use your location in the background (even when the app is closed) to:',
                                fontWeight: FontWeight.w600),
                            const SizedBox(height: 6),
                            AppText.text(
                                '- Track your current position for accurate order assignments.',
                                fontSize: 12),
                            const SizedBox(height: 6),
                            AppText.text(
                                '- Provide real-time updates to customers on their delivery status.',
                                fontSize: 12),
                            const SizedBox(height: 6),
                            AppText.text(
                                '- Ensure your safety by monitoring your location during active deliveries.',
                                fontSize: 12),
                          ],
                        )),
                  const SizedBox(height: 48),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AppButton.button(
                          widget: Center(
                            child: AppText.text('Enable',
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          onPressed: () {
                            context.read<AuthBloc>().add(RequestLocationData());
                          })),
                  const SizedBox(height: 16),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AppButton.button(
                          backgroundColor: AppColors.secondary,
                          widget: Center(
                            child: AppText.text('Skip',
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          onPressed: () {
                            Navigator.popUntil(
                                context, (route) => route.isFirst);
                          }))
                ],
              ),
            )));
  }
}

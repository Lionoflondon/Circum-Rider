import 'package:circum_rider/app/authentication/bloc/auth_bloc.dart';
import 'package:circum_rider/app/bottom_nav/view/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import '../../../utils/theme/theme.dart';

class EnableLocation extends StatelessWidget {
  const EnableLocation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.secondary,
        body: BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state.status == Status.locationRequested) {
                context.read<AuthBloc>().add(ResetStatus());
                // context.read<AuthBloc>().add(StartCountDown());
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => AppNavView()),
                );
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
                            Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AppNavView()));
                          }))
                ],
              ),
            )));
  }
}

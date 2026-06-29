import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import 'enter_otp.dart';
import 'signup_form.dart';
import 'verify_email.dart';
import 'widgets/rider_onboarding_shell.dart';

class SignupView extends StatelessWidget {
  const SignupView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == Status.success) {
            if (state.isPhoneOtpSent && state.isPhoneVerified != true) {
              context.read<AuthBloc>().add(ResetStatus());
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EnterOTPView()));
            }
          }

          if (state.status == Status.unverifiedEmail) {
            context.read<AuthBloc>().add(ResetStatus());
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const VerifyEmailView()));
          }
        },
        child: const RiderOnboardingShell(
          currentStep: 1,
          title: 'Become a Circum Rider',
          subtitle: "Join the UK's most trusted delivery network.",
          child: SignupForm(),
        ));
  }
}

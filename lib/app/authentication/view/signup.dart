import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../utils/theme/theme.dart';
import '../bloc/auth_bloc.dart';
import 'enter_otp.dart';
import 'signup_form.dart';
import 'verify_email.dart';
import 'widgets/step_progress.dart';

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
        child: Scaffold(
            backgroundColor: AppColors.secondary,
            body: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).padding.top,
                ),
                _loader(),
                Container(
                    width: MediaQuery.of(context).size.width,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: AppText.text("Become a Circum Rider",
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 30)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AppText.text(
                    "Join the UK's most trusted delivery network.",
                    color: AppColors.textGrey,
                    fontSize: 15,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: StepProgress(currentStep: 1),
                ),
                Expanded(
                  child: const SignupForm(),
                ),
                const SizedBox(height: 20),
              ],
            )));
  }

  Widget _loader() {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return state.status == Status.loading
          ? LinearProgressIndicator(color: AppColors.primary)
          : Container();
    });
  }
}

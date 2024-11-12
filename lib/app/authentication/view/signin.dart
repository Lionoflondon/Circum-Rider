import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../utils/theme/theme.dart';
import '../../bottom_nav/view/app_nav.dart';
import '../bloc/auth_bloc.dart';
import 'signin_form.dart';
import 'verify_email.dart';

class SigninView extends StatelessWidget {
  const SigninView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == Status.success) {
            context.read<AuthBloc>().add(ResetStatus());
            // AppNavView()
            // AdvisorView()
            // Navigator.push(
            //     context, MaterialPageRoute(builder: (_) => AppNavView()));
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
                    margin: EdgeInsets.only(
                      left: 30,
                      top: 20,
                    ),
                    child: AppText.text("Sign In",
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 28)),
                const Expanded(
                  child: SigninForm(),
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

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../utils/theme/theme.dart';
import '../bloc/auth_bloc.dart';
import 'signin.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({Key? key}) : super(key: key);

  @override
  SignupFormState createState() => SignupFormState();
}

class SignupFormState extends State<SignupForm> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _acceptedTerms = false;
  var _country = countries.firstWhere((element) => element.code == 'GB');

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.18),
                    blurRadius: 38,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _trustChips(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          label: 'First name',
                          controller: _firstNameController,
                          onChanged: (value) => context
                              .read<AuthBloc>()
                              .add(FirstNameChanged(firstName: value)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _textField(
                          label: 'Last name',
                          controller: _lastNameController,
                          onChanged: (value) => context
                              .read<AuthBloc>()
                              .add(LastNameChanged(lastName: value)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _textField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => context
                        .read<AuthBloc>()
                        .add(SignupEmailChanged(email: value)),
                  ),
                  const SizedBox(height: 16),
                  _phoneField(state),
                  const SizedBox(height: 16),
                  _textField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: !state.showPassword,
                    onChanged: (value) => context
                        .read<AuthBloc>()
                        .add(SignupPasswordChanged(password: value)),
                    suffix: IconButton(
                      onPressed: () => context
                          .read<AuthBloc>()
                          .add(SetShowPassword(val: !state.showPassword)),
                      icon: Icon(
                        state.showPassword
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _acceptedTerms,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() => _acceptedTerms = value ?? false);
                    },
                    title: AppText.text(
                      'I agree to Circum rider onboarding checks and terms.',
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  if (state.errorMessage?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppText.text(
                        state.errorMessage!,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton.button(
                      isLoading: state.status == Status.loading,
                      onPressed: () => _submit(state),
                      widget: AppText.text(
                        'Create account',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SigninView(),
                          ),
                        );
                      },
                      child: AppText.text(
                        'Already have an account? Sign in',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _trustChips() {
    const chips = [
      'Powered by IRIS',
      'Protected by Vanguard',
      'Trust unlocks priority deliveries',
      'Flexible work',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map((chip) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.34),
                  ),
                ),
                child: AppText.text(
                  chip,
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ))
          .toList(),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.text(label, color: Colors.white, fontWeight: FontWeight.w700),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontFamily: 'OpenSans'),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.input.withOpacity(0.9),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _phoneField(AuthState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.text('Mobile number',
            color: Colors.white, fontWeight: FontWeight.w700),
        const SizedBox(height: 8),
        IntlPhoneField(
          style: const TextStyle(color: Colors.white, fontFamily: 'OpenSans'),
          dropdownTextStyle:
              const TextStyle(color: Colors.white, fontFamily: 'OpenSans'),
          initialCountryCode: 'GB',
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.input.withOpacity(0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          onCountryChanged: (country) => _country = country,
          onChanged: (value) {
            final valid = value.number.length >= _country.minLength &&
                value.number.length <= _country.maxLength;
            context.read<AuthBloc>().add(ValidatePhoneNumber(val: valid));
            context
                .read<AuthBloc>()
                .add(PhoneNumberChanged(phoneNumber: value.completeNumber));
          },
        ),
      ],
    );
  }

  void _submit(AuthState state) {
    final bloc = context.read<AuthBloc>();
    if ((_firstNameController.text.trim().isEmpty) ||
        (_lastNameController.text.trim().isEmpty)) {
      bloc.add(const SetErrorMessage(errorMessage: 'Add your full name.'));
      return;
    }
    if (state.isEmailValid != true) {
      bloc.add(const SetErrorMessage(errorMessage: 'Invalid email address.'));
      return;
    }
    if (state.isPhoneNumberValid != true) {
      bloc.add(
          const SetErrorMessage(errorMessage: 'Add a valid mobile number.'));
      return;
    }
    if ((state.password?.length ?? 0) < 8) {
      bloc.add(const SetErrorMessage(
          errorMessage: 'Use a password with at least 8 characters.'));
      return;
    }
    if (!_acceptedTerms) {
      bloc.add(const SetErrorMessage(
          errorMessage: 'Accept the rider onboarding terms to continue.'));
      return;
    }
    bloc.add(SignUpWithEmail(email: state.email!, password: state.password!));
  }
}

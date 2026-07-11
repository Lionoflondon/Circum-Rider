import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../utils/theme/theme.dart';
import '../bloc/auth_bloc.dart';
import 'signin.dart';
import 'widgets/rider_onboarding_shell.dart';

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
  final _vehicleTypeController = TextEditingController();
  final _vehicleMakeModelController = TextEditingController();
  final _vehicleColourController = TextEditingController();
  final _vehicleRegistrationController = TextEditingController();
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _vehicleTypeController.dispose();
    _vehicleMakeModelController.dispose();
    _vehicleColourController.dispose();
    _vehicleRegistrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      final valid = state.isEmailValid == true &&
          (state.password?.length ?? 0) >= 8 &&
          _vehicleTypeController.text.trim().isNotEmpty &&
          _vehicleMakeModelController.text.trim().isNotEmpty &&
          _vehicleColourController.text.trim().isNotEmpty &&
          _vehicleRegistrationController.text.trim().isNotEmpty &&
          _firstNameController.text.trim().isNotEmpty &&
          _lastNameController.text.trim().isNotEmpty &&
          _acceptedTerms;
      return RiderGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _trustChips(),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: RiderGlassTextField(
                    label: 'First name',
                    controller: _firstNameController,
                    onChanged: (value) {
                      setState(() {});
                      context
                          .read<AuthBloc>()
                          .add(FirstNameChanged(firstName: value));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RiderGlassTextField(
                    label: 'Last name',
                    controller: _lastNameController,
                    onChanged: (value) {
                      setState(() {});
                      context
                          .read<AuthBloc>()
                          .add(LastNameChanged(lastName: value));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RiderGlassTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => context
                  .read<AuthBloc>()
                  .add(SignupEmailChanged(email: value)),
              suffix: state.isEmailValid == true
                  ? const Icon(CupertinoIcons.check_mark_circled,
                      color: AppColors.primary)
                  : null,
            ),
            const SizedBox(height: 16),
            RiderGlassTextField(
              label: 'Vehicle type',
              controller: _vehicleTypeController,
              onChanged: (value) {
                setState(() {});
                context.read<AuthBloc>().add(
                      VehicleDetailsChanged(
                        vehicleType: value,
                        vehicleMakeModel: _vehicleMakeModelController.text,
                        vehicleColour: _vehicleColourController.text,
                        vehicleRegistration:
                            _vehicleRegistrationController.text,
                      ),
                    );
              },
            ),
            const SizedBox(height: 16),
            RiderGlassTextField(
              label: 'Vehicle make/model',
              controller: _vehicleMakeModelController,
              onChanged: (value) {
                setState(() {});
                context.read<AuthBloc>().add(
                      VehicleDetailsChanged(
                        vehicleType: _vehicleTypeController.text,
                        vehicleMakeModel: value,
                        vehicleColour: _vehicleColourController.text,
                        vehicleRegistration:
                            _vehicleRegistrationController.text,
                      ),
                    );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: RiderGlassTextField(
                    label: 'Vehicle colour',
                    controller: _vehicleColourController,
                    onChanged: (value) {
                      setState(() {});
                      context.read<AuthBloc>().add(
                            VehicleDetailsChanged(
                              vehicleType: _vehicleTypeController.text,
                              vehicleMakeModel:
                                  _vehicleMakeModelController.text,
                              vehicleColour: value,
                              vehicleRegistration:
                                  _vehicleRegistrationController.text,
                            ),
                          );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RiderGlassTextField(
                    label: 'Registration',
                    controller: _vehicleRegistrationController,
                    onChanged: (value) {
                      setState(() {});
                      context.read<AuthBloc>().add(
                            VehicleDetailsChanged(
                              vehicleType: _vehicleTypeController.text,
                              vehicleMakeModel:
                                  _vehicleMakeModelController.text,
                              vehicleColour: _vehicleColourController.text,
                              vehicleRegistration: value,
                            ),
                          );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RiderGlassTextField(
              label: 'Password',
              controller: _passwordController,
              obscureText: !state.showPassword,
              onChanged: (value) {
                setState(() {});
                context
                    .read<AuthBloc>()
                    .add(SignupPasswordChanged(password: value));
              },
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
            const SizedBox(height: 8),
            _passwordStrength(state.password ?? ''),
            const SizedBox(height: 14),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _acceptedTerms,
              activeColor: AppColors.primary,
              checkColor: Colors.white,
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
            RiderPrimaryButton(
              label: 'Create account',
              isLoading: state.status == Status.loading,
              enabled: valid && state.status != Status.loading,
              onPressed: () => _submit(state),
            ),
            if (!valid)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppText.text(
                  'Complete all fields to continue.',
                  color: AppColors.textGrey,
                  fontSize: 12,
                  textAlign: TextAlign.center,
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
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
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
      children: chips.map((chip) => RiderTrustChip(label: chip)).toList(),
    );
  }

  Widget _passwordStrength(String password) {
    final score = password.length >= 12
        ? 3
        : password.length >= 10
            ? 2
            : password.length >= 8
                ? 1
                : 0;
    final label = score == 0
        ? 'Use 8+ characters'
        : score == 1
            ? 'Password strength: fair'
            : score == 2
                ? 'Password strength: good'
                : 'Password strength: strong';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                decoration: BoxDecoration(
                  color: index < score
                      ? AppColors.primary
                      : Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        AppText.text(label, color: AppColors.textGrey, fontSize: 11),
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
    if (_vehicleTypeController.text.trim().isEmpty ||
        _vehicleMakeModelController.text.trim().isEmpty ||
        _vehicleColourController.text.trim().isEmpty ||
        _vehicleRegistrationController.text.trim().isEmpty) {
      bloc.add(const SetErrorMessage(
          errorMessage: 'Add your vehicle type, model, colour, and plate.'));
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
    bloc.add(VehicleDetailsChanged(
      vehicleType: _vehicleTypeController.text.trim(),
      vehicleMakeModel: _vehicleMakeModelController.text.trim(),
      vehicleColour: _vehicleColourController.text.trim(),
      vehicleRegistration: _vehicleRegistrationController.text.trim(),
    ));
    bloc.add(SignUpWithEmail(email: state.email!, password: state.password!));
  }
}

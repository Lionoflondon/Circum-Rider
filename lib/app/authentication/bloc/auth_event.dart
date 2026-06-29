part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object> get props => [];
}

class SortSessionState extends AuthEvent {
  // BuildContext context;
  // SortSessionState({required this.context});
}

class ChangeAppState extends AuthEvent {
  final String state;
  ChangeAppState({required this.state});
}

class ChangeSelectedPage extends AuthEvent {
  final String page;
  ChangeSelectedPage({required this.page});
}

class AccountRegistrationType extends AuthEvent {
  final bool isemail;
  final dynamic focusManager;
  final dynamic focusNode;
  AccountRegistrationType(
      {required this.isemail, this.focusManager, this.focusNode});
}

class EmailChanged extends AuthEvent {
  final String email;
  EmailChanged({required this.email});
}

class PhoneNumberChanged extends AuthEvent {
  final String phoneNumber;
  PhoneNumberChanged({required this.phoneNumber});
}

class ConfirmPasswordChanged extends AuthEvent {
  final String password;
  ConfirmPasswordChanged({required this.password});
}

class DateOfBirthChanged extends AuthEvent {
  final String dateOfBirth;
  DateOfBirthChanged({required this.dateOfBirth});
}

class VerificationCodeChanged extends AuthEvent {
  final int verificationCode;
  VerificationCodeChanged({required this.verificationCode});
}

class SetVerificationUploadStatus extends AuthEvent {
  final VerificationUploadStatus status;
  const SetVerificationUploadStatus({required this.status});
}

class VerifyEmail extends AuthEvent {}

class SetOTP extends AuthEvent {
  final String otp;
  SetOTP({required this.otp});
}

class SendPhoneOtp extends AuthEvent {}

class VerifyPhoneOtp extends AuthEvent {
  final String otpCode;
  const VerifyPhoneOtp({required this.otpCode});
}

class ResendPhoneOtp extends AuthEvent {}

class PhoneOtpChanged extends AuthEvent {
  final String otpCode;
  const PhoneOtpChanged({required this.otpCode});
}

class ResendVerificationEmail extends AuthEvent {}

class CompleteRiderApplication extends AuthEvent {
  final bool locationEnabled;
  const CompleteRiderApplication({required this.locationEnabled});
}

class ConfirmEmailVerification extends AuthEvent {}

class SetErrorMessage extends AuthEvent {
  final String errorMessage;
  const SetErrorMessage({required this.errorMessage});
}

class SignInWithGoogle extends AuthEvent {}

class SignInWithAppleAuth extends AuthEvent {}

class SignInWithEmail extends AuthEvent {
  final String email;
  final String password;
  const SignInWithEmail({required this.email, required this.password});
}

class SignUpWithEmail extends AuthEvent {
  final String email;
  final String password;
  const SignUpWithEmail({required this.email, required this.password});
}

class UpdatePhoneNumber extends AuthEvent {
  final String value;
  const UpdatePhoneNumber({required this.value});
}

class SetResetPasswordOTP extends AuthEvent {
  final String otp;
  SetResetPasswordOTP({required this.otp});
}

class SubmitOTP extends AuthEvent {}

class SubmitRegistrationDetails extends AuthEvent {}

class SetVerificationMethod extends AuthEvent {
  final String method;
  SetVerificationMethod({required this.method});
}

class RequestForOTP extends AuthEvent {}

class RegisterUser extends AuthEvent {}

class LoginUser extends AuthEvent {}

class SetPin extends AuthEvent {
  final String pin;
  const SetPin({required this.pin});
}

class CreateAuthPin extends AuthEvent {
  final String pin;
  const CreateAuthPin({required this.pin});
}

class UpdatePhone extends AuthEvent {}

class HandleUserLogin extends AuthEvent {
  final data;
  const HandleUserLogin({required this.data});
}

class ResetStatus extends AuthEvent {}

class StartCountDown extends AuthEvent {}

class ResetCountdown extends AuthEvent {}

class SetShowPassword extends AuthEvent {
  final bool val;
  SetShowPassword({required this.val});
}

class ValidatePhoneNumber extends AuthEvent {
  final bool val;

  const ValidatePhoneNumber({required this.val});
}

class VerifySentCode extends AuthEvent {}

class UpdateUserProfile extends AuthEvent {
  final String username;
  const UpdateUserProfile({required this.username});
}

class SubmitVerificationDocuments extends AuthEvent {
  final String? frontImagePath;
  final String? backImagePath;
  final String? workPermitPath;
  final String? idType;
  const SubmitVerificationDocuments(
      {this.frontImagePath,
      this.backImagePath,
      this.workPermitPath,
      this.idType});
}

class RequestLocationData extends AuthEvent {}

class OpenSettingsApp extends AuthEvent {}

class UpdateFirstName extends AuthEvent {
  final String value;
  const UpdateFirstName({required this.value});
}

class UpdateLastName extends AuthEvent {
  final String value;
  const UpdateLastName({required this.value});
}

class UpdateUserProfilePhoto extends AuthEvent {
  final String imagePath;
  const UpdateUserProfilePhoto({required this.imagePath});
}

class SignOut extends AuthEvent {}

class DeleteAccount extends AuthEvent {}

class ResetPassword extends AuthEvent {
  final String email;
  const ResetPassword({required this.email});
}

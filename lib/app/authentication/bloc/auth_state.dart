part of 'auth_bloc.dart';

enum Status {
  initial,
  loading,
  locationRequested,
  success,
  failure,
  unverifiedEmail,
  signedInWithOAuth,
  passwordResetEmailSent,
}

enum AuthenticatedStatus {
  initial,
  incompleteData,
  authenticated,
  pendingApproval
}

enum AppLocationStatus {
  denied,
  unavailalbe,
  available,
}

enum VerificationUploadStatus { initialized, loading, uploaded, failure }

abstract class AuthInitial extends Equatable {
  const AuthInitial();

  // @override
  // List<Object> get props => [];

  // @override
  // String toString() => '$runtimeType{}';
}

class AuthState extends AuthInitial {
  final bool unknownSessionState;
  final bool isAuthenticated;
  final bool isUnAuthenticated;
  final bool registerWithEmail;
  final bool isLoading;

  final String currentState;
  final String? selectedPage;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? email;
  final String? phoneNumber;
  final String? vehicleType;
  final String? vehicleMakeModel;
  final String? vehicleColour;
  final String? vehicleRegistration;
  final String? password;
  final String? confirmPassword;
  final String? dateOfBirth;
  final String? gender;
  final String? pin;
  final String? otp;
  final String? otpCode;
  final String? resetPasswordOtp;
  final String? errorMessage;
  final bool isPhoneOtpSent;
  final bool isPhoneVerified;
  final String? otpErrorMessage;
  final int? verificationCode;
  final String? verificationType;
  final bool showPassword;
  final bool isPhoneNumberValid;
  final bool isEmailValid;
  final String? verificationId;
  final int? resendToken;
  final Position? locationData;
  final bool? isLocationEnabled;
  final bool? hasLocationPermission;
  final String? vehicleRegistrationDocumentStatus;

// information extracted when the uses 0Auth sign in method
  final String? oAuthFirstName;
  final String? oAuthLastName;
  final String? oAuthEmail;
  final String? oAuthPhotoURL;

  final Status status;
  final AppLocationStatus appLocationStatus;
  final VerificationUploadStatus verificationUploadStatus;
  final AuthenticatedStatus authenticatedStatus;
  final RiderAccountState riderAccountState;

  final int countdown;

  final String? profilePhoto;

  @override
  List<Object?> get props => [
        unknownSessionState,
        isAuthenticated,
        isUnAuthenticated,
        registerWithEmail,
        isLoading,
        currentState,
        selectedPage,
        firstName,
        lastName,
        username,
        email,
        phoneNumber,
        vehicleType,
        vehicleMakeModel,
        vehicleColour,
        vehicleRegistration,
        password,
        confirmPassword,
        dateOfBirth,
        gender,
        pin,
        otp,
        otpCode,
        resetPasswordOtp,
        errorMessage,
        isPhoneOtpSent,
        isPhoneVerified,
        otpErrorMessage,
        verificationCode,
        verificationType,
        status,
        countdown,
        showPassword,
        isPhoneNumberValid,
        isEmailValid,
        verificationId,
        resendToken,
        locationData,
        isLocationEnabled,
        hasLocationPermission,
        vehicleRegistrationDocumentStatus,
        appLocationStatus,
        profilePhoto,
        oAuthFirstName,
        oAuthLastName,
        oAuthEmail,
        oAuthPhotoURL,
        verificationUploadStatus,
        authenticatedStatus,
        riderAccountState,
      ];

  const AuthState({
    this.unknownSessionState = false,
    this.isAuthenticated = false,
    this.isUnAuthenticated = true,
    this.registerWithEmail = true,
    this.currentState = AppState.unknownSessionState,
    this.selectedPage,
    this.firstName,
    this.lastName,
    this.username,
    this.email,
    this.phoneNumber,
    this.vehicleType,
    this.vehicleMakeModel,
    this.vehicleColour,
    this.vehicleRegistration,
    this.password,
    this.confirmPassword,
    this.dateOfBirth,
    this.gender,
    this.otp,
    this.otpCode,
    this.resetPasswordOtp,
    this.pin,
    this.isLoading = false,
    this.errorMessage,
    this.isPhoneOtpSent = false,
    this.isPhoneVerified = false,
    this.otpErrorMessage,
    this.verificationCode,
    this.verificationType,
    this.status = Status.initial,
    this.countdown = 30,
    this.showPassword = false,
    this.isPhoneNumberValid = false,
    this.isEmailValid = false,
    this.verificationId,
    this.resendToken,
    this.locationData,
    this.isLocationEnabled,
    this.hasLocationPermission,
    this.vehicleRegistrationDocumentStatus,
    this.appLocationStatus = AppLocationStatus.unavailalbe,
    this.profilePhoto,
    this.oAuthFirstName,
    this.oAuthLastName,
    this.oAuthEmail,
    this.oAuthPhotoURL,
    this.verificationUploadStatus = VerificationUploadStatus.initialized,
    this.authenticatedStatus = AuthenticatedStatus.initial,
    this.riderAccountState = RiderAccountState.onboardingNotStarted,
  });

  AuthState copyWith(
      {bool? unknownSessionState,
      bool? isAuthenticated,
      bool? isUnAuthenticated,
      bool? registerWithEmail,
      String? currentState,
      String? selectedPage,
      String? firstName,
      String? lastName,
      String? username,
      String? email,
      String? phoneNumber,
      String? vehicleType,
      String? vehicleMakeModel,
      String? vehicleColour,
      String? vehicleRegistration,
      String? password,
      String? confirmPassword,
      String? dateOfBirth,
      String? gender,
      String? otp,
      String? otpCode,
      String? resetPasswordOtp,
      String? pin,
      bool? isLoading,
      String? errorMessage,
      bool? isPhoneOtpSent,
      bool? isPhoneVerified,
      String? otpErrorMessage,
      int? verificationCode,
      String? verificationType,
      Status? status,
      int? countdown,
      bool? showPassword,
      bool? isPhoneNumberValid,
      bool? isEmailValid,
      String? verificationId,
      int? resendToken,
      Position? locationData,
      bool? isLocationEnabled,
      bool? hasLocationPermission,
      String? vehicleRegistrationDocumentStatus,
      AppLocationStatus? appLocationStatus,
      AuthenticatedStatus? authenticatedStatus,
      RiderAccountState? riderAccountState,
      String? profilePhoto,
      String? oAuthFirstName,
      String? oAuthLastName,
      String? oAuthEmail,
      String? oAuthPhotoURL,
      VerificationUploadStatus? verificationUploadStatus}) {
    return AuthState(
        unknownSessionState: unknownSessionState ?? this.unknownSessionState,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isUnAuthenticated: isUnAuthenticated ?? this.isUnAuthenticated,
        registerWithEmail: registerWithEmail ?? this.registerWithEmail,
        currentState: currentState ?? this.currentState,
        selectedPage: selectedPage ?? this.selectedPage,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        username: username ?? this.username,
        email: email ?? this.email,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        vehicleType: vehicleType ?? this.vehicleType,
        vehicleMakeModel: vehicleMakeModel ?? this.vehicleMakeModel,
        vehicleColour: vehicleColour ?? this.vehicleColour,
        vehicleRegistration: vehicleRegistration ?? this.vehicleRegistration,
        password: password ?? this.password,
        confirmPassword: confirmPassword ?? this.confirmPassword,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        gender: gender ?? this.gender,
        otp: otp ?? this.otp,
        otpCode: otpCode ?? this.otpCode,
        resetPasswordOtp: resetPasswordOtp ?? this.resetPasswordOtp,
        pin: pin ?? this.pin,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        isPhoneOtpSent: isPhoneOtpSent ?? this.isPhoneOtpSent,
        isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
        otpErrorMessage: otpErrorMessage,
        verificationCode: verificationCode ?? this.verificationCode,
        verificationType: verificationType ?? this.verificationType,
        status: status ?? this.status,
        countdown: countdown ?? this.countdown,
        showPassword: showPassword ?? this.showPassword,
        isPhoneNumberValid: isPhoneNumberValid ?? this.isPhoneNumberValid,
        isEmailValid: isEmailValid ?? this.isEmailValid,
        verificationId: verificationId ?? this.verificationId,
        resendToken: resendToken ?? this.resendToken,
        locationData: locationData ?? this.locationData,
        isLocationEnabled: isLocationEnabled ?? this.isLocationEnabled,
        hasLocationPermission:
            hasLocationPermission ?? this.hasLocationPermission,
        vehicleRegistrationDocumentStatus: vehicleRegistrationDocumentStatus ??
            this.vehicleRegistrationDocumentStatus,
        appLocationStatus: appLocationStatus ?? this.appLocationStatus,
        authenticatedStatus: authenticatedStatus ?? this.authenticatedStatus,
        riderAccountState: riderAccountState ?? this.riderAccountState,
        profilePhoto: profilePhoto ?? this.profilePhoto,
        oAuthFirstName: oAuthFirstName ?? this.oAuthFirstName,
        oAuthLastName: oAuthLastName ?? this.oAuthLastName,
        oAuthEmail: oAuthEmail ?? this.oAuthEmail,
        oAuthPhotoURL: oAuthPhotoURL ?? this.oAuthPhotoURL,
        verificationUploadStatus:
            verificationUploadStatus ?? this.verificationUploadStatus);
  }
}

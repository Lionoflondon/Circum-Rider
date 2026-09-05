import '../../referrals/rider_referral.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:circum_rider/extension/email_validation.dart';
import 'package:circum_rider/helper/location_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:circum_rider/utils/app_state/app_state.dart';
// import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../rider_account/rider_account_state.dart';
import '../apple_auth_nonce.dart';
import '../rider_auth_error.dart';
import '../rider_auth_bootstrap.dart';
import '../rider_terminal_operations.dart';
// import '../../onboarding/view/onboarding.dart';

part 'auth_event.dart';
part 'auth_state.dart';
part 'signup_event.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static const _authOperationTimeout = Duration(seconds: 20);
  static const _authRestoreTimeout = Duration(seconds: 12);
  static const _signupOperationTimeout = Duration(seconds: 30);
  static const _signupBootstrapTimeout = Duration(seconds: 20);
  static const _profilePhotoOperationTimeout = Duration(seconds: 30);
  static const _documentUploadOperationTimeout = Duration(seconds: 45);

  AuthBloc() : super(const AuthState()) {
    FirebaseAuth auth = FirebaseAuth.instance;
    // Init firestore and geoFlutterFire
    // final geo = GeoFlutterFire();
    LocationHelper locationHelper = LocationHelper();

    FirebaseFirestore db = FirebaseFirestore.instance;
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

    Future<void> ensureRiderRothWallet(User user) async {
      await functions.httpsCallable('ensureRiderRothWallet').call({
        'riderId': user.uid,
        if (user.email != null) 'email': user.email,
      }).timeout(_authOperationTimeout);
    }

    void logRiderAuthError({
      required Object error,
      required String path,
      required String step,
      String? riderDocumentId,
    }) {
      final code = error is FirebaseException ? error.code : error.runtimeType;
      final category = error is TimeoutException
          ? 'timeout'
          : error is FirebaseException
              ? 'firebase'
              : 'unexpected';
      final riderRef =
          riderDocumentId == null ? 'unknown' : riderDocumentId.hashCode;
      final pathSurface = path.split('/').first;
      debugPrint(
        'Rider auth diagnostic stage=$step category=$category code=$code '
        'surface=$pathSurface riderRef=$riderRef',
      );
    }

    Future<void> upsertRiderOnboarding({
      required User user,
      required Map<String, dynamic> data,
    }) async {
      await functions.httpsCallable('advanceRiderOnboarding').call({
        'stage': data['onboardingStatus'] ?? data['stage'] ?? 'profile_started',
        if (data['name'] != null) 'name': data['name'],
        if (data['locationEnabled'] != null)
          'locationEnabled': data['locationEnabled'],
        if (data['position'] != null) 'position': data['position'],
      }).timeout(_authOperationTimeout);
    }

    Future<void> ensureRiderOnboardingStarted({
      required User user,
      String? name,
    }) async {
      final rider = await db
          .collection('riders')
          .doc(user.uid)
          .get()
          .timeout(_authRestoreTimeout);
      final status = rider.data()?['onboardingStatus']?.toString();
      if (!riderOnboardingNeedsProfileStart(status)) return;
      await functions.httpsCallable('updateRiderProfile').call({
        if (name != null && name.isNotEmpty) 'fullName': name
      }).timeout(_authOperationTimeout);
      await upsertRiderOnboarding(user: user, data: {
        if (name != null && name.isNotEmpty) 'name': name,
        'onboardingStatus': 'profile_started',
      });
    }

    Future<String?> vehicleRegistrationDocumentStatus(String uid) async {
      final doc = await db
          .collection('riderDocuments')
          .doc('${uid}_vehicle_registration')
          .get()
          .timeout(_authRestoreTimeout);
      if (!doc.exists) return null;
      return '${doc.data()?['status'] ?? doc.data()?['verificationStatus'] ?? ''}'
          .trim();
    }

    void listenForPermissionStatus() async {
      await permission_handler.Permission.location.status;
    }

    if (!kIsWeb) listenForPermissionStatus();

    on<AuthEvent>((event, emit) async {
      if (event is SortSessionState) {
        const storage = FlutterSecureStorage();
        User? user = auth.currentUser;

        if (user != null) {
          String? phone;
          try {
            phone = (await storage
                .readAll()
                .timeout(_authOperationTimeout))["phone"];
          } catch (error) {
            logRiderAuthError(
              error: error,
              path: 'secure_storage',
              step: 'session_restore_storage',
              riderDocumentId: user.uid,
            );
          }
          String? riderPhone = phone;
          bool phoneVerified = false;
          bool riderAccessVerified = false;
          String? vehicleDocStatus;
          String? riderPhoto;
          var authenticatedStatus = AuthenticatedStatus.authenticated;
          var riderAccountState = RiderAccountState.onboardingNotStarted;
          try {
            var records = await Future.wait([
              db.collection('riders').doc(user.uid).get(),
              db.collection('riderProfiles').doc(user.uid).get(),
            ]).timeout(_authRestoreTimeout);
            if (!records[0].exists && !records[1].exists) {
              await runRiderAuthBootstrap(
                timeout: _signupBootstrapTimeout,
                updateDisplayName: () async {},
                initializeProfile: () => ensureRiderOnboardingStarted(
                  user: user,
                  name: user.displayName?.trim(),
                ),
                initializeRothWallet: () => ensureRiderRothWallet(user),
              );
              records = await Future.wait([
                db.collection('riders').doc(user.uid).get(),
                db.collection('riderProfiles').doc(user.uid).get(),
              ]).timeout(_authRestoreTimeout);
            }
            riderAccessVerified = records[0].exists || records[1].exists;
            final riderRecord = records[0].data() ?? const <String, dynamic>{};
            final riderProfile = records[1].data() ?? const <String, dynamic>{};
            final riderData = <String, dynamic>{
              ...riderProfile,
              ...riderRecord,
            };
            riderPhone = riderData['phone'] as String? ?? phone;
            riderPhoto =
                '${riderData['profileThumbnailUrl'] ?? riderData['profilePhotoUrl'] ?? riderData['photoURL'] ?? riderData['photoUrl'] ?? ''}'
                    .trim();
            if (riderPhoto.isEmpty || riderPhoto == 'null') riderPhoto = null;
            phoneVerified = riderData['phoneVerified'] == true;
            riderAccountState = RiderAccountStateResolver.resolveRecords(
              rider: riderRecord,
              riderProfile: riderProfile,
            );
            if (!RiderAccountStateResolver.canOperate(riderAccountState)) {
              authenticatedStatus =
                  riderAccountState == RiderAccountState.onboardingNotStarted ||
                          riderAccountState ==
                              RiderAccountState.onboardingInProgress ||
                          riderAccountState ==
                              RiderAccountState.moreInformationRequired
                      ? AuthenticatedStatus.incompleteData
                      : AuthenticatedStatus.pendingApproval;
            }
            vehicleDocStatus =
                await vehicleRegistrationDocumentStatus(user.uid);
          } catch (error) {
            final cause =
                error is RiderBootstrapException ? error.cause : error;
            if (cause is FirebaseException &&
                cause.code == 'permission-denied') {
              try {
                await auth.signOut().timeout(_authOperationTimeout);
              } catch (_) {}
              emit(
                state.copyWith(
                  status: Status.failure,
                  currentState: AppState.unauthenticated,
                  errorMessage:
                      'This account belongs to Sender or Admin. Sign in on the correct Circum app.',
                  clearSensitiveAuthFields: true,
                ),
              );
              return;
            }
            logRiderAuthError(
              error: error,
              path: 'riders/${user.uid}',
              step: 'session_restore',
              riderDocumentId: user.uid,
            );
          }

          if (!riderAccessVerified) {
            emit(state.copyWith(
                status: Status.failure,
                currentState: AppState.unauthenticated,
                errorMessage:
                    'We could not verify Rider access. Sign in again to retry.',
                clearSensitiveAuthFields: true));
            return;
          }
          try {
            final prefs = await SharedPreferences.getInstance()
                .timeout(_authOperationTimeout);
            await prefs
                .setString('riderId', user.uid)
                .timeout(_authOperationTimeout);
          } catch (error) {
            logRiderAuthError(
              error: error,
              path: 'shared_preferences',
              step: 'session_restore_preferences',
              riderDocumentId: user.uid,
            );
          }
          // You can also access user information like user.displayName, user.email, etc.
          emit(state.copyWith(
              currentState: AppState.authenticated,
              username: user.displayName,
              phoneNumber: riderPhone ?? user.phoneNumber,
              email: user.email,
              profilePhoto: riderPhoto ?? user.photoURL,
              isPhoneVerified: phoneVerified,
              vehicleRegistrationDocumentStatus: vehicleDocStatus,
              riderAccountState: riderAccountState,
              authenticatedStatus: authenticatedStatus));
        } else {
          emit(state.copyWith(currentState: AppState.unauthenticated));
        }
      }

      if (event is ResetStatus) {
        emit(state.copyWith(status: Status.initial));
      }

      if (event is StartCountDown) {
        int countdown = state.countdown;
        const oneSec = Duration(seconds: 1);
        Timer.periodic(
          oneSec,
          (Timer timer) {
            if (state.countdown == 0) {
              timer.cancel();
            } else {
              emit(state.copyWith(countdown: countdown--));
            }
          },
        );
      }

      if (event is ResetCountdown) {
        if (state.countdown < 30) {
          emit(state.copyWith(countdown: 59));
          add(StartCountDown());
        } else {
          emit(state.copyWith(countdown: 30));
          add(StartCountDown());
        }
      }

      if (event is SignupEmailChanged) {
        emit(state.copyWith(email: event.email));
        if (event.email!.isValidEmail()) {
          emit(state.copyWith(isEmailValid: true));
        } else {
          emit(state.copyWith(isEmailValid: false));
        }
      }

      if (event is PhoneNumberChanged) {
        emit(state.copyWith(phoneNumber: event.phoneNumber));
      }

      if (event is VehicleDetailsChanged) {
        emit(state.copyWith(
          vehicleType: event.vehicleType,
          vehicleMakeModel: event.vehicleMakeModel,
          vehicleColour: event.vehicleColour,
          vehicleRegistration: event.vehicleRegistration,
        ));
      }

      if (event is SignupPasswordChanged) {
        // Passwords must never be persisted in bloc state. The canonical
        // email auth flow passes credentials directly to Firebase Auth.
        emit(state.copyWith(clearSensitiveAuthFields: true));
      }

      if (event is ConfirmPasswordChanged) {
        emit(state.copyWith(clearSensitiveAuthFields: true));
      }
      if (event is DateOfBirthChanged) {
        if (event.dateOfBirth.length == 10) {
          var inputFormat = DateFormat('dd/MM/yyyy');
          var date1 = inputFormat.parse(event.dateOfBirth);

          var outputFormat = DateFormat('yyyy-MM-dd');
          var date2 = outputFormat.format(date1);
          emit(state.copyWith(dateOfBirth: date2));
        } else {
          emit(state.copyWith(dateOfBirth: event.dateOfBirth));
        }
      }

      if (event is SetOTP) {
        emit(state.copyWith(otp: event.otp, otpCode: event.otp));
      }

      if (event is PhoneOtpChanged) {
        emit(state.copyWith(otpCode: event.otpCode, otpErrorMessage: null));
      }

      if (event is SendPhoneOtp || event is ResendPhoneOtp) {
        final phoneNumber = state.phoneNumber;
        if (phoneNumber == null || phoneNumber.trim().isEmpty) {
          emit(state.copyWith(
              status: Status.failure,
              otpErrorMessage: 'Add a mobile number to continue.'));
          return;
        }

        final completer = Completer<void>();
        String? verificationId;
        int? resendToken;

        try {
          emit(state.copyWith(status: Status.loading, otpErrorMessage: null));
          await auth.verifyPhoneNumber(
            phoneNumber: phoneNumber,
            forceResendingToken:
                event is ResendPhoneOtp ? state.resendToken : null,
            verificationCompleted: (credential) {},
            verificationFailed: (error) {
              logRiderAuthError(
                error: error,
                path: 'riders/${auth.currentUser?.uid ?? 'unknown'}',
                step: 'phone_otp_send',
                riderDocumentId: auth.currentUser?.uid,
              );
              if (!completer.isCompleted) completer.completeError(error);
            },
            codeSent: (id, token) {
              verificationId = id;
              resendToken = token;
              if (!completer.isCompleted) completer.complete();
            },
            codeAutoRetrievalTimeout: (id) {
              verificationId = id;
              if (!completer.isCompleted) {
                completer.completeError(TimeoutException('phone_otp_send'));
              }
            },
          );
          await completer.future.timeout(_authOperationTimeout);
          emit(state.copyWith(
            verificationId: verificationId,
            resendToken: resendToken ?? state.resendToken,
            isPhoneOtpSent: true,
            status: Status.success,
            otpErrorMessage: null,
          ));
        } catch (error) {
          emit(state.copyWith(
            status: Status.failure,
            otpErrorMessage:
                'We could not send the code. Please check the number.',
          ));
        }
      }

      if (event is VerifyPhoneOtp) {
        final user = auth.currentUser;
        final verificationId = state.verificationId;
        if (user == null || verificationId == null) {
          emit(state.copyWith(
            status: Status.failure,
            otpErrorMessage: 'We could not verify this session. Try again.',
          ));
          return;
        }

        try {
          emit(state.copyWith(status: Status.loading, otpErrorMessage: null));
          final credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: event.otpCode,
          );
          try {
            await user
                .linkWithCredential(credential)
                .timeout(_authOperationTimeout);
          } on FirebaseAuthException catch (error) {
            if (error.code != 'provider-already-linked' &&
                error.code != 'credential-already-in-use') {
              rethrow;
            }
            logRiderAuthError(
              error: error,
              path: 'riders/${user.uid}',
              step: 'phone_credential_already_linked',
              riderDocumentId: user.uid,
            );
          }

          await upsertRiderOnboarding(user: user, data: {
            'phone': state.phoneNumber,
            'phoneVerified': true,
            'phoneVerifiedAt': FieldValue.serverTimestamp(),
            'onboardingStatus': 'phone_verified',
          }).timeout(_authOperationTimeout);
          await user.sendEmailVerification().timeout(_authOperationTimeout);

          emit(state.copyWith(
            otpCode: event.otpCode,
            isPhoneVerified: true,
            status: Status.unverifiedEmail,
            otpErrorMessage: null,
          ));
        } on FirebaseAuthException catch (error) {
          logRiderAuthError(
            error: error,
            path: 'riders/${user.uid}',
            step: 'phone_otp_verify',
            riderDocumentId: user.uid,
          );
          emit(state.copyWith(
            status: Status.failure,
            otpErrorMessage: error.code == 'invalid-verification-code'
                ? 'That code is invalid or expired.'
                : 'We could not verify that code. Please try again.',
          ));
        } catch (error) {
          logRiderAuthError(
            error: error,
            path: 'riders/${user.uid}',
            step: 'phone_otp_verify',
            riderDocumentId: user.uid,
          );
          emit(state.copyWith(
            status: Status.failure,
            otpErrorMessage: 'We could not verify that code. Please try again.',
          ));
        }
      }

      if (event is ResendVerificationEmail) {
        try {
          emit(state.copyWith(status: Status.loading));
          await auth.currentUser
              ?.sendEmailVerification()
              .timeout(_authOperationTimeout);
          emit(state.copyWith(status: Status.success));
        } catch (error) {
          emit(state.copyWith(
              status: Status.failure,
              errorMessage: 'We could not resend the email. Try again.'));
        }
      }

      if (event is SetPin) {
        emit(state.copyWith(pin: event.pin));
        add(SubmitOTP());
      }

      if (event is SignInWithAppleAuth) {
        try {
          emit(state.copyWith(status: Status.loading));
          final rawNonce = generateAppleAuthNonce();
          final appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
            nonce: sha256Nonce(rawNonce),
          ).timeout(_authOperationTimeout);

          // SignInWithApple

          // final GoogleSignInAuthentication googleSignInAuthentication =
          //     await googleSignInAccount.authentication;

          // Create an `OAuthCredential` from the credential returned by Apple.
          final oauthCredential = OAuthProvider("apple.com").credential(
            idToken: appleCredential.identityToken,
            rawNonce: rawNonce,
          );

          // Sign in with credential
          UserCredential userCredential = await auth
              .signInWithCredential(oauthCredential)
              .timeout(_authOperationTimeout);

          emit(state.copyWith(
              username: userCredential.user?.displayName,
              email: userCredential.user?.email,
              profilePhoto: userCredential.user?.photoURL,
              status: Status.signedInWithOAuth,
              currentState: AppState.authenticated,
              authenticatedStatus: appleCredential.givenName == null &&
                      userCredential.user?.displayName == null
                  ? AuthenticatedStatus.incompleteData
                  : AuthenticatedStatus.authenticated));

          final appleName =
              '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                  .trim();
          add(BootstrapOAuthRider(
            username: appleName.isEmpty
                ? userCredential.user?.displayName
                : appleName,
          ));
          // await googleSignIn.signOut();
        } catch (error) {
          logRiderAuthError(
            error: error,
            path: 'oauth/apple',
            step: 'apple_sign_in',
            riderDocumentId: auth.currentUser?.uid,
          );
          emit(state.copyWith(
            status: Status.failure,
            errorMessage: 'Apple sign-in could not be completed. Try again.',
            clearSensitiveAuthFields: true,
          ));
        }
      }

      if (event is SignInWithGoogle) {
        try {
          emit(state.copyWith(status: Status.loading));
          final GoogleSignIn googleSignIn = GoogleSignIn();
          await googleSignIn.signOut().timeout(_authOperationTimeout);
          final GoogleSignInAccount? googleSignInAccount =
              await googleSignIn.signIn().timeout(_authOperationTimeout);

          if (googleSignInAccount == null) {
            emit(state.copyWith(status: Status.initial));
            return;
          }

          final GoogleSignInAuthentication googleSignInAuthentication =
              await googleSignInAccount.authentication
                  .timeout(_authOperationTimeout);

          final credential = GoogleAuthProvider.credential(
            accessToken: googleSignInAuthentication.accessToken,
            idToken: googleSignInAuthentication.idToken,
          );

          // Sign in with credential
          UserCredential userCredential =
              await auth.signInWithCredential(credential).timeout(
                    _authOperationTimeout,
                  );

          emit(state.copyWith(
              username: userCredential.user?.displayName,
              email: userCredential.user?.email,
              profilePhoto: userCredential.user?.photoURL,
              status: Status.signedInWithOAuth,
              currentState: AppState.authenticated,
              authenticatedStatus: AuthenticatedStatus.authenticated));

          add(BootstrapOAuthRider(
            username: userCredential.user?.displayName?.trim(),
          ));
          // await googleSignIn.signOut();
        } catch (error) {
          logRiderAuthError(
            error: error,
            path: 'oauth/google',
            step: 'google_sign_in',
            riderDocumentId: auth.currentUser?.uid,
          );
          emit(state.copyWith(
            status: Status.failure,
            errorMessage: 'Google sign-in could not be completed. Try again.',
            clearSensitiveAuthFields: true,
          ));
        }
      }

      if (event is RequestForOTP) {
        // emit(state.copyWith(isLoading: true, status: Status.loading));

        final completer = Completer<bool>();

        String? verificationIdValue;
        int? resendTokenValue;

        try {
          emit(state.copyWith(status: Status.loading));
          await auth.verifyPhoneNumber(
            phoneNumber: state.phoneNumber,
            verificationCompleted: (_) {},
            verificationFailed: (error) {
              if (!completer.isCompleted) completer.completeError(error);
            },
            codeSent: (String verificationId, int? resendToken) async {
              verificationIdValue = verificationId;
              resendTokenValue = resendToken;
              if (!completer.isCompleted) completer.complete(true);
            },
            codeAutoRetrievalTimeout: (_) {
              if (!completer.isCompleted) {
                completer.completeError(TimeoutException('phone_otp_request'));
              }
            },
          );
          await completer.future.timeout(_authOperationTimeout);
          emit(state.copyWith(
              verificationId: verificationIdValue,
              resendToken: resendTokenValue,
              status: Status.success));
        } catch (e) {
          logRiderAuthError(
            error: e,
            path: 'phone/request_otp',
            step: 'request_phone_otp',
            riderDocumentId: auth.currentUser?.uid,
          );
          emit(state.copyWith(
              errorMessage: 'Verification code could not be sent. Try again.',
              isLoading: false,
              status: Status.failure));
        }
      }

      if (event is VerifySentCode) {
        try {
          // Create a PhoneAuthCredential with the code
          PhoneAuthCredential credential = PhoneAuthProvider.credential(
              verificationId: state.verificationId!, smsCode: '${state.otp}');
          if (auth.currentUser != null) {
            await auth.currentUser
                ?.linkWithCredential(credential)
                .timeout(_authOperationTimeout);
          } else {
            // Sign the user in (or link) with the credential
            final UserCredential userCredential = await auth
                .signInWithCredential(credential)
                .timeout(_authOperationTimeout);

            if (userCredential.user?.displayName == null) {
              if (state.oAuthFirstName == null) {
                emit(state.copyWith(
                    authenticatedStatus: AuthenticatedStatus.incompleteData,
                    currentState: AppState.authenticated));
              } else {
                add(UpdateUserProfile(
                    username:
                        "${state.oAuthFirstName} ${state.oAuthLastName}"));
                emit(state.copyWith(
                    status: Status.success,
                    username: "${state.oAuthFirstName} ${state.oAuthLastName}",
                    profilePhoto: state.oAuthPhotoURL,
                    email: state.oAuthEmail,
                    phoneNumber: userCredential.user?.phoneNumber,
                    currentState: AppState.authenticated));
              }
            } else {
              emit(state.copyWith(
                  status: Status.success,
                  username: userCredential.user?.displayName,
                  profilePhoto: userCredential.user?.photoURL,
                  email: userCredential.user?.email,
                  phoneNumber: userCredential.user?.phoneNumber,
                  currentState: AppState.authenticated));
            }
          }
        } on FirebaseAuthException catch (error) {
          emit(state.copyWith(
              status: Status.failure,
              isLoading: false,
              errorMessage: riderOtpFailureMessage(error.code)));
        } on TimeoutException {
          emit(state.copyWith(
              status: Status.failure,
              isLoading: false,
              errorMessage:
                  'Verification took too long. Check your connection and try again.'));
        } catch (_) {
          emit(state.copyWith(
              status: Status.failure,
              isLoading: false,
              errorMessage:
                  'Your verification code could not be confirmed. Please try again.'));
        }
      }

      if (event is UpdateUserProfile) {
        try {
          emit(state.copyWith(status: Status.loading));
          final User? user = auth.currentUser;
          if (user == null) {
            emit(state.copyWith(
                status: Status.failure,
                errorMessage: 'Please sign in again to continue.'));
            return;
          }
          await user.updateDisplayName(event.username).timeout(
                _authOperationTimeout,
              );
          // if (state.oAuthEmail != null) {
          //   await user!.updateEmail(state.oAuthEmail!);
          // }

          // if (state.oAuthPhotoURL != null) {
          //   await user!.updatePhotoURL(state.oAuthPhotoURL!);
          // }

          final SharedPreferences prefs =
              await SharedPreferences.getInstance().timeout(
            _authOperationTimeout,
          );

          await prefs.setString('riderId', user.uid).timeout(
                _authOperationTimeout,
              );

          await functions.httpsCallable('updateRiderProfile').call({
            'name': event.username,
            'phone': user.phoneNumber ?? state.phoneNumber,
            'phoneVerified': state.isPhoneVerified,
            'vehicle': {
              'type': state.vehicleType?.trim(),
              'makeModel': state.vehicleMakeModel?.trim(),
              'colour': state.vehicleColour?.trim(),
              'plateNumber': state.vehicleRegistration?.trim(),
            },
            'vehicleType': state.vehicleType?.trim(),
            'vehicleMakeModel': state.vehicleMakeModel?.trim(),
            'vehicleColour': state.vehicleColour?.trim(),
            'vehicleRegistration': state.vehicleRegistration?.trim(),
            'plateNumber': state.vehicleRegistration?.trim(),
            'typeOfVehicle': state.vehicleType?.trim(),
            'section': 'profile_details',
          }).timeout(_authOperationTimeout);
          await upsertRiderOnboarding(user: user, data: {
            'onboardingStatus': 'profile_complete',
          }).timeout(_authOperationTimeout);

          await ensureRiderRothWallet(user).timeout(_authOperationTimeout);

          emit(state.copyWith(
              status: Status.success,
              authenticatedStatus: AuthenticatedStatus.authenticated,
              username: event.username));
        } catch (error) {
          logRiderAuthError(
            error: error,
            path: 'riders/${auth.currentUser?.uid ?? 'unknown'}',
            step: 'authenticated_profile_update',
            riderDocumentId: auth.currentUser?.uid,
          );
          emit(state.copyWith(
            status: Status.success,
            currentState: AppState.authenticated,
            authenticatedStatus: AuthenticatedStatus.incompleteData,
            errorMessage:
                'You are signed in. Some account details are still loading.',
          ));
        }
      }
      if (event is BootstrapOAuthRider) {
        final user = auth.currentUser;
        if (user == null) {
          emit(state.copyWith(
            status: Status.failure,
            errorMessage: 'Please sign in again to continue.',
          ));
        } else {
          try {
            final name = event.username?.trim() ?? '';
            await runRiderAuthBootstrap(
              timeout: _signupBootstrapTimeout,
              updateDisplayName: () async {
                if (name.isNotEmpty && user.displayName != name) {
                  await user.updateDisplayName(name);
                }
              },
              initializeProfile: () async {
                await functions.httpsCallable('updateRiderProfile').call({
                  if (name.isNotEmpty) 'name': name,
                  'phone': user.phoneNumber ?? state.phoneNumber,
                  'phoneVerified': state.isPhoneVerified,
                  'section': 'profile_details',
                });
                await ensureRiderOnboardingStarted(user: user, name: name);
              },
              initializeRothWallet: () => ensureRiderRothWallet(user),
            );
            emit(state.copyWith(
              status: Status.success,
              username: name.isEmpty ? user.displayName : name,
              currentState: AppState.authenticated,
              authenticatedStatus: AuthenticatedStatus.incompleteData,
            ));
          } on RiderBootstrapException catch (error) {
            logRiderAuthError(
              error: error.cause,
              path: 'riders/${user.uid}',
              step: 'oauth_bootstrap_${error.stage.name}',
              riderDocumentId: user.uid,
            );
            emit(state.copyWith(
              status: Status.success,
              currentState: AppState.authenticated,
              authenticatedStatus: AuthenticatedStatus.incompleteData,
              errorMessage:
                  'You are signed in. Some account details are still loading.',
            ));
          }
        }
      }
      if (event is SubmitOTP) {
        emit(state.copyWith(isLoading: true, status: Status.success));
      }

      if (event is FirstNameChanged) {
        emit(state.copyWith(firstName: event.firstName));
      }

      if (event is LastNameChanged) {
        return emit(state.copyWith(lastName: event.lastName));
      }

      if (event is UsernameChanged) {
        return emit(state.copyWith(username: event.username));
      }

      if (event is GenderChanged) {
        return emit(state.copyWith(gender: event.gender.toUpperCase().trim()));
      }

      if (event is SetVerificationMethod) {
        emit(state.copyWith(verificationType: event.method));
        // return;
      }

      if (event is LoginUser) {
        emit(state.copyWith(isLoading: true, status: Status.loading));
        emit(state.copyWith(
          status: Status.failure,
          isLoading: false,
          errorMessage: 'Please use the secure email sign-in flow.',
        ));
      }
      if (event is SetResetPasswordOTP) {
        emit(state.copyWith(resetPasswordOtp: event.otp));
      }

      if (event is ForgotPassword) {
        final email = state.email?.trim() ?? '';
        if (email.isEmpty) {
          emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage: 'Enter your email address first.',
          ));
          return;
        }
        try {
          emit(state.copyWith(
            status: Status.loading,
            isLoading: true,
            errorMessage: null,
          ));
          await auth
              .sendPasswordResetEmail(email: email)
              .timeout(_authOperationTimeout);
          emit(state.copyWith(
            status: Status.passwordResetEmailSent,
            isLoading: false,
          ));
        } on FirebaseAuthException catch (error) {
          emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage: switch (error.code) {
              'invalid-email' => 'Enter a valid email address.',
              'user-not-found' => 'No Rider account was found for that email.',
              'network-request-failed' =>
                'Check your connection and try again.',
              'too-many-requests' =>
                'Too many attempts. Wait a moment and try again.',
              _ => 'Password reset could not be completed. Please try again.',
            },
          ));
        } on TimeoutException {
          emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage:
                'Password reset timed out. Check your connection and try again.',
          ));
        } catch (error) {
          logRiderAuthError(
            error: error,
            path: 'auth',
            step: 'password_reset',
            riderDocumentId: auth.currentUser?.uid,
          );
          emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage:
                'Password reset could not be completed. Please try again.',
          ));
        }
      }

      if (event is SetShowPassword) {
        emit(state.copyWith(showPassword: event.val));
      }

      if (event is ValidatePhoneNumber) {
        emit(state.copyWith(isPhoneNumberValid: event.val));
      }

      if (event is RequestLocationData) {
        // Obtain shared preferences.
        try {
          emit(state.copyWith(status: Status.locationRequested));
          final User? user = auth.currentUser;
          if (user == null) {
            emit(state.copyWith(
              status: Status.failure,
              errorMessage: 'Please sign in again to continue.',
            ));
            return;
          }
          final SharedPreferences prefs =
              await SharedPreferences.getInstance().timeout(
            _authOperationTimeout,
          );

          Position locationData = await locationHelper
              .enableLocation()
              .timeout(_authOperationTimeout);

          // Position myPosition = Position(
          //     longitude: 7.496811,
          //     latitude: 9.078255,
          //     timestamp: DateTime.timestamp(),
          //     accuracy: 0.9,
          //     altitude: 10,
          //     altitudeAccuracy: 0.9,
          //     heading: 0,
          //     headingAccuracy: 0,
          //     speed: 0,
          //     speedAccuracy: 0);
          await prefs.setString('riderId', user.uid).timeout(
                _authOperationTimeout,
              );
          await prefs
              .setDouble('longitude', locationData.longitude)
              .timeout(_authOperationTimeout);
          await prefs
              .setDouble('latitude', locationData.latitude)
              .timeout(_authOperationTimeout);
          await prefs
              .setString('timestamp', locationData.timestamp.toIso8601String())
              .timeout(
                _authOperationTimeout,
              );
          await prefs
              .setDouble('altitude', locationData.altitude)
              .timeout(_authOperationTimeout);

          GeoFirePoint myLocation = GeoFirePoint(
              GeoPoint(locationData.latitude, locationData.longitude));
          emit(state.copyWith(
            locationData: locationData,
            hasLocationPermission: true,
            isLocationEnabled: true,
          ));
          await db.collection("riders").doc(user.uid).update({
            'position': myLocation.data,
            'locationEnabled': true,
          }).timeout(_authOperationTimeout);
          await upsertRiderOnboarding(user: user, data: {
            'onboardingStatus': 'profile_complete',
            'locationEnabled': true,
            'position': myLocation.data,
          });
          await ensureRiderRothWallet(user).timeout(_authOperationTimeout);
        } catch (e) {
          if (e == 'Location permissions are permanently denied') {
            emit(state.copyWith(
                hasLocationPermission: false,
                status: Status.locationRequested));
          }
        }
      }

      if (event is OpenSettingsApp) {
        try {
          final User? user = auth.currentUser;
          Position locationData = await locationHelper.enableLocation();

          GeoFirePoint myLocation = GeoFirePoint(
              GeoPoint(locationData.latitude, locationData.longitude));
          emit(state.copyWith(
              locationData: locationData,
              hasLocationPermission: true,
              isLocationEnabled: true,
              status: Status.locationRequested));
          await db
              .collection("riders")
              .doc(user?.uid)
              .update({'position': myLocation.data});
        } catch (e) {
          if (e == 'Location permissions are permanently denied') {
            await Geolocator.openLocationSettings();
          }

          if (e == 'Location services are disabled') {
            await Geolocator.openAppSettings();
          }
        }
      }

      if (event is CompleteRiderApplication) {
        final user = auth.currentUser;
        if (user == null) return;
        try {
          await upsertRiderOnboarding(user: user, data: {
            'locationEnabled': event.locationEnabled,
            'onboardingStatus': 'profile_complete',
          });
          await ensureRiderRothWallet(user).timeout(_authOperationTimeout);
          emit(state.copyWith(status: Status.locationRequested));
        } catch (error) {
          logRiderAuthError(
            error: error,
            path: 'riders/${user.uid}',
            step: 'application_submit',
            riderDocumentId: user.uid,
          );
          emit(state.copyWith(
              status: Status.failure,
              errorMessage: 'We could not submit your application.'));
        }
      }
    });

    on<UpdateFirstName>(((event, emit) async {
      try {
        User? user = auth.currentUser;
        final lastName = state.username?.trim().split(' ').last;

        if (lastName != null) {
          await user?.updateDisplayName('${event.value} $lastName');
          emit(state.copyWith(username: '${event.value} $lastName'));
        } else {
          await user?.updateDisplayName(event.value);
          emit(state.copyWith(username: event.value));
        }
      } catch (_) {
        emit(state.copyWith(status: Status.failure));
      }
    }));

    on<UpdateLastName>(((event, emit) async {
      try {
        User? user = auth.currentUser;
        final firstName = state.username?.trim().split(' ').first;

        if (firstName != null) {
          await user?.updateDisplayName('$firstName ${event.value}');
          emit(state.copyWith(username: '$firstName ${event.value}'));
        } else {
          await user?.updateDisplayName(event.value);
          emit(state.copyWith(username: event.value));
        }
      } catch (_) {
        emit(state.copyWith(status: Status.failure));
      }
    }));

    on<SetVerificationUploadStatus>((event, emit) =>
        emit(state.copyWith(verificationUploadStatus: event.status)));

    String documentKeyForIdType(String idType) {
      switch (idType) {
        case 'drivers license':
          return 'driving_licence';
        case 'international passport':
          return 'identity_document';
        case 'work permit':
          return 'right_to_work';
        case 'vehicle registration':
          return 'vehicle_registration';
        default:
          return idType.trim().toLowerCase().replaceAll(' ', '_');
      }
    }

    Future<void> writeRiderDocumentRecord({
      required String uid,
      required String idType,
      required String idempotencyKey,
      required List<Map<String, dynamic>> files,
    }) async {
      await functions.httpsCallable('submitRiderDocument').call({
        'documentType': documentKeyForIdType(idType),
        'files': files,
        'idempotencyKey': idempotencyKey,
      }).timeout(_documentUploadOperationTimeout);
    }

    Future<Map<String, dynamic>> documentFile(String path, String side) async {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
        throw StateError('Document file must be between 1 byte and 8MB.');
      }
      final lowerPath = path.toLowerCase();
      final mimeType = lowerPath.endsWith('.png')
          ? 'image/png'
          : lowerPath.endsWith('.webp')
              ? 'image/webp'
              : lowerPath.endsWith('.pdf')
                  ? 'application/pdf'
                  : 'image/jpeg';
      return {
        'side': side,
        'base64': base64Encode(bytes),
        'mimeType': mimeType,
        'fileName': path.split(Platform.pathSeparator).last,
      };
    }

    on<SubmitVerificationDocuments>(
      (event, emit) async {
        final User? user = auth.currentUser;
        emit(state.copyWith(
          verificationUploadStatus: VerificationUploadStatus.loading,
          errorMessage: '',
        ));
        try {
          final uid = user?.uid;
          final idType = event.idType;
          final idempotencyKey = event.idempotencyKey;
          if (uid == null || idType == null || idempotencyKey == null) {
            throw StateError('Sign in to submit verification documents.');
          }
          final files =
              idType == 'drivers license' || idType == 'international passport'
                  ? [
                      await documentFile(event.frontImagePath!, 'front'),
                      await documentFile(event.backImagePath!, 'back'),
                    ]
                  : [await documentFile(event.workPermitPath!, 'primary')];
          await writeRiderDocumentRecord(
            uid: uid,
            idType: idType,
            idempotencyKey: idempotencyKey,
            files: files,
          );
          emit(state.copyWith(
            vehicleRegistrationDocumentStatus:
                idType == 'vehicle registration' ? 'under_review' : null,
            verificationUploadStatus: VerificationUploadStatus.uploaded,
            errorMessage: '',
          ));
        } on TimeoutException {
          emit(state.copyWith(
            verificationUploadStatus: VerificationUploadStatus.failure,
            errorMessage:
                'The upload took too long. Check your connection and try again.',
          ));
        } on FirebaseFunctionsException catch (error) {
          final message = switch (error.code) {
            'unauthenticated' =>
              'Your session has expired. Sign in and try again.',
            'failed-precondition' =>
              'Complete the required account details and try again.',
            'invalid-argument' =>
              'The selected document could not be accepted. Check the file and try again.',
            'permission-denied' =>
              'This document could not be submitted from your account.',
            'unavailable' ||
            'deadline-exceeded' =>
              'The connection dropped. Please try the upload again.',
            _ => 'The document could not be submitted. Please try again.',
          };
          emit(state.copyWith(
            verificationUploadStatus: VerificationUploadStatus.failure,
            errorMessage: message,
          ));
        } catch (_) {
          emit(state.copyWith(
            verificationUploadStatus: VerificationUploadStatus.failure,
            errorMessage:
                'The document could not be submitted. Please try again.',
          ));
        }
      },
    );

    on<UpdateUserProfilePhoto>(
      (event, emit) async {
        try {
          User? user = auth.currentUser;
          if (user == null) return;
          final sourceBytes = await _profilePhotoSourceBytes(event);
          if (sourceBytes == null || sourceBytes.isEmpty) {
            emit(state.copyWith(errorMessage: 'Choose a profile photo.'));
            return;
          }
          if (sourceBytes.length > 10 * 1024 * 1024) {
            emit(state.copyWith(
                errorMessage: 'Profile photo must be 10 MB or smaller.'));
            return;
          }
          final processed = _processRiderProfilePhoto(sourceBytes);
          if (processed == null) {
            emit(state.copyWith(
                errorMessage: 'Choose a JPG, PNG or HEIC profile photo.'));
            return;
          }

          final storageRef = FirebaseStorage.instance;
          final profilePath = 'rider-profiles/${user.uid}/profile.jpg';
          final thumbnailPath = 'rider-profiles/${user.uid}/thumbnail.jpg';
          final current = await db
              .collection('riderProfiles')
              .doc(user.uid)
              .get()
              .timeout(_profilePhotoOperationTimeout);
          final previousVersion =
              (current.data()?['profilePhotoVersion'] as num?)?.toInt() ?? 0;
          final version = previousVersion + 1;
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'public,max-age=300',
            customMetadata: {
              'riderId': user.uid,
              'source': 'rider_profile_photo',
              'version': '$version',
            },
          );
          final profileRef = storageRef.ref(profilePath);
          final thumbnailRef = storageRef.ref(thumbnailPath);
          await profileRef
              .putData(processed.full, metadata)
              .timeout(_profilePhotoOperationTimeout);
          await thumbnailRef
              .putData(processed.thumbnail, metadata)
              .timeout(_profilePhotoOperationTimeout);
          final downloadUrl = await profileRef
              .getDownloadURL()
              .timeout(_profilePhotoOperationTimeout);
          final thumbnailUrl = await thumbnailRef
              .getDownloadURL()
              .timeout(_profilePhotoOperationTimeout);

          await user
              .updatePhotoURL(downloadUrl)
              .timeout(_profilePhotoOperationTimeout);
          final patch = {
            'photoURL': downloadUrl,
            'photoUrl': downloadUrl,
            'profilePhoto': downloadUrl,
            'profilePhotoUrl': downloadUrl,
            'profileThumbnailUrl': thumbnailUrl,
            'profilePhotoPath': profilePath,
            'profileThumbnailPath': thumbnailPath,
            'profilePhotoVersion': version,
            'profilePhotoMetadata': {
              'contentType': 'image/jpeg',
              'fullBytes': processed.full.length,
              'thumbnailBytes': processed.thumbnail.length,
              'fullWidth': processed.fullSize,
              'thumbnailWidth': processed.thumbnailSize,
              'sourceMimeType': event.mimeType ?? '',
            },
            'photoPath': profilePath,
            'photoUpdatedAt': FieldValue.serverTimestamp(),
            'profilePhotoUpdatedAt': FieldValue.serverTimestamp(),
            'profilePhotoUploadedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          await db
              .collection('riders')
              .doc(user.uid)
              .set(patch, SetOptions(merge: true))
              .timeout(_profilePhotoOperationTimeout);
          await db
              .collection('riderProfiles')
              .doc(user.uid)
              .set(patch, SetOptions(merge: true))
              .timeout(_profilePhotoOperationTimeout);
          emit(state.copyWith(
              profilePhoto: thumbnailUrl,
              errorMessage: 'Profile photo updated.'));
        } catch (_) {
          emit(state.copyWith(
              errorMessage: 'Profile photo could not be updated.'));
        }
      },
    );

    on<RemoveUserProfilePhoto>(
      (event, emit) async {
        try {
          final user = auth.currentUser;
          if (user == null) return;
          const empty = '';
          final profilePath = 'rider-profiles/${user.uid}/profile.jpg';
          final thumbnailPath = 'rider-profiles/${user.uid}/thumbnail.jpg';
          await FirebaseStorage.instance
              .ref(profilePath)
              .delete()
              .timeout(_profilePhotoOperationTimeout)
              .catchError((_) {});
          await FirebaseStorage.instance
              .ref(thumbnailPath)
              .delete()
              .timeout(_profilePhotoOperationTimeout)
              .catchError((_) {});
          await user
              .updatePhotoURL(null)
              .timeout(_profilePhotoOperationTimeout);
          final patch = {
            'photoURL': FieldValue.delete(),
            'photoUrl': FieldValue.delete(),
            'photoPath': FieldValue.delete(),
            'profilePhotoUrl': FieldValue.delete(),
            'profileThumbnailUrl': FieldValue.delete(),
            'profilePhotoPath': FieldValue.delete(),
            'profileThumbnailPath': FieldValue.delete(),
            'profilePhotoMetadata': FieldValue.delete(),
            'profilePhoto': FieldValue.delete(),
            'profilePhotoVersion': FieldValue.increment(1),
            'photoUpdatedAt': FieldValue.serverTimestamp(),
            'profilePhotoUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          await db
              .collection('riders')
              .doc(user.uid)
              .set(patch, SetOptions(merge: true))
              .timeout(_profilePhotoOperationTimeout);
          await db
              .collection('riderProfiles')
              .doc(user.uid)
              .set(patch, SetOptions(merge: true))
              .timeout(_profilePhotoOperationTimeout);
          emit(state.copyWith(
              profilePhoto: empty, errorMessage: 'Profile photo removed.'));
        } catch (e) {
          emit(state.copyWith(
              errorMessage: 'Profile photo could not be removed.'));
        }
      },
    );

    on<SetErrorMessage>(
      (event, emit) {
        emit(state.copyWith(errorMessage: event.errorMessage));
      },
    );

    on<SignInWithEmail>(
      (event, emit) async {
        var firebaseAuthenticationSucceeded = false;
        var riderAccessVerified = false;
        try {
          emit(state.copyWith(status: Status.loading));
          final UserCredential userCredential = await auth
              .signInWithEmailAndPassword(
                  email: event.email, password: event.password)
              .timeout(_authOperationTimeout);
          firebaseAuthenticationSucceeded = true;
          const storage = FlutterSecureStorage();

          if (auth.currentUser?.emailVerified == false) {
            await auth.currentUser
                ?.sendEmailVerification()
                .timeout(_authOperationTimeout);
            emit(state.copyWith(
              status: Status.unverifiedEmail,
              clearSensitiveAuthFields: true,
            ));
          } else {
            final user = auth.currentUser;
            if (user == null) {
              emit(state.copyWith(
                status: Status.failure,
                errorMessage:
                    'Sign in could not be completed. Please try again.',
              ));
              return;
            }
            final documentReference = db.collection('riders').doc(user.uid);
            // Get the document snapshot
            var documentSnapshot =
                await documentReference.get().timeout(_authRestoreTimeout);
            if (!documentSnapshot.exists) {
              final recoveredName = user.displayName?.trim() ?? '';
              await runRiderAuthBootstrap(
                timeout: _signupBootstrapTimeout,
                updateDisplayName: () async {},
                initializeProfile: () => ensureRiderOnboardingStarted(
                  user: user,
                  name: recoveredName,
                ),
                initializeRothWallet: () => ensureRiderRothWallet(user),
              );
              documentSnapshot =
                  await documentReference.get().timeout(_authRestoreTimeout);
            }
            riderAccessVerified = documentSnapshot.exists;
            if (!riderAccessVerified) {
              throw StateError('Rider account setup is incomplete.');
            }
            String? riderPhone = userCredential.user?.phoneNumber;
            var authenticatedStatus = AuthenticatedStatus.authenticated;

            if (documentSnapshot.exists) {
              final doc = documentSnapshot.data();
              riderPhone = doc?['phone'] as String? ?? riderPhone;
              final riderAccountState = RiderAccountStateResolver.resolve(doc);
              if (!RiderAccountStateResolver.canOperate(riderAccountState)) {
                authenticatedStatus = riderAccountState ==
                            RiderAccountState.onboardingNotStarted ||
                        riderAccountState ==
                            RiderAccountState.onboardingInProgress ||
                        riderAccountState ==
                            RiderAccountState.moreInformationRequired
                    ? AuthenticatedStatus.incompleteData
                    : AuthenticatedStatus.pendingApproval;
              }
              if (riderPhone != null) {
                await storage
                    .write(key: 'phone', value: riderPhone)
                    .timeout(_authOperationTimeout);
              }
            }
            emit(state.copyWith(
                status: Status.success,
                authenticatedStatus: authenticatedStatus,
                riderAccountState: documentSnapshot.exists
                    ? RiderAccountStateResolver.resolve(documentSnapshot.data())
                    : RiderAccountState.onboardingNotStarted,
                username: user.displayName,
                profilePhoto: user.photoURL,
                email: user.email,
                verificationId: '',
                otp: '',
                phoneNumber: riderPhone,
                currentState: AppState.authenticated,
                clearSensitiveAuthFields: true));
          }
        } on FirebaseAuthException catch (e) {
          emit(state.copyWith(
            status: Status.failure,
            errorMessage: RiderAuthError.messageFor(e.code),
            clearSensitiveAuthFields: true,
          ));
        } catch (error) {
          final cause = error is RiderBootstrapException ? error.cause : error;
          if (cause is FirebaseException && cause.code == 'permission-denied') {
            try {
              await auth.signOut().timeout(_authOperationTimeout);
            } catch (_) {}
            emit(
              state.copyWith(
                status: Status.failure,
                currentState: AppState.unauthenticated,
                errorMessage:
                    'This account belongs to Sender or Admin. Sign in on the correct Circum app.',
                clearSensitiveAuthFields: true,
              ),
            );
            return;
          }
          logRiderAuthError(
            error: error,
            path: 'riders/${auth.currentUser?.uid ?? 'unknown'}',
            step: 'email_sign_in_enrichment',
            riderDocumentId: auth.currentUser?.uid,
          );
          if (firebaseAuthenticationSucceeded &&
              riderAccessVerified &&
              auth.currentUser != null) {
            emit(state.copyWith(
              status: Status.success,
              currentState: AppState.authenticated,
              authenticatedStatus: AuthenticatedStatus.incompleteData,
              errorMessage:
                  'You are signed in. Some account details are still loading.',
              clearSensitiveAuthFields: true,
            ));
          } else {
            emit(state.copyWith(
              status: Status.failure,
              errorMessage:
                  'We could not verify Rider access. Sign in again to retry.',
              clearSensitiveAuthFields: true,
            ));
          }
        }
      },
    );

    on<SignUpWithEmail>(
      (event, emit) async {
        // var acs = ActionCodeSettings(
        //     // URL you want to redirect back to. The domain (www.example.com) for this
        //     // URL must be whitelisted in the Firebase Console.
        //     url: 'https://circum-2797c.firebaseapp.com',
        //     // This must be true
        //     handleCodeInApp: true,
        //     iOSBundleId: 'com.circum.app',
        //     androidPackageName: 'com.circum.app',
        //     // installIfNotAvailable
        //     androidInstallApp: true,
        //     // minimumVersion
        //     androidMinimumVersion: '12');
        try {
          emit(state.copyWith(status: Status.loading, referralMessage: ''));
          var createdNewAccount = false;
          User? user = auth.currentUser;
          final normalizedEmail = event.email.trim().toLowerCase();
          if (user?.email?.trim().toLowerCase() != normalizedEmail) {
            final userCredential = await auth
                .createUserWithEmailAndPassword(
                    email: event.email, password: event.password)
                .timeout(_signupOperationTimeout);
            user = userCredential.user;
            createdNewAccount = true;
          }

          final fullName =
              '${state.firstName ?? ''} ${state.lastName ?? ''}'.trim();
          if (user == null) {
            throw StateError('Account creation did not complete.');
          }
          final accountUser = user;
          await runRiderAuthBootstrap(
            timeout: _signupBootstrapTimeout,
            updateDisplayName: () async {
              if (createdNewAccount && fullName.isNotEmpty) {
                await accountUser.updateDisplayName(fullName);
              }
            },
            initializeProfile: () => ensureRiderOnboardingStarted(
              user: accountUser,
              name: createdNewAccount ? fullName : accountUser.displayName,
            ),
            initializeRothWallet: () => ensureRiderRothWallet(accountUser),
          );

          final referralMessage = await applyRiderReferral(
            code: event.referralCode,
            attach: (code) async {
              final result = await functions
                  .httpsCallable('attachReferralCode')
                  .call({'referralCode': code, 'program': 'rider'});
              return '${(result.data as Map)['status']}';
            },
          );

          emit(state.copyWith(
            referralMessage: referralMessage,
            username: createdNewAccount ? fullName : accountUser.displayName,
            status: Status.initial,
            clearSensitiveAuthFields: true,
          ));
          add(SendPhoneOtp());
        } on FirebaseAuthException catch (e) {
          final message = switch (e.code) {
            'invalid-email' => 'Enter a valid email address.',
            'email-already-in-use' =>
              'An account already exists for this email. Sign in to continue setup.',
            'weak-password' => 'Use a stronger password and try again.',
            'network-request-failed' => 'Check your connection and try again.',
            'too-many-requests' =>
              'Too many attempts. Wait a moment and try again.',
            _ => "We couldn't create your account. Please try again.",
          };
          logRiderAuthError(
            error: e,
            path: 'riders/${auth.currentUser?.uid ?? 'unknown'}',
            step: 'signup_authentication',
            riderDocumentId: auth.currentUser?.uid,
          );
          emit(state.copyWith(
            status: Status.failure,
            errorMessage: message,
            clearSensitiveAuthFields: true,
          ));
        } on RiderBootstrapException catch (error) {
          logRiderAuthError(
            error: error.cause,
            path: 'riders/${auth.currentUser?.uid ?? 'unknown'}',
            step: 'signup_bootstrap_${error.stage.name}',
            riderDocumentId: auth.currentUser?.uid,
          );
          emit(state.copyWith(
            status: Status.failure,
            errorMessage:
                'Your account was created, but setup did not finish. Try again to continue.',
            clearSensitiveAuthFields: true,
          ));
        } catch (e) {
          logRiderAuthError(
            error: e,
            path: 'riders/${auth.currentUser?.uid ?? 'unknown'}',
            step: 'signup_unexpected_failure',
            riderDocumentId: auth.currentUser?.uid,
          );
          emit(state.copyWith(
            status: Status.failure,
            errorMessage: auth.currentUser == null
                ? "We couldn't create your account. Please try again."
                : 'Your account was created, but setup did not finish. Try again to continue.',
            clearSensitiveAuthFields: true,
          ));
        }
      },
    );

    on<UpdatePhoneNumber>(
      (event, emit) async {
        try {
          User? user = auth.currentUser;
          if (user == null) return;
          const storage = FlutterSecureStorage();
          final documentReference = db.collection('riders').doc(user.uid);
          // Get the document snapshot
          final documentSnapshot =
              await documentReference.get().timeout(_authRestoreTimeout);

          if (documentSnapshot.exists) {
            await db.collection("riders").doc(user.uid).update({
              'phone': event.value,
            }).timeout(_authOperationTimeout);

            await storage
                .write(key: 'phone', value: event.value)
                .timeout(_authOperationTimeout);

            emit(state.copyWith(phoneNumber: event.value));
          }
        } catch (_) {
          // Profile update failures are surfaced by the next account refresh.
        }
      },
    );

    on<ConfirmEmailVerification>((event, emit) async {
      if (state.status == Status.loading) return;
      emit(state.copyWith(status: Status.loading, isLoading: true));
      try {
        final verified = await runRiderEmailVerification(
          reload: () async {
            final user = auth.currentUser;
            if (user == null) {
              throw FirebaseAuthException(code: 'user-not-found');
            }
            await user.reload();
          },
          isVerified: () => auth.currentUser?.emailVerified == true,
          completeVerifiedBootstrap: () async {
            final user = auth.currentUser;
            if (user == null) {
              throw FirebaseAuthException(code: 'user-not-found');
            }
            await upsertRiderOnboarding(user: user, data: {
              'onboardingStatus': 'email_verified',
              'emailVerified': true,
              'emailVerifiedAt': FieldValue.serverTimestamp(),
            });
            if (user.displayName == null &&
                (state.firstName?.trim().isNotEmpty ?? false)) {
              final name =
                  '${state.firstName ?? ''} ${state.lastName ?? ''}'.trim();
              await user.updateDisplayName(name);
              await upsertRiderOnboarding(user: user, data: {'name': name});
            }
          },
          timeout: _authOperationTimeout,
        );
        if (!verified) {
          emit(state.copyWith(
              status: Status.unverifiedEmail,
              isLoading: false,
              errorMessage: 'Verify your email, then try again.'));
          return;
        }
        final user = auth.currentUser;
        if (user?.displayName == null) {
          emit(state.copyWith(
              status: Status.success,
              isLoading: false,
              authenticatedStatus: AuthenticatedStatus.incompleteData,
              currentState: AppState.authenticated));
        } else {
          emit(state.copyWith(
              status: Status.success,
              isLoading: false,
              username: user?.displayName,
              profilePhoto: user?.photoURL));
        }
      } on RiderOperationFailure catch (error) {
        emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage: error.safeMessage));
      }
    });

    on<SignOut>(
      (event, emit) async {
        const storage = FlutterSecureStorage();
        emit(state.copyWith(status: Status.loading, isLoading: true));
        final result = await runRiderSignOut(
          signOut: auth.signOut,
          clearLocalSession: storage.deleteAll,
          timeout: _authOperationTimeout,
        );
        if (!result.remoteSignedOut) {
          emit(state.copyWith(
              status: Status.failure,
              isLoading: false,
              clearSensitiveAuthFields: true,
              errorMessage:
                  'Sign out could not be completed. Check your connection and try again.'));
          return;
        }
        emit(AuthState(
          currentState: AppState.unauthenticated,
          status:
              result.localCleanupCompleted ? Status.success : Status.failure,
          errorMessage: result.localCleanupCompleted
              ? null
              : 'You are signed out. Local account data could not be fully cleared.',
        ));
      },
    );

    on<DeleteAccount>((event, emit) async {
      FlutterSecureStorage storage = const FlutterSecureStorage();

      // auth.currentUser.reauthenticateWithProvider(provider)

      try {
        await storage.delete(key: 'password').timeout(_authOperationTimeout);
        emit(state.copyWith(
          status: Status.failure,
          errorMessage:
              'For security, please sign in again before closing your account.',
        ));
      } on FirebaseException catch (e) {
        if (e.code == 'invalid-verification-code') {
          emit(state.copyWith(errorMessage: 'Invalid verification code'));
        }
      } catch (_) {
        // Reauthentication failures are handled by the account closure UI.
      }

      // Navigator.pushNamedAndRemoveUntil(
      //     context, '/onboarding', (Route<dynamic> route) => false);
    });

    on<ResetPassword>((event, emit) async {
      try {
        emit(state.copyWith(status: Status.loading));
        await auth
            .sendPasswordResetEmail(email: event.email)
            .timeout(_authOperationTimeout);
        emit(state.copyWith(status: Status.passwordResetEmailSent));
      } on FirebaseAuthException catch (err) {
        emit(state.copyWith(status: Status.failure));
        if (err.code == 'invalid-email') {
          emit(state.copyWith(errorMessage: 'Invalid email'));
        }

        if (err.code == 'user-not-found') {
          emit(state.copyWith(errorMessage: 'User not found'));
        }
      } catch (err) {
        emit(state.copyWith(status: Status.failure));
      }
    });
  }

  Future<Uint8List?> _profilePhotoSourceBytes(
      UpdateUserProfilePhoto event) async {
    if (event.imageBytes != null && event.imageBytes!.isNotEmpty) {
      return Uint8List.fromList(event.imageBytes!);
    }
    final path = event.imagePath;
    if (path == null || path.trim().isEmpty) return null;
    return File(path).readAsBytes();
  }

  _ProcessedRiderProfilePhoto? _processRiderProfilePhoto(Uint8List bytes) {
    final decoded = image_lib.decodeImage(bytes);
    if (decoded == null) return null;
    final side =
        decoded.width < decoded.height ? decoded.width : decoded.height;
    final cropX = ((decoded.width - side) / 2).round();
    final cropY = ((decoded.height - side) / 2).round();
    final square = image_lib.copyCrop(
      decoded,
      x: cropX,
      y: cropY,
      width: side,
      height: side,
    );
    final full = image_lib.copyResize(
      square,
      width: 1024,
      height: 1024,
      interpolation: image_lib.Interpolation.cubic,
    );
    final thumbnail = image_lib.copyResize(
      square,
      width: 240,
      height: 240,
      interpolation: image_lib.Interpolation.average,
    );
    return _ProcessedRiderProfilePhoto(
      full: Uint8List.fromList(image_lib.encodeJpg(full, quality: 86)),
      thumbnail:
          Uint8List.fromList(image_lib.encodeJpg(thumbnail, quality: 80)),
      fullSize: full.width,
      thumbnailSize: thumbnail.width,
    );
  }
}

class _ProcessedRiderProfilePhoto {
  const _ProcessedRiderProfilePhoto({
    required this.full,
    required this.thumbnail,
    required this.fullSize,
    required this.thumbnailSize,
  });

  final Uint8List full;
  final Uint8List thumbnail;
  final int fullSize;
  final int thumbnailSize;
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:circum_rider/extension/email_validation.dart';
import 'package:circum_rider/helper/location_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:uuid/uuid.dart';

import '../../onboarding/rider_roth_onboarding.dart';
import '../../rider_account/rider_account_state.dart';
import '../rider_auth_error.dart';
// import '../../onboarding/view/onboarding.dart';

part 'auth_event.dart';
part 'auth_state.dart';
part 'signup_event.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthState()) {
    FirebaseAuth auth = FirebaseAuth.instance;
    // Init firestore and geoFlutterFire
    // final geo = GeoFlutterFire();
    LocationHelper locationHelper = LocationHelper();

    FirebaseFirestore db = FirebaseFirestore.instance;
    const rothOnboarding = RiderRothOnboarding();

    void logRiderAuthError({
      required Object error,
      required String path,
      required String step,
      String? riderDocumentId,
    }) {}

    Future<void> upsertRiderOnboarding({
      required User user,
      required Map<String, dynamic> data,
    }) async {
      await db.collection('riders').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
        ...data,
      }, SetOptions(merge: true));
    }

    Future<String?> vehicleRegistrationDocumentStatus(String uid) async {
      final doc = await db
          .collection('riderDocuments')
          .doc('${uid}_vehicle_registration')
          .get();
      if (!doc.exists) return null;
      return '${doc.data()?['status'] ?? doc.data()?['verificationStatus'] ?? ''}'
          .trim();
    }

    void listenForPermissionStatus() async {
      await permission_handler.Permission.location.status;
    }

    listenForPermissionStatus();

    on<AuthEvent>((event, emit) async {
      if (event is SortSessionState) {
        final storage = FlutterSecureStorage();
        User? user = auth.currentUser;

        if (user != null) {
          final phone = (await storage.readAll())["phone"];
          String? riderPhone = phone;
          bool phoneVerified = false;
          String? vehicleDocStatus;
          String? riderPhoto;
          var authenticatedStatus = AuthenticatedStatus.authenticated;
          var riderAccountState = RiderAccountState.onboardingNotStarted;
          try {
            final records = await Future.wait([
              db.collection('riders').doc(user.uid).get(),
              db.collection('riderProfiles').doc(user.uid).get(),
            ]);
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
            logRiderAuthError(
              error: error,
              path: 'riders/${user.uid}',
              step: 'session_restore',
              riderDocumentId: user.uid,
            );
          }

          final SharedPreferences prefs = await SharedPreferences.getInstance();

          await prefs.setString('riderId', user.uid);
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

          await Future.delayed(const Duration(seconds: 3));

          final creationDate = DateTime.parse('${user.metadata.creationTime}');

          final authChangeDate = DateTime.parse('2024-05-15');

          if (authChangeDate.isAfter(creationDate)) {
            add(SignOut());
          }
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
            },
          );
          await completer.future;
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
            await user.linkWithCredential(credential);
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
          });
          await user.sendEmailVerification();

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
          await auth.currentUser?.sendEmailVerification();
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
          final appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
            // nonce: nonce
          );

          // SignInWithApple

          // final GoogleSignInAuthentication googleSignInAuthentication =
          //     await googleSignInAccount.authentication;

          // Create an `OAuthCredential` from the credential returned by Apple.
          final oauthCredential = OAuthProvider("apple.com").credential(
              idToken: appleCredential.identityToken,
              accessToken: appleCredential.authorizationCode
              // rawNonce: rawNonce,
              );

          // Sign in with credential
          UserCredential userCredential =
              await auth.signInWithCredential(oauthCredential);

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

          if (appleCredential.givenName != null) {
            add(UpdateUserProfile(
                username:
                    "${appleCredential.givenName} ${appleCredential.familyName}"));
          }
          await Future.delayed(const Duration(seconds: 2));

          // await googleSignIn.signOut();
        } catch (_) {
          // OAuth profile enrichment should not block sign-in.
        }
      }

      if (event is SignInWithGoogle) {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
        final GoogleSignInAccount? googleSignInAccount =
            await googleSignIn.signIn();

        if (googleSignInAccount != null) {
          final GoogleSignInAuthentication googleSignInAuthentication =
              await googleSignInAccount.authentication;

          final credential = GoogleAuthProvider.credential(
            accessToken: googleSignInAuthentication.accessToken,
            idToken: googleSignInAuthentication.idToken,
          );

          // Sign in with credential
          UserCredential userCredential =
              await auth.signInWithCredential(credential);

          emit(state.copyWith(
              username: userCredential.user?.displayName,
              email: userCredential.user?.email,
              profilePhoto: userCredential.user?.photoURL,
              status: Status.signedInWithOAuth,
              currentState: AppState.authenticated,
              authenticatedStatus: AuthenticatedStatus.authenticated));

          add(UpdateUserProfile(username: userCredential.user!.displayName!));
          // await googleSignIn.signOut();
        }
      }

      if (event is RequestForOTP) {
        // emit(state.copyWith(isLoading: true, status: Status.loading));

        var completer = Completer<bool>();

        String? _verificationId;
        int? _resendToken;

        try {
          emit(state.copyWith(status: Status.loading));
          await auth.verifyPhoneNumber(
            phoneNumber: state.phoneNumber,
            verificationCompleted: (_) {},
            verificationFailed: (_) {},
            codeSent: (String verificationId, int? resendToken) async {
              _verificationId = verificationId;
              _resendToken = resendToken;
              completer.complete(true);
            },
            codeAutoRetrievalTimeout: (_) {},
          );
          await completer.future;
          emit(state.copyWith(
              verificationId: _verificationId,
              resendToken: _resendToken,
              status: Status.success));
        } catch (e) {
          emit(state.copyWith(
              errorMessage: e.toString().split(':').last.trim(),
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
            await auth.currentUser?.linkWithCredential(credential);
          } else {
            // Sign the user in (or link) with the credential
            final UserCredential _userCredential =
                await auth.signInWithCredential(credential);

            if (_userCredential.user?.displayName == null) {
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
                    phoneNumber: _userCredential.user?.phoneNumber,
                    currentState: AppState.authenticated));
              }
            } else {
              emit(state.copyWith(
                  status: Status.success,
                  username: _userCredential.user?.displayName,
                  profilePhoto: _userCredential.user?.photoURL,
                  email: _userCredential.user?.email,
                  phoneNumber: _userCredential.user?.phoneNumber,
                  currentState: AppState.authenticated));
            }
          }
        } on FirebaseException catch (e) {
          if (e.code == 'invalid-verification-code') {
            emit(state.copyWith(errorMessage: 'Invalid verification code'));
          }
        } catch (_) {
          emit(state.copyWith(status: Status.failure));
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
          await user.updateDisplayName(event.username);
          // if (state.oAuthEmail != null) {
          //   await user!.updateEmail(state.oAuthEmail!);
          // }

          // if (state.oAuthPhotoURL != null) {
          //   await user!.updatePhotoURL(state.oAuthPhotoURL!);
          // }

          final documentReference = db.collection('riders').doc(user.uid);
          final SharedPreferences prefs = await SharedPreferences.getInstance();

          await prefs.setString('riderId', user.uid);

          // Get the document snapshot
          final documentSnapshot = await documentReference.get();

          if (documentSnapshot.exists) {
            // Document exists
            await db.collection("riders").doc(user.uid).update({
              'name': event.username,
              'role': 'rider',
              'roles': ['rider'],
              'phone': user.phoneNumber ?? state.phoneNumber,
              'phoneVerified': state.isPhoneVerified,
              if (state.isPhoneVerified)
                'phoneVerifiedAt': FieldValue.serverTimestamp(),
              'status': 'offline',
              'approvalStatus': 'pending',
              'verificationStatus': 'verification_pending',
              'profileCompletionStatus': 'complete',
              'onboardingStatus': 'profile_complete',
              'driverStatus': 'offline',
              'riderRank': 'agent',
              'rating': '0.0',
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
            });
          } else {
            // Document does not exist
            await db.collection("riders").doc(user.uid).set({
              'name': event.username,
              "role": 'rider',
              'roles': ['rider'],
              'phone': user.phoneNumber ?? state.phoneNumber,
              'phoneVerified': state.isPhoneVerified,
              if (state.isPhoneVerified)
                'phoneVerifiedAt': FieldValue.serverTimestamp(),
              'status': 'offline',
              'approvalStatus': 'pending',
              'verificationStatus': 'verification_pending',
              'profileCompletionStatus': 'complete',
              'onboardingStatus': 'profile_complete',
              'driverStatus': 'offline',
              'riderRank': 'agent',
              'rating': '0.0',
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
            });
          }

          await rothOnboarding.ensureWalletForRider(
            riderId: user.uid,
            email: user.email,
          );

          emit(state.copyWith(
              status: Status.success,
              authenticatedStatus: AuthenticatedStatus.authenticated,
              username: event.username));
        } catch (_) {
          emit(state.copyWith(status: Status.failure));
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
        try {} catch (e) {
          emit(state.copyWith(
              errorMessage: e.toString().split(':').last.trim(),
              isLoading: false));
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
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        try {
          emit(state.copyWith(status: Status.locationRequested));
          final User? user = auth.currentUser;

          Position locationData = await locationHelper.enableLocation();

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
          await prefs.setString('riderId', user!.uid);
          await prefs.setDouble('longitude', locationData.longitude);
          await prefs.setDouble('latitude', locationData.latitude);
          await prefs.setString(
              'timestamp', locationData.timestamp.toIso8601String());
          await prefs.setDouble('altitude', locationData.altitude);

          GeoFirePoint myLocation = GeoFirePoint(
              GeoPoint(locationData.latitude, locationData.longitude));
          emit(state.copyWith(
            locationData: locationData,
            hasLocationPermission: true,
            isLocationEnabled: true,
          ));
          await db.collection("riders").doc(user?.uid).update({
            'position': myLocation.data,
            'locationEnabled': true,
            'approvalStatus': 'pending',
            'verificationStatus': 'verification_pending',
            'profileCompletionStatus': 'complete',
            'onboardingStatus': 'profile_complete',
            'driverStatus': 'offline',
            'role': 'rider',
            'roles': ['rider'],
            'riderRank': 'agent',
            'submittedAt': FieldValue.serverTimestamp(),
          });
          await db.collection('riderOnboardingEvents').add({
            'riderId': user.uid,
            'eventType': 'profile_complete',
            'timestamp': FieldValue.serverTimestamp(),
            'statusAfterEvent': 'profile_complete',
          });
          await rothOnboarding.ensureWalletForRider(
            riderId: user.uid,
            email: user.email,
          );
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
            'approvalStatus': 'pending',
            'verificationStatus': 'verification_pending',
            'profileCompletionStatus': 'complete',
            'onboardingStatus': 'profile_complete',
            'driverStatus': 'offline',
            'role': 'rider',
            'roles': ['rider'],
            'riderRank': 'agent',
            'submittedAt': FieldValue.serverTimestamp(),
          });
          await db.collection('riderOnboardingEvents').add({
            'riderId': user.uid,
            'eventType': 'profile_complete',
            'timestamp': FieldValue.serverTimestamp(),
            'statusAfterEvent': 'profile_complete',
          });
          await rothOnboarding.ensureWalletForRider(
            riderId: user.uid,
            email: user.email,
          );
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

    String documentDisplayName(String idType) {
      switch (idType) {
        case 'drivers license':
          return 'Driving licence';
        case 'international passport':
          return 'Identity document';
        case 'work permit':
          return 'Right to work';
        case 'vehicle registration':
          return 'Vehicle Registration (V5C/MOT)';
        default:
          return idType;
      }
    }

    String riderStatusFieldForDocumentKey(String key) {
      switch (key) {
        case 'driving_licence':
          return 'drivingLicenceStatus';
        case 'identity_document':
          return 'identityDocumentStatus';
        case 'right_to_work':
          return 'rightToWorkStatus';
        case 'vehicle_registration':
          return 'vehicleRegistrationDocumentStatus';
        default:
          return '${key}Status';
      }
    }

    Future<void> writeRiderDocumentRecord({
      required String uid,
      required String idType,
      String? frontImageURL,
      String? backImageURL,
      String? imageURL,
    }) async {
      final key = documentKeyForIdType(idType);
      final documentRef = db.collection('riderDocuments').doc('${uid}_$key');
      final existing = await documentRef.get();
      final existingData = existing.data();
      final archivedVersion = existingData == null
          ? null
          : {
              'frontImageURL': existingData['frontImageURL'],
              'backImageURL': existingData['backImageURL'],
              'downloadUrl': existingData['downloadUrl'],
              'imageURL': existingData['imageURL'],
              'status': existingData['status'],
              'verificationStatus': existingData['verificationStatus'],
              'uploadedAt': existingData['uploadedAt'],
              'reviewedAt': existingData['reviewedAt'],
              'reviewedBy': existingData['reviewedBy'],
              'reviewer': existingData['reviewer'],
              'rejectionReason': existingData['rejectionReason'],
              'expiryDate': existingData['expiryDate'],
              'archivedAt': Timestamp.now(),
            };
      final displayName = documentDisplayName(idType);
      final statusEntry = {
        'status': 'under_review',
        'timestamp': Timestamp.now(),
        'actor': uid,
        'note': '$displayName uploaded by rider.',
      };
      await documentRef.set({
        'riderId': uid,
        'uid': uid,
        'documentType': key,
        'type': displayName,
        'displayName': displayName,
        if (frontImageURL != null) 'frontImageURL': frontImageURL,
        if (backImageURL != null) 'backImageURL': backImageURL,
        if (imageURL != null) 'downloadUrl': imageURL,
        if (imageURL != null) 'imageURL': imageURL,
        'status': 'under_review',
        'verificationStatus': 'under_review',
        'active': true,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadTimestamp': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewTimestamp': null,
        'reviewedBy': null,
        'reviewer': null,
        'rejectionReason': null,
        'expiryDate': null,
        'statusHistory': FieldValue.arrayUnion([statusEntry]),
        if (archivedVersion != null)
          'archivedVersions': FieldValue.arrayUnion([archivedVersion]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final statusField = riderStatusFieldForDocumentKey(key);
      await db.collection('riders').doc(uid).set({
        statusField: 'under_review',
        'documentChecklist.$key': 'under_review',
        'verificationStatus': 'under_review',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    on<SubmitVerificationDocuments>(
      (event, emit) async {
        final User? user = auth.currentUser;

        if (event.idType == 'drivers license' ||
            event.idType == 'international passport') {
          try {
            emit(state.copyWith(
                verificationUploadStatus: VerificationUploadStatus.loading));
            final frontImageURL =
                await uploadImage(imagePath: event.frontImagePath!);
            final backImageURL =
                await uploadImage(imagePath: event.backImagePath!);

            final verificationData = {
              'frontImageURL': frontImageURL,
              'backImageURL': backImageURL,
              'idType': event.idType,
              'updateAt': DateTime.now()
            };

            await db.collection("riders").doc(user?.uid).update({
              'verificationData': verificationData,
              'verificationStatus': 'under_review'
            });
            final uid = user?.uid;
            if (uid != null) {
              await writeRiderDocumentRecord(
                uid: uid,
                idType: event.idType!,
                frontImageURL: frontImageURL,
                backImageURL: backImageURL,
              );
            }

            emit(state.copyWith(
                verificationUploadStatus: VerificationUploadStatus.uploaded));
          } catch (e) {
            emit(state.copyWith(
                verificationUploadStatus: VerificationUploadStatus.failure));
          }
        }

        if (event.idType == 'work permit') {
          try {
            emit(state.copyWith(
                verificationUploadStatus: VerificationUploadStatus.loading));
            final imageURL =
                await uploadImage(imagePath: event.workPermitPath!);

            final verificationData = {
              'imageURL': imageURL,
              'idType': event.idType,
              'updateAt': DateTime.now()
            };

            await db.collection("riders").doc(user?.uid).update({
              'verificationData': verificationData,
              'verificationStatus': 'under_review'
            });
            final uid = user?.uid;
            if (uid != null) {
              await writeRiderDocumentRecord(
                uid: uid,
                idType: event.idType!,
                imageURL: imageURL,
              );
            }
            emit(state.copyWith(
                verificationUploadStatus: VerificationUploadStatus.uploaded));
          } catch (e) {
            emit(state.copyWith(
                verificationUploadStatus: VerificationUploadStatus.failure));
          }
        }

        if (event.idType == 'vehicle registration') {
          try {
            emit(state.copyWith(
                verificationUploadStatus: VerificationUploadStatus.loading));
            final imageURL =
                await uploadImage(imagePath: event.workPermitPath!);
            final uid = user?.uid;
            if (uid == null) {
              emit(state.copyWith(
                  verificationUploadStatus: VerificationUploadStatus.failure));
              return;
            }
            final documentRef = db
                .collection('riderDocuments')
                .doc('${uid}_vehicle_registration');
            final existing = await documentRef.get();
            final existingData = existing.data();
            final archivedVersion = existingData == null
                ? null
                : {
                    'downloadUrl': existingData['downloadUrl'],
                    'imageURL': existingData['imageURL'],
                    'status': existingData['status'],
                    'verificationStatus': existingData['verificationStatus'],
                    'uploadedAt': existingData['uploadedAt'],
                    'reviewedAt': existingData['reviewedAt'],
                    'reviewedBy': existingData['reviewedBy'],
                    'reviewer': existingData['reviewer'],
                    'rejectionReason': existingData['rejectionReason'],
                    'expiryDate': existingData['expiryDate'],
                    'archivedAt': Timestamp.now(),
                  };
            final statusEntry = {
              'status': 'under_review',
              'timestamp': Timestamp.now(),
              'actor': uid,
              'note': 'Vehicle registration document uploaded by rider.',
            };
            final data = {
              'riderId': uid,
              'uid': uid,
              'documentType': 'vehicle_registration',
              'type': 'Vehicle Registration (V5C/MOT)',
              'displayName': 'Vehicle Registration (V5C/MOT)',
              'downloadUrl': imageURL,
              'imageURL': imageURL,
              'status': 'under_review',
              'verificationStatus': 'under_review',
              'active': true,
              'uploadedAt': FieldValue.serverTimestamp(),
              'uploadTimestamp': FieldValue.serverTimestamp(),
              'reviewedAt': null,
              'reviewTimestamp': null,
              'reviewedBy': null,
              'reviewer': null,
              'rejectionReason': null,
              'expiryDate': null,
              'statusHistory': FieldValue.arrayUnion([statusEntry]),
              if (archivedVersion != null)
                'archivedVersions': FieldValue.arrayUnion([archivedVersion]),
              'updatedAt': FieldValue.serverTimestamp(),
            };
            await documentRef.set(data, SetOptions(merge: true));
            await db.collection('riders').doc(uid).set({
              'vehicleRegistrationDocument': {
                'documentId': documentRef.id,
                'downloadUrl': imageURL,
                'status': 'under_review',
                'uploadedAt': FieldValue.serverTimestamp(),
              },
              'vehicleRegistrationDocumentStatus': 'under_review',
              'documentChecklist.vehicle_registration': 'under_review',
              'verificationStatus': 'under_review',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            emit(state.copyWith(
                vehicleRegistrationDocumentStatus: 'under_review',
                verificationUploadStatus: VerificationUploadStatus.uploaded));
          } catch (e) {
            emit(state.copyWith(
                verificationUploadStatus: VerificationUploadStatus.failure));
          }
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
          if (sourceBytes.length > 20 * 1024 * 1024) {
            emit(state.copyWith(
                errorMessage: 'Profile photo must be smaller than 20MB.'));
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
          final current =
              await db.collection('riderProfiles').doc(user.uid).get();
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
          await profileRef.putData(processed.full, metadata);
          await thumbnailRef.putData(processed.thumbnail, metadata);
          final downloadUrl = await profileRef.getDownloadURL();
          final thumbnailUrl = await thumbnailRef.getDownloadURL();

          await user.updatePhotoURL(downloadUrl);
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
              .set(patch, SetOptions(merge: true));
          await db
              .collection('riderProfiles')
              .doc(user.uid)
              .set(patch, SetOptions(merge: true));
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
              .catchError((_) {});
          await FirebaseStorage.instance
              .ref(thumbnailPath)
              .delete()
              .catchError((_) {});
          await user.updatePhotoURL(null);
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
              .set(patch, SetOptions(merge: true));
          await db
              .collection('riderProfiles')
              .doc(user.uid)
              .set(patch, SetOptions(merge: true));
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
        try {
          emit(state.copyWith(status: Status.loading));
          final UserCredential userCredential =
              await auth.signInWithEmailAndPassword(
                  email: event.email, password: event.password);
          const storage = FlutterSecureStorage();

          if (auth.currentUser?.emailVerified == false) {
            await auth.currentUser?.sendEmailVerification();
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
            final documentSnapshot = await documentReference.get();
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
                await storage.write(key: 'phone', value: riderPhone);
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
        } catch (_) {
          emit(state.copyWith(
            status: Status.failure,
            errorMessage: RiderAuthError.messageFor('unknown'),
            clearSensitiveAuthFields: true,
          ));
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
          emit(state.copyWith(status: Status.loading));
          final UserCredential userCredential =
              await auth.createUserWithEmailAndPassword(
                  email: event.email, password: event.password);

          final user = userCredential.user;
          final fullName =
              '${state.firstName ?? ''} ${state.lastName ?? ''}'.trim();
          if (user != null && fullName.isNotEmpty) {
            await user.updateDisplayName(fullName);
            final vehicleRegistration = state.vehicleRegistration?.trim();
            await upsertRiderOnboarding(user: user, data: {
              'name': fullName,
              'role': 'rider',
              'roles': ['rider'],
              'riderRank': 'agent',
              'phone': state.phoneNumber,
              'phoneVerified': false,
              'approvalStatus': 'pending',
              'verificationStatus': 'verification_pending',
              'profileCompletionStatus': 'started',
              'onboardingStatus': 'profile_started',
              'driverStatus': 'pending',
              'status': 'offline',
              'rating': '0.0',
              'vehicle': {
                'type': state.vehicleType?.trim(),
                'makeModel': state.vehicleMakeModel?.trim(),
                'colour': state.vehicleColour?.trim(),
                'plateNumber': vehicleRegistration,
              },
              'vehicleType': state.vehicleType?.trim(),
              'vehicleMakeModel': state.vehicleMakeModel?.trim(),
              'vehicleColour': state.vehicleColour?.trim(),
              'vehicleRegistration': vehicleRegistration,
              'plateNumber': vehicleRegistration,
              'typeOfVehicle': state.vehicleType?.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            });
            await db.collection('riderOnboardingEvents').add({
              'riderId': user.uid,
              'eventType': 'account_created',
              'timestamp': FieldValue.serverTimestamp(),
              'statusAfterEvent': 'account_created',
            });
            await rothOnboarding.ensureWalletForRider(
              riderId: user.uid,
              email: user.email,
            );
          }

          emit(state.copyWith(
            username: fullName.isEmpty ? state.username : fullName,
            status: Status.initial,
            clearSensitiveAuthFields: true,
          ));
          add(SendPhoneOtp());
        } on FirebaseAuthException catch (e) {
          emit(state.copyWith(
            status: Status.failure,
            clearSensitiveAuthFields: true,
          ));
          if (e.code == 'invalid-email') {
            emit(state.copyWith(errorMessage: 'Email is invalid'));
          }
          if (e.code == 'email-already-in-use') {
            emit(state.copyWith(errorMessage: 'User already exists'));
          }
          if (e.code == 'user-not-found') {
            emit(state.copyWith(errorMessage: 'User not found'));
          }
          if (e.code == 'weak-password') {
            emit(state.copyWith(errorMessage: 'Use a strong password'));
          }
        } catch (e) {
          emit(state.copyWith(
              status: Status.failure,
              errorMessage: 'Something went wrong',
              clearSensitiveAuthFields: true));
        }
      },
    );

    on<UpdatePhoneNumber>(
      (event, emit) async {
        try {
          User? user = auth.currentUser;
          FlutterSecureStorage storage = const FlutterSecureStorage();
          final documentReference = db.collection('riders').doc(user?.uid);
          // Get the document snapshot
          final documentSnapshot = await documentReference.get();

          if (documentSnapshot.exists) {
            await db.collection("riders").doc(user!.uid).update({
              'phone': event.value,
            });

            await storage.write(key: 'phone', value: event.value);

            emit(state.copyWith(phoneNumber: event.value));
          }
        } catch (_) {
          // Profile update failures are surfaced by the next account refresh.
        }
      },
    );

    on<ConfirmEmailVerification>((event, emit) async {
      await auth.currentUser?.reload();
      if (auth.currentUser?.emailVerified == true) {
        final user = auth.currentUser;
        if (user != null) {
          await upsertRiderOnboarding(user: user, data: {
            'onboardingStatus': 'email_verified',
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
          });
        }
        if (user != null &&
            user.displayName == null &&
            (state.firstName?.trim().isNotEmpty ?? false)) {
          final name =
              '${state.firstName ?? ''} ${state.lastName ?? ''}'.trim();
          await user.updateDisplayName(name);
          await upsertRiderOnboarding(user: user, data: {'name': name});
          emit(state.copyWith(
            status: Status.success,
            username: name,
          ));
        } else if (user?.displayName == null) {
          emit(state.copyWith(
              authenticatedStatus: AuthenticatedStatus.incompleteData,
              currentState: AppState.authenticated));
        } else {
          emit(state.copyWith(
            status: Status.success,
            username: auth.currentUser?.displayName,
            profilePhoto: auth.currentUser?.photoURL,
          ));
        }
      } else {}
    });

    on<SignOut>(
      (event, emit) async {
        FlutterSecureStorage storage = const FlutterSecureStorage();
        await auth.signOut();
        emit(const AuthState());
        emit(state.copyWith(currentState: AppState.unauthenticated));
        await storage.deleteAll();
      },
    );

    on<DeleteAccount>((event, emit) async {
      FlutterSecureStorage storage = const FlutterSecureStorage();

      // auth.currentUser.reauthenticateWithProvider(provider)

      try {
        await storage.delete(key: 'password');
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
        await auth.sendPasswordResetEmail(email: event.email);
        emit(state.copyWith(status: Status.passwordResetEmailSent));
      } on FirebaseAuthException catch (err) {
        emit(state.copyWith(status: Status.failure));
        if (err.code == 'invalid-email') {
          emit(state.copyWith(errorMessage: 'Invalid email'));
        }

        if (err.code == 'user-not-found') {
          emit(state.copyWith(errorMessage: 'User not found'));
        }

        throw Exception(err.message.toString());
      } catch (err) {
        emit(state.copyWith(status: Status.failure));
        throw Exception(err.toString());
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

  Future<String> uploadImage({required String imagePath}) async {
    try {
      final fileName = Uuid();
      File imageFile = File(imagePath);

      final storageRef = FirebaseStorage.instance;
      await storageRef.ref('verification-photos/$fileName').putFile(imageFile);
      final downloadUrl = await storageRef
          .ref('verification-photos/$fileName')
          .getDownloadURL();

      return downloadUrl;
    } catch (_) {
      throw 'Something went wrong uploading image';
    }
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

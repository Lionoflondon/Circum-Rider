import '../../verification/rider_document_transport.dart';
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
  static const _documentUploadOperationTimeout = Duration(minutes: 2);

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

    Future<void> verifyRiderSurface(User? user) async {
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');
      try {
        final access = await functions
            .httpsCallable('verifyRiderAccountAccess')
            .call({}).timeout(_authOperationTimeout);
        if (access.data is Map && access.data['profileExists'] == false) {
          await functions
              .httpsCallable('updateRiderProfile')
              .call({}).timeout(_authOperationTimeout);
        }
      } on FirebaseFunctionsException catch (error) {
        if (error.code == 'permission-denied') {
          try {
            await auth.signOut().timeout(_authOperationTimeout);
          } catch (_) {}
          throw FirebaseAuthException(code: 'wrong-surface');
        }
        rethrow;
      }
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
          try {
            await verifyRiderSurface(user);
          } catch (error) {
            emit(state.copyWith(
                currentState: AppState.unauthenticated,
                status: Status.failure,
                isLoading: false,
                errorMessage: error is FirebaseAuthException
                    ? RiderAuthError.messageFor(error.code)
                    : 'Account access could not be checked. Check your connection and sign in again.'));
            return;
          }
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
          await verifyRiderSurface(userCredential.user);

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
            errorMessage: error is FirebaseAuthException
                ? RiderAuthError.messageFor(error.code)
                : 'Apple sign-in could not be completed. Try again.',
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
          await verifyRiderSurface(userCredential.user);

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
            errorMessage: error is FirebaseAuthException
                ? RiderAuthError.messageFor(error.code)
                : 'Google sign-in could not be completed. Try again.',
            clearSensitiveAuthFields: true,
          ));
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

      if (event is LoginUser) {
        emit(state.copyWith(isLoading: true, status: Status.loading));
        emit(state.copyWith(
          status: Status.failure,
          isLoading: false,
          errorMessage: 'Please use the secure email sign-in flow.',
        ));
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
              'user-not-found' =>
                'Password reset could not be completed. Please try again.',
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
        final user = auth.currentUser;
        if (user == null) {
          throw const RiderOperationFailure(
              'Sign in again to update your name.');
        }
        final lastName = state.username?.trim().split(' ').last;

        if (lastName != null) {
          await user
              .updateDisplayName('${event.value} $lastName')
              .timeout(_authOperationTimeout);
          emit(state.copyWith(username: '${event.value} $lastName'));
        } else {
          await user
              .updateDisplayName(event.value)
              .timeout(_authOperationTimeout);
          emit(state.copyWith(username: event.value));
        }
      } on TimeoutException {
        emit(state.copyWith(
          status: Status.failure,
          isLoading: false,
          errorMessage:
              'Name update took too long. Check your profile before retrying.',
        ));
      } on RiderOperationFailure catch (error) {
        emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage: error.safeMessage));
      } catch (_) {
        emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage: 'Your name could not be updated. Please try again.'));
      }
    }));

    on<UpdateLastName>(((event, emit) async {
      try {
        final user = auth.currentUser;
        if (user == null) {
          throw const RiderOperationFailure(
              'Sign in again to update your name.');
        }
        final firstName = state.username?.trim().split(' ').first;

        if (firstName != null) {
          await user
              .updateDisplayName('$firstName ${event.value}')
              .timeout(_authOperationTimeout);
          emit(state.copyWith(username: '$firstName ${event.value}'));
        } else {
          await user
              .updateDisplayName(event.value)
              .timeout(_authOperationTimeout);
          emit(state.copyWith(username: event.value));
        }
      } on TimeoutException {
        emit(state.copyWith(
          status: Status.failure,
          isLoading: false,
          errorMessage:
              'Name update took too long. Check your profile before retrying.',
        ));
      } on RiderOperationFailure catch (error) {
        emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage: error.safeMessage));
      } catch (_) {
        emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage: 'Your name could not be updated. Please try again.'));
      }
    }));

    on<SetVerificationUploadStatus>((event, emit) =>
        emit(state.copyWith(verificationUploadStatus: event.status)));

    String documentKeyForIdType(String idType) {
      switch (idType) {
        case 'drivers license':
          return 'driving_licence';
        case 'international passport':
          return 'identity';
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
      await submitRiderDocumentTransport(
          timeout: _documentUploadOperationTimeout,
          request: {
            'documentType': documentKeyForIdType(idType),
            'files': files,
            'idempotencyKey': idempotencyKey,
          },
          call: (payload) async {
            await functions.httpsCallable('submitRiderDocument').call(payload);
          });
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
        try {
          emit(state.copyWith(status: Status.loading));
          final UserCredential userCredential = await auth
              .signInWithEmailAndPassword(
                  email: event.email, password: event.password)
              .timeout(_authOperationTimeout);
          await verifyRiderSurface(userCredential.user);
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
          logRiderAuthError(
            error: error,
            path: 'riders/${auth.currentUser?.uid ?? 'unknown'}',
            step: 'email_sign_in_enrichment',
            riderDocumentId: auth.currentUser?.uid,
          );
          if (firebaseAuthenticationSucceeded && auth.currentUser != null) {
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
              errorMessage: RiderAuthError.messageFor('unknown'),
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
          emit(state.copyWith(status: Status.loading));
          User? user = auth.currentUser;
          final normalizedEmail = event.email.trim().toLowerCase();
          if (user?.email?.trim().toLowerCase() != normalizedEmail) {
            final userCredential = await auth
                .createUserWithEmailAndPassword(
                    email: event.email, password: event.password)
                .timeout(_signupOperationTimeout);
            user = userCredential.user;
          }

          final fullName =
              '${state.firstName ?? ''} ${state.lastName ?? ''}'.trim();
          if (user != null && fullName.isNotEmpty) {
            await runRiderAuthBootstrap(
              timeout: _signupBootstrapTimeout,
              updateDisplayName: () => user!.updateDisplayName(fullName),
              initializeProfile: () => ensureRiderOnboardingStarted(
                user: user!,
                name: fullName,
              ),
              initializeRothWallet: () => ensureRiderRothWallet(user!),
            );
          }

          if (user != null && !user.emailVerified) {
            await user.sendEmailVerification().timeout(_authOperationTimeout);
            emit(state.copyWith(
              username: fullName.isEmpty ? state.username : fullName,
              email: user.email,
              status: Status.unverifiedEmail,
              currentState: AppState.unauthenticated,
              authenticatedStatus: AuthenticatedStatus.incompleteData,
              clearSensitiveAuthFields: true,
            ));
            return;
          }

          emit(state.copyWith(
            username: fullName.isEmpty ? state.username : fullName,
            status: Status.success,
            currentState: AppState.authenticated,
            authenticatedStatus: AuthenticatedStatus.incompleteData,
            clearSensitiveAuthFields: true,
          ));
        } on FirebaseAuthException catch (e) {
          final message = switch (e.code) {
            'invalid-email' => 'Enter a valid email address.',
            'email-already-in-use' =>
              'Account creation could not be completed. If you already have an account, sign in or reset your password.',
            'weak-password' => 'Use a password with at least 10 characters.',
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
      emit(state.copyWith(
          status: Status.loading, isLoading: true, errorMessage: ''));
      try {
        await auth
            .sendPasswordResetEmail(email: event.email.trim())
            .timeout(_authOperationTimeout);
        emit(state.copyWith(
            status: Status.passwordResetEmailSent, isLoading: false));
      } on FirebaseAuthException catch (error) {
        emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage: RiderAuthError.messageFor(error.code)));
      } on TimeoutException {
        emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage:
                'Password reset took too long. Check your email before trying again.'));
      } catch (_) {
        emit(state.copyWith(
            status: Status.failure,
            isLoading: false,
            errorMessage:
                'We could not send the reset email. Please try again.'));
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helper/bitmap_descriptor_helper.dart';
import '../../../helper/formatted_string_after_seconds.dart';
import '../../../helper/messaging_server.dart';
import '../../../utils/theme/theme.dart';
import '../../communication/rider_communication_service.dart';
import '../../rider_account/rider_account_state.dart';
import '../../rider_jobs/rider_active_delivery_resolver.dart';
import '../models/dispatch_request.m..dart';
import '../models/message.m.dart';
import '../models/place_coordinates.m.dart';
import '../repo/direction_service.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> with WidgetsBindingObserver {
  static const _directionsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_DIRECTIONS_API_KEY');
  static const _presenceHeartbeatInterval = Duration(seconds: 45);
  static const _founderUid = 'T2eV6PQucdUKmwSipEn2NAn4N9z1';

  FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  final DirectionsService _directionsService = DirectionsService();
  final RiderCommunicationService _communicationService =
      RiderCommunicationService();

  List<DirectionStep> _currentRoute = [];
  Timer? _presenceHeartbeatTimer;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _presenceSubscription;
  String? _presenceRiderId;

  List<String> _remainingVerificationItems(Map<String, dynamic>? riderData) {
    final remaining = <String>[];
    final docs = riderData?['documentChecklist'];
    bool approved(String key) {
      if (docs is Map && '${docs[key] ?? ''}' == 'approved') return true;
      return '${riderData?['${key}Status'] ?? ''}' == 'approved' ||
          riderData?['${key}Approved'] == true;
    }

    if (riderData?['phoneVerified'] != true) {
      remaining.add('Phone verification');
    }
    if (!approved('identityDocument')) remaining.add('Identity document');
    if (!approved('rightToWork')) remaining.add('Right to work');
    if (!approved('drivingLicence')) remaining.add('Driving licence');
    if (!approved('insurance')) remaining.add('Insurance');
    final vehicle = riderData?['vehicle'];
    final vehicleType =
        '${riderData?['vehicleType'] ?? (vehicle is Map ? vehicle['type'] : '')}'
            .toLowerCase();
    if (vehicleType.contains('car') || vehicleType.contains('van')) {
      if ('${riderData?['vehicleRegistrationDocumentStatus'] ?? ''}' !=
              'approved' &&
          !approved('vehicleRegistration')) {
        remaining.add('Vehicle Registration (V5C/MOT)');
      }
    }
    if ('${riderData?['approvalStatus'] ?? ''}' != 'approved') {
      remaining.add('Admin approval');
    }
    return remaining;
  }

  Future<List<String>> _loadRemainingVerificationItems(String? uid) async {
    if (uid == null || uid.isEmpty) return ['Circum Rider profile'];
    final riderDoc = await db.collection('riders').doc(uid).get();
    return _remainingVerificationItems(riderDoc.data());
  }

  Future<RiderAccountState> _loadAccountState(String? uid) async {
    if (uid == null || uid.isEmpty) {
      return RiderAccountState.onboardingNotStarted;
    }
    final records = await Future.wait([
      db.collection('riders').doc(uid).get(),
      db.collection('riderProfiles').doc(uid).get(),
    ]);
    return RiderAccountStateResolver.resolve({
      ...(records[1].data() ?? const <String, dynamic>{}),
      ...(records[0].data() ?? const <String, dynamic>{}),
    });
  }

  HomeBloc() : super(HomeState()) {
    WidgetsBinding.instance.addObserver(this);
    on<CheckForPushToken>(_handleCheckForPushToken);
    on<SetRideStatus>(_handleSetRideStatus);
    on<SyncPresenceSnapshot>(_handleSyncPresenceSnapshot);
    on<GetAvailableRequests>(_handleGetAvailableRequests);
    on<SetHomeLocationData>(_handleSetHomeLocationData);
    on<AcceptRide>(_handleAcceptRide);
    on<DeclineRequest>(_handleDeclineRequest);
    on<SetSourceAndDestinationStatus>(_handleSetSourceAndDestinationStatus);
    on<SetMapCameraStatus>(_handleSetMapCameraStatus);
    on<SetDrawerHeight>(_handleSetDrawerHeight);
    on<SetPanelControlStatus>(_handleSetPanelControlStatus);
    on<GetPolylines>(_handleGetPolylines);
    on<CancelRequest>(_handlerCancelRequest);
    on<BroadcastLocation>(_handleBroadcastLocation);
    on<CheckForActiveRequest>(_handleCheckForActiveRequest);
    on<IncomingMessage>(_handleIncomingMessage);
    on<SetNewMessage>(_handleSetNewMessage);
    on<LoadChatMessages>(_handleLoadChatMessages);
    on<MessageUser>(_handleMessageUser);
    _authStateSubscription = auth.authStateChanges().listen(
      _bindPresenceUser,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[RIDER_AVAILABILITY] auth stream failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        this.state.availability.intendsToBeOnline) {
      _startPresenceHeartbeat();
    }
  }

  void _bindPresenceUser(User? user) {
    final riderId = user?.uid;
    if (_presenceRiderId == riderId) return;
    _presenceRiderId = riderId;
    final previousSubscription = _presenceSubscription;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }
    _presenceSubscription = null;
    if (riderId == null) {
      _stopPresenceHeartbeat();
      add(SyncPresenceSnapshot(const <String, dynamic>{}));
      return;
    }
    _presenceSubscription =
        db.collection('riderPresence').doc(riderId).snapshots().listen(
      (snapshot) => add(
        SyncPresenceSnapshot(
          snapshot.data() ?? const <String, dynamic>{},
          riderId: riderId,
        ),
      ),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '[RIDER_AVAILABILITY] riderId=$riderId presence stream failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  void _handleCheckForPushToken(
    CheckForPushToken event,
    Emitter<HomeState> emit,
  ) async {
    final User? user = auth.currentUser;
    final internalAccess = user == null
        ? false
        : (await user.getIdTokenResult()).claims?['founderRider'] == true;
    await _refreshRiderHomeAccess(user, internalAccess, emit);

    String? fcmToken;
    try {
      if (!kIsWeb && Platform.isIOS) {
        await firebaseMessaging.requestPermission();
      }
      if (!kIsWeb && Platform.isIOS) {
        await firebaseMessaging.getAPNSToken();
      }
      fcmToken = await firebaseMessaging.getToken();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-blocked') {
        debugPrint('Rider push token unavailable: ${error.code}');
      }
      return;
    } catch (_) {
      return;
    }

    if (fcmToken == null || user == null) return;
    try {
      await FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('updateRiderPushToken').call({'fcmToken': fcmToken});
    } catch (_) {
      // Push token updates should not block the Rider home state.
    }
  }

  Future<void> _refreshRiderHomeAccess(
    User? user,
    bool internalAccess,
    Emitter<HomeState> emit,
  ) async {
    if (user == null) return;
    try {
      final documentSnapshot =
          await db.collection('riders').doc(user.uid).get();
      if (!documentSnapshot.exists) return;
      final remaining = _remainingVerificationItems(documentSnapshot.data());
      emit(
        state.copyWith(
          canGoOnline: internalAccess || remaining.isEmpty,
          verificationChecklist: remaining,
        ),
      );
    } catch (_) {
      // Verification state refresh should not block the Rider dashboard.
    }
  }

  void _handleSetRideStatus(SetRideStatus event, Emitter emit) async {
    final User? user = auth.currentUser;
    if (user == null) {
      emit(
        state.copyWith(message: 'Sign in before changing Rider availability.'),
      );
      return;
    }
    final internalAccess = await _readFounderClaim(user);
    if (event.status == RideStatus.offline) {
      final previousAvailability = state.availability;
      try {
        _stopPresenceHeartbeat();
        emit(
          state.copyWith(
            availability: previousAvailability.copyWith(
              status: RiderAvailabilityStatus.goingOffline,
              dispatchEligible: false,
            ),
            requestStatus: RequestStatus.loading,
            message: null,
          ),
        );
        await FirebaseFunctions.instanceFor(
          region: 'us-central1',
        ).httpsCallable('goOffline').call();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('status', 'offline');
        emit(
          state.copyWith(
            rideStatus: RideStatus.offline,
            availability: const RiderAvailability(),
            message: null,
            requestStatus: RequestStatus.initial,
          ),
        );
      } on FirebaseFunctionsException catch (error) {
        emit(
          state.copyWith(
            availability: previousAvailability,
            requestStatus: RequestStatus.initial,
            message: error.message ?? 'Could not go offline.',
          ),
        );
      }
      return;
    } else {
      if (user.uid == _founderUid) {
        try {
          await FirebaseFunctions.instanceFor(
            region: 'us-central1',
          ).httpsCallable('founderRiderOperationalPreflight').call();
        } on FirebaseFunctionsException catch (error, stackTrace) {
          debugPrint(
            '[RIDER_OPERATIONAL_PREFLIGHT] code=${error.code} message=${error.message} details=${error.details}',
          );
          debugPrintStack(stackTrace: stackTrace);
          emit(
            state.copyWith(
              rideStatus: RideStatus.offline,
              canGoOnline: false,
              requestStatus: RequestStatus.initial,
              message:
                  'FOUNDER_PREFLIGHT_FAILED: ${_availabilityErrorMessage(error, fallback: 'Operational preflight failed. Retry.')}',
            ),
          );
          return;
        } catch (error, stackTrace) {
          debugPrint(
            '[RIDER_OPERATIONAL_PREFLIGHT] type=${error.runtimeType} error=$error',
          );
          debugPrintStack(stackTrace: stackTrace);
          emit(
            state.copyWith(
              rideStatus: RideStatus.offline,
              canGoOnline: false,
              requestStatus: RequestStatus.initial,
              message: 'FOUNDER_PREFLIGHT_FAILED: ${error.runtimeType}',
            ),
          );
          return;
        }
      }
      final accountState = await _loadAccountState(user.uid);
      if (!internalAccess &&
          !RiderAccountStateResolver.canOperate(accountState)) {
        emit(
          state.copyWith(
            rideStatus: RideStatus.offline,
            canGoOnline: false,
            message:
                'Your Circum Rider account is not approved for operational access.',
          ),
        );
        return;
      }
      final remaining = await _loadRemainingVerificationItems(user.uid);
      if (!internalAccess &&
          event.status == RideStatus.online &&
          remaining.isNotEmpty) {
        emit(
          state.copyWith(
            rideStatus: RideStatus.offline,
            canGoOnline: false,
            verificationChecklist: remaining,
            message: 'Complete your verification to start earning.',
          ),
        );
        return;
      }
      if (event.status == RideStatus.online) {
        final previousRideStatus = state.rideStatus;
        final previousAvailability = state.availability;
        final fallbackRideStatus = previousRideStatus == RideStatus.online
            ? RideStatus.online
            : RideStatus.offline;
        try {
          emit(
            state.copyWith(
              availability: previousAvailability.copyWith(
                status: RiderAvailabilityStatus.waitingForLocation,
                dispatchEligible: false,
              ),
              requestStatus: RequestStatus.loading,
              message: null,
            ),
          );
          final locationPayload =
              await _onlinePresenceLocationPayload().timeout(
            const Duration(seconds: 12),
            onTimeout: () async {
              final fallback = await _freshWebPresenceLocationPayload();
              if (fallback != null) return fallback;
              throw const _RiderLocationUnavailable(
                'Location is taking too long. Check browser location permission and try again.',
              );
            },
          );
          if (locationPayload == null) {
            throw const _RiderLocationUnavailable(
              'Turn on location and allow Circum Rider to use your location before going online.',
            );
          }
          final response =
              await FirebaseFunctions.instanceFor(region: 'us-central1')
                  .httpsCallable('goOnline')
                  .call(<String, dynamic>{'location': locationPayload}).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw const _RiderAvailabilityTimeout();
            },
          );
          _startPresenceHeartbeat();
          final responseData = response.data is Map
              ? Map<String, dynamic>.from(response.data as Map)
              : const <String, dynamic>{};
          final responsePresence = responseData['presence'] is Map
              ? Map<String, dynamic>.from(responseData['presence'] as Map)
              : const <String, dynamic>{};
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('status', 'online');
          emit(
            state.copyWith(
              rideStatus: RideStatus.online,
              availability: RiderAvailability.fromPresence(responsePresence),
              canGoOnline: true,
              message: null,
              requestStatus: RequestStatus.success,
            ),
          );
          add(GetAvailableRequests());
          add(
            SetDrawerHeight(
              minDrawerHeight: state.minDrawerHeight,
              maxDrawerHeight: 0.75.sh,
            ),
          );
          add(SetPanelControlStatus(status: PanelControlStatus.isOpened));
        } on FirebaseFunctionsException catch (error, stackTrace) {
          if (fallbackRideStatus == RideStatus.offline) {
            _stopPresenceHeartbeat();
          }
          debugPrint(
            '[RIDER_GO_ONLINE_FAILURE] code=${error.code} message=${error.message} details=${error.details}',
          );
          debugPrintStack(stackTrace: stackTrace);
          emit(
            state.copyWith(
              rideStatus: fallbackRideStatus,
              availability: previousAvailability,
              requestStatus: RequestStatus.initial,
              message: _availabilityErrorMessage(
                error,
                fallback:
                    'FUNCTION_${error.code.toUpperCase().replaceAll('-', '_')}',
              ),
            ),
          );
        } on _RiderAvailabilityTimeout {
          if (fallbackRideStatus == RideStatus.offline) {
            _stopPresenceHeartbeat();
          }
          emit(
            state.copyWith(
              rideStatus: fallbackRideStatus,
              availability: previousAvailability,
              requestStatus: RequestStatus.initial,
              message:
                  'Circum Rider could not switch online in time. Check your connection and try again.',
            ),
          );
        } on _RiderLocationUnavailable catch (error) {
          if (fallbackRideStatus == RideStatus.offline) {
            _stopPresenceHeartbeat();
          }
          emit(
            state.copyWith(
              rideStatus: fallbackRideStatus,
              availability: previousAvailability,
              requestStatus: RequestStatus.initial,
              message: error.message,
            ),
          );
        } catch (error, stackTrace) {
          if (fallbackRideStatus == RideStatus.offline) {
            _stopPresenceHeartbeat();
          }
          debugPrint(
            '[RIDER_GO_ONLINE_FAILURE] type=${error.runtimeType} error=$error',
          );
          debugPrintStack(stackTrace: stackTrace);
          emit(
            state.copyWith(
              rideStatus: fallbackRideStatus,
              availability: previousAvailability,
              requestStatus: RequestStatus.initial,
              message: 'UNKNOWN_INTERNAL_ERROR: ${error.runtimeType}',
            ),
          );
        }
        return;
      }
    }
  }

  Future<bool> _readFounderClaim(User user) async {
    try {
      return (await user.getIdTokenResult()).claims?['founderRider'] == true;
    } catch (error, stackTrace) {
      debugPrint('[RIDER_AUTH] getIdTokenResult failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  void _handleSyncPresenceSnapshot(
    SyncPresenceSnapshot event,
    Emitter<HomeState> emit,
  ) {
    if (event.riderId != null && event.riderId != auth.currentUser?.uid) return;
    final availability = RiderAvailability.fromPresence(event.presence);
    final current = state.availability;
    if (current.status == availability.status &&
        current.lastFix == availability.lastFix &&
        current.lastHeartbeat == availability.lastHeartbeat &&
        current.dispatchEligible == availability.dispatchEligible) {
      return;
    }
    if (availability.intendsToBeOnline && _presenceHeartbeatTimer == null) {
      _startPresenceHeartbeat();
    } else if (!availability.intendsToBeOnline) {
      _stopPresenceHeartbeat();
    }
    emit(state.copyWith(availability: availability));
  }

  String _availabilityErrorMessage(
    FirebaseFunctionsException error, {
    required String fallback,
  }) {
    final message = (error.message ?? '').trim();
    if (message.isEmpty || message.toLowerCase() == 'internal') {
      return fallback;
    }
    return message;
  }

  void _handleGetAvailableRequests(event, emit) async {
    try {
      emit(
        state.copyWith(
          dispatchRequests: [],
          requestStatus: RequestStatus.loading,
        ),
      );
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final HttpsCallable callable = functions.httpsCallable(
        'getAvailableRequests',
      );
      final response = await callable.call();
      final dispatchRequests = (response.data['nearestRequests'] as List)
          .map((doc) => DispatchRequest.fromJson(doc))
          .toList();
      emit(
        state.copyWith(
          dispatchRequests: dispatchRequests,
          requestStatus: RequestStatus.success,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          requestStatus: RequestStatus.failure,
          message:
              'Available deliveries could not refresh. Check your connection and try again.',
        ),
      );
    }
  }

  void _handleSetHomeLocationData(SetHomeLocationData event, Emitter emit) {
    emit(state.copyWith(locationData: event.locationData));
  }

  void _handleAcceptRide(AcceptRide event, Emitter emit) async {
    try {
      final User? user = auth.currentUser;
      if (user == null) {
        emit(state.copyWith(requestStatus: RequestStatus.failure));
        return;
      }
      // Obtain shared preferences.
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final documentReference = db.collection('riders').doc(user.uid);
      // Get the document snapshot
      final documentSnapshot = await documentReference.get();

      final riderData = documentSnapshot.data();

      final requests = state.dispatchRequests;
      if (event.selectedRequestIndex < 0 ||
          event.selectedRequestIndex >= requests.length) {
        emit(state.copyWith(requestStatus: RequestStatus.failure));
        return;
      }

      emit(
        state.copyWith(
          rideStatus: RideStatus.acceptedARide,
          selectedRequestIndex: event.selectedRequestIndex,
          activeRequest: requests[event.selectedRequestIndex],
        ),
      );

      final double? riderLng = prefs.getDouble('longitude');
      final double? riderLat = prefs.getDouble('latitude');
      if (riderLng == null || riderLat == null) {
        emit(state.copyWith(requestStatus: RequestStatus.failure));
        return;
      }

      final riderCoordinates = PlaceCoordinate(lat: riderLat, lng: riderLng);
      final userPickupCoordinates = PlaceCoordinate(
        lat: requests[event.selectedRequestIndex]
            .pickupData
            .position
            .geopoint
            .latitude,
        lng: requests[event.selectedRequestIndex]
            .pickupData
            .position
            .geopoint
            .longitude,
      );

      final userDestinationCoordinates = PlaceCoordinate(
        lat: requests[event.selectedRequestIndex]
            .dropoffData
            .position
            .geopoint
            .latitude,
        lng: requests[event.selectedRequestIndex]
            .dropoffData
            .position
            .geopoint
            .longitude,
      );

      // Create the Ployfills for the routes between the rider and the pickup locations
      add(
        GetPolylines(
          pickupCoordinate: riderCoordinates,
          desinationCoordinate: userPickupCoordinates,
        ),
      );

      PolylinePoints points = PolylinePoints();
      if (_directionsApiKey.isEmpty) {
        return;
      }

      PolylineResult startingPolylineResult =
          await points.getRouteBetweenCoordinates(
        googleApiKey: _directionsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(riderLat, riderLng),
          destination: PointLatLng(
            userPickupCoordinates.lat,
            userPickupCoordinates.lng,
          ),
          mode: TravelMode.driving,
        ),
      );

      PolylineResult endingPolylineResult =
          await points.getRouteBetweenCoordinates(
        googleApiKey: _directionsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(
            userPickupCoordinates.lat,
            userPickupCoordinates.lng,
          ),
          destination: PointLatLng(
            userDestinationCoordinates.lat,
            userDestinationCoordinates.lng,
          ),
          mode: TravelMode.driving,
        ),
      );

      final totalTime = 120 +
          startingPolylineResult.totalDurationValue! +
          endingPolylineResult.totalDistanceValue!;

      final formattedDeliveryTime = formattedTimeAfterSeconds(totalTime);
      final riderPhone = riderData?['phone'] ?? user.phoneNumber ?? '';
      final riderPhoto =
          '${riderData?['profileThumbnailUrl'] ?? riderData?['profilePhotoUrl'] ?? riderData?['photoURL'] ?? riderData?['photoUrl'] ?? user.photoURL ?? ''}';

      // final userData = await firebaseMessaging
      //     .subscribeToTopic('your_topic_name')
      //         'Successfully subscribed to your_topic_name')); // Replace with your topic name
      await MessagingServer().sendMessage(
        data: {
          'type': 'connection',
          'status': 'accepted',
          'data': '''{
                'courierName': '${user.displayName}',
                'photoURL': '$riderPhoto',
                'rating': '${riderData?['rating'] ?? '0'}',
                'plateNumber': '${riderData!['plateNumber']}',
                'typeOfVehicle': '${riderData['typeOfVehicle']}',
                'estimatedDeliveryTime': '$formattedDeliveryTime',
                'phoneNumber': '$riderPhone',
                'riderId': '${user.uid}',
                'code': '${riderData['fcmToken']}'
              }''',
        },
        code: event.code,
        message:
            '${user.displayName!.split(' ').first.trim()} will be picking up your parcel soon.',
      );

      await prefs.setString('courierName', '${user.displayName}');
      await prefs.setString('rating', '${riderData['rating']}');
      await prefs.setString('plateNumber', '${riderData['plateNumber']}');
      await prefs.setString('typeOfVehicle', '${riderData['typeOfVehicle']}');
      await prefs.setString('estimatedDeliveryTime', formattedDeliveryTime);
      await prefs.setString('phoneNumber', '$riderPhone');
      await prefs.setString('riderId', user.uid);
      await prefs.setString('code', '${riderData['fcmToken']}');
      await prefs.setString('userCode', event.code);

      // Verify that the ride was assigned to this rider

      final Completer<bool> rideAssigned = Completer();

      Timer.periodic(const Duration(seconds: 2), (timer) async {
        try {
          final requestID = requests[event.selectedRequestIndex].requestId;
          final docReference = db
              .collection('deliveryRequests')
              .where('requestId', isEqualTo: requestID);

          final docResponse = await docReference.get();
          final doc = docResponse.docs.firstOrNull;

          if (doc != null) {
            final data = doc.data();
            if (data['riderId'] != null && data['riderId'] == user.uid) {
              await FirebaseFunctions.instanceFor(region: 'us-central1')
                  .httpsCallable('confirmRiderActiveDelivery')
                  .call({'deliveryId': doc.id, 'requestId': requestID});
              if (!rideAssigned.isCompleted) rideAssigned.complete(true);
              timer.cancel();
            } else if (timer.tick ==
                    15 // Automatically cancel request after 30 sec
                ) {
              if (!rideAssigned.isCompleted) rideAssigned.complete(false);
              timer.cancel();
            }
          } else {
            if (!rideAssigned.isCompleted) rideAssigned.complete(false);
            timer.cancel();
          }
        } catch (_) {
          if (timer.tick >= 15) {
            if (!rideAssigned.isCompleted) rideAssigned.complete(false);
            timer.cancel();
          }
        }
      });

      final rideAssignedResult = await rideAssigned.future;
      // The ride was not assigned to this rider in 30s
      if (rideAssignedResult == false) {
        emit(state.copyWith(rideStatus: RideStatus.online));
        add(CancelRequest());
      }
      if (rideAssignedResult == true) {
        await prefs.setString(
          'activeRequest',
          requests[event.selectedRequestIndex].requestId,
        );
        emit(
          state.copyWith(
            rideStatus: RideStatus.userConfirmedRide,
            activeRequest: requests[event.selectedRequestIndex],
            actionButtonStatus: ActionButtonStatus.goingToPickupLocation,
          ),
        );

        add(BroadcastLocation());
      }
    } catch (_) {
      emit(state.copyWith(requestStatus: RequestStatus.failure));
    }
  }

  void _handleDeclineRequest(DeclineRequest event, Emitter emit) async {
    final updatedDispatchRequests = state.dispatchRequests
        .where((request) => request.requestId != event.requestId)
        .toList();
    emit(state.copyWith(dispatchRequests: updatedDispatchRequests));
  }

  void _handleSetSourceAndDestinationStatus(
    SetSourceAndDestinationStatus event,
    Emitter emit,
  ) {
    emit(state.copyWith(sourceAndDestinationStatus: event.status));
  }

  void _handleSetMapCameraStatus(SetMapCameraStatus event, Emitter emit) {
    emit(state.copyWith(mapCameraStatus: event.status));
  }

  void _handleSetDrawerHeight(SetDrawerHeight event, Emitter emit) {
    emit(
      state.copyWith(
        minDrawerHeight: event.minDrawerHeight,
        maxDrawerHeight: event.maxDrawerHeight,
      ),
    );
  }

  void _handleSetPanelControlStatus(SetPanelControlStatus event, Emitter emit) {
    emit(state.copyWith(panelControlStatus: event.status));
  }

  void _handleGetPolylines(GetPolylines event, Emitter emit) async {
    _currentRoute = await _directionsService.getDetailedDirections(
      LatLng(event.pickupCoordinate.lat, event.pickupCoordinate.lng),
      LatLng(event.desinationCoordinate.lat, event.desinationCoordinate.lng),
    );

    if (_currentRoute.isNotEmpty) {
      // Create a more detailed list of points by breaking down each route step
      List<LatLng> routePoints = _currentRoute
          .expand(
            (step) => step.polylinePoints.isNotEmpty
                ? step.polylinePoints
                : [step.startLocation, step.endLocation],
          )
          .toList();

      Polyline route = Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints, // Use the more detailed points
        color: AppColors.primary,
        width: 5,
        geodesic: true, // Helps create a more curved line on long routes
      );

      // Rest of your existing code remains the same
      List<Polyline> polyLines = [route];

      final Marker sourceMarker = Marker(
        markerId: const MarkerId('source_marker'),
        position: LatLng(
          event.pickupCoordinate.lat,
          event.pickupCoordinate.lng,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );

      final Marker destinationMarker = Marker(
        markerId: const MarkerId('destination_marker'),
        position: LatLng(
          event.desinationCoordinate.lat,
          event.desinationCoordinate.lng,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );

      Map<MarkerId, Marker> markers = {
        const MarkerId('source_marker'): sourceMarker,
        const MarkerId('destination_marker'): destinationMarker,
      };

      emit(state.copyWith(polylines: polyLines, markers: markers));

      add(
        SetSourceAndDestinationStatus(
          status: SourceAndDestinationStatus.selected,
        ),
      );
    }
  }

  void _handlerCancelRequest(CancelRequest event, Emitter emit) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeRequest');
    await prefs.remove('courierName');
    await prefs.remove('rating');
    await prefs.remove('plateNumber');
    await prefs.remove('typeOfVehicle');
    await prefs.remove('estimatedDeliveryTime');
    await prefs.remove('phoneNumber');
    await prefs.remove('riderId');
    await prefs.remove('code');
    List<Polyline> polylines = [];
    Map<MarkerId, Marker> markers = {};
    emit(
      state.copyWith(
        polylines: polylines,
        markers: markers,
        polylineCoordinates: [],
        dispatchRequests: [],
      ),
    );
  }

  void _handleBroadcastLocation(BroadcastLocation event, Emitter emit) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final double? riderLng = prefs.getDouble('longitude');
      final double? riderLat = prefs.getDouble('latitude');
      final String? riderId = prefs.getString('riderId');
      emit(state.copyWith(broadcastStatus: BroadcastStatus.broadcasting));
      if (state.activeRequest != null &&
          (state.rideStatus == RideStatus.userConfirmedRide ||
              state.rideStatus == RideStatus.outForDelivery)) {
        final icon =
            await BitmapDescriptorHelper.getBitmapDescriptorFromSvgAsset(
          "assets/svg/bike_top.svg",
        );
        final Marker riderLocationMarker = Marker(
          markerId: const MarkerId('rider_location_marker'),
          position: LatLng(
            riderLat!,
            riderLng!,
          ), // Destination address location
          icon: icon,
        );

        Map<MarkerId, Marker> markers = Map.of(state.markers);

        markers[const MarkerId('rider_location_marker')] = riderLocationMarker;

        emit(state.copyWith(markers: markers));

        // final SharedPreferences prefs = await SharedPreferences.getInstance();
        final courierName = prefs.getString('courierName');
        Map<String, dynamic>? riderSnapshotData;
        try {
          riderSnapshotData =
              (await db.collection('riders').doc(riderId).get()).data();
        } catch (_) {
          // Rider photo fallback uses the authenticated user profile.
        }
        final riderPhoto =
            '${riderSnapshotData?['profileThumbnailUrl'] ?? riderSnapshotData?['profilePhotoUrl'] ?? riderSnapshotData?['photoURL'] ?? riderSnapshotData?['photoUrl'] ?? auth.currentUser?.photoURL ?? ''}';
        final rating = prefs.getString('rating');
        final plateNumber = prefs.getString('plateNumber');
        final typeOfVehicle = prefs.getString('typeOfVehicle');
        final estimatedDeliveryTime = prefs.getString('estimatedDeliveryTime');
        final phoneNumber = prefs.getString('phoneNumber');
        final code = prefs.getString('code');
        await MessagingServer().sendMessage(
          data: {
            'type': 'location-broadcast',
            'data': '''{
                'riderId': '$riderId',
                'latitude': '$riderLat',
                'longitude': '$riderLng',
                'courierName': '$courierName',
                'photoURL': '$riderPhoto',
                'rating': '$rating',
                'plateNumber': '$plateNumber',
                'typeOfVehicle': '$typeOfVehicle',
                'estimatedDeliveryTime': '$estimatedDeliveryTime',
                'phoneNumber': '$phoneNumber',
                'code': '$code'
              }''',
          },
          code: state.activeRequest!.code,
          message: "Broadcasting rider's location",
        );
        await Future.delayed(const Duration(seconds: 5));
        emit(state.copyWith(broadcastStatus: BroadcastStatus.initialized));
      }
    } catch (e) {
      emit(state.copyWith(broadcastStatus: BroadcastStatus.initialized));
    }
  }

  void _handleCheckForActiveRequest(
    CheckForActiveRequest event,
    Emitter emit,
  ) async {
    final user = auth.currentUser;
    if (user == null) {
      add(CancelRequest());
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final double? riderLng = prefs.getDouble('longitude');
    final double? riderLat = prefs.getDouble('latitude');
    String? statusString = prefs.getString('status');
    RideStatus? status;
    final backendPresenceOnline =
        await _backendPresenceIndicatesOnline(user.uid);
    if (statusString == 'online' || backendPresenceOnline) {
      status = RideStatus.online;
      _startPresenceHeartbeat();
      emit(
        state.copyWith(
          rideStatus: RideStatus.online,
          canGoOnline: true,
          message: null,
        ),
      );
      add(GetAvailableRequests());
      add(
        SetDrawerHeight(
          minDrawerHeight: state.minDrawerHeight,
          maxDrawerHeight: 0.75.sh,
        ),
      );
      add(SetPanelControlStatus(status: PanelControlStatus.isOpened));
    }
    final resolution = await RiderActiveDeliveryResolver(
      firestore: db,
    ).resolve(riderId: user.uid);
    final data = resolution.data;
    if (!resolution.hasActiveDelivery || data == null) {
      add(CancelRequest());
      return;
    }

    final activeRequest = DispatchRequest.fromJson(data);
    final normalized = resolution.status ??
        RiderActiveDeliveryResolver.normalizeStatus(
          data['deliveryStage'] ?? data['deliveryStatus'] ?? data['status'],
        );
    final towardPickup = {
      'accepted',
      'navigating_to_pickup',
      'arrived_at_pickup',
      'waiting',
      'pickup_verification',
      'pickup_verified',
    }.contains(normalized);
    status =
        towardPickup ? RideStatus.userConfirmedRide : RideStatus.outForDelivery;
    final pickup = PlaceCoordinate(
      lat: activeRequest.pickupData.position.geopoint.latitude,
      lng: activeRequest.pickupData.position.geopoint.longitude,
    );
    final dropoff = PlaceCoordinate(
      lat: activeRequest.dropoffData.position.geopoint.latitude,
      lng: activeRequest.dropoffData.position.geopoint.longitude,
    );
    if (towardPickup && riderLat != null && riderLng != null) {
      add(
        GetPolylines(
          desinationCoordinate: pickup,
          pickupCoordinate: PlaceCoordinate(lat: riderLat, lng: riderLng),
        ),
      );
      emit(
        state.copyWith(
          actionButtonStatus: normalized == 'arrived_at_pickup'
              ? ActionButtonStatus.arrivedPickupLocation
              : ActionButtonStatus.goingToPickupLocation,
        ),
      );
    } else {
      add(
        GetPolylines(desinationCoordinate: dropoff, pickupCoordinate: pickup),
      );
      emit(
        state.copyWith(actionButtonStatus: ActionButtonStatus.outForDelivery),
      );
    }
    emit(state.copyWith(rideStatus: status, activeRequest: activeRequest));
    add(BroadcastLocation());
  }

  Future<bool> _backendPresenceIndicatesOnline(String uid) async {
    try {
      final snapshot = await db.collection('riderPresence').doc(uid).get();
      final data = snapshot.data();
      if (data == null) return false;
      final availability = '${data['availabilityStatus'] ?? ''}'.toLowerCase();
      final status = '${data['status'] ?? ''}'.toLowerCase();
      if (availability == 'offline' || status == 'offline') return false;
      return data['isOnline'] == true ||
          availability == 'online' ||
          status == 'online' ||
          data['currentLocation'] is Map ||
          data['lastLocationAt'] != null;
    } catch (_) {
      return false;
    }
  }

  void _handleIncomingMessage(IncomingMessage event, Emitter emit) async {
    final chatMessages = [...state.chatMessages];

    final newMessage = Message.fromJson(event.data);
    chatMessages.add(newMessage);

    emit(
      state.copyWith(
        chatMessages: chatMessages,
        chatStatus: ChatStatus.newMessage,
      ),
    );
  }

  void _startPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    unawaited(_sendPresenceHeartbeat());
    _presenceHeartbeatTimer = Timer.periodic(
      _presenceHeartbeatInterval,
      (_) => unawaited(_sendPresenceHeartbeat()),
    );
  }

  void _stopPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
  }

  Future<void> _sendPresenceHeartbeat() async {
    if (auth.currentUser == null || !state.availability.intendsToBeOnline) {
      _stopPresenceHeartbeat();
      return;
    }
    try {
      final locationPayload = await _currentPresenceLocationPayload(
        highAccuracy: false,
      );
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('updateRiderPresence')
          .call(
            locationPayload == null
                ? <String, dynamic>{}
                : <String, dynamic>{'location': locationPayload},
          );
    } catch (error, stackTrace) {
      // Dispatch excludes stale riders until heartbeats recover.
      debugPrint(
        '[RIDER_PRESENCE_HEARTBEAT] uid=${auth.currentUser?.uid ?? 'signed_out'} '
        'updateRiderPresence failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<Map<String, dynamic>?> _currentPresenceLocationPayload({
    required bool highAccuracy,
    bool requestPermission = false,
  }) async {
    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        throw const _RiderLocationUnavailable(
          'Turn on location services before going online.',
        );
      }
      var permission = await Geolocator.checkPermission();
      debugPrint(
        '[GPS_HEALTH_CLIENT] permission=$permission web=$kIsWeb highAccuracy=$highAccuracy',
      );
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
        debugPrint('[GPS_HEALTH_CLIENT] permissionAfterRequest=$permission');
      }
      if (permission == LocationPermission.denied) {
        throw const _RiderLocationUnavailable(
          'Allow location access before going online.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        if (!requestPermission) {
          final fallback = await _freshWebPresenceLocationPayload();
          if (fallback != null) return fallback;
        }
        throw const _RiderLocationUnavailable(
          'Location access is blocked. Enable it in your browser or device settings before going online.',
        );
      }
      if (permission == LocationPermission.unableToDetermine) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
      );
      debugPrint(
        '[GPS_HEALTH_CLIENT] position latitude=${position.latitude} '
        'longitude=${position.longitude} accuracy=${position.accuracy} '
        'timestamp=${position.timestamp} speed=${position.speed} '
        'heading=${position.heading}',
      );
      return <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracyMeters': position.accuracy,
        'heading': position.heading,
        'speed': position.speed,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'gpsStatus': position.accuracy <= 100 ? 'active' : 'poorAccuracy',
        'gpsSignalQuality': _gpsSignalQuality(position.accuracy),
        'permission': permission.name,
        'backgroundTracking': kIsWeb ? 'foregroundOnly' : 'available',
      };
    } on _RiderLocationUnavailable {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[GPS_HEALTH_CLIENT] locationException=$error');
      debugPrintStack(stackTrace: stackTrace);
      if (!requestPermission) {
        final fallback = await _freshWebPresenceLocationPayload();
        if (fallback != null) return fallback;
      }
      if (requestPermission) {
        throw const _RiderLocationUnavailable(
          'Location could not refresh. Keep this tab open, allow location access, and try again.',
        );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _onlinePresenceLocationPayload() async {
    return _currentPresenceLocationPayload(
      highAccuracy: true,
      requestPermission: true,
    );
  }

  Future<Map<String, dynamic>?> _freshWebPresenceLocationPayload() async {
    if (!kIsWeb) return null;
    final user = auth.currentUser;
    if (user == null) return null;
    try {
      final snapshot = await db.collection('riderPresence').doc(user.uid).get();
      final data = snapshot.data();
      if (data == null) return null;
      final location = data['currentLocation'];
      if (location is! Map) {
        debugPrint('[GPS_HEALTH_CLIENT] cachedPresence=no_location');
        return null;
      }
      final latitude = (location['latitude'] as num?)?.toDouble();
      final longitude = (location['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        debugPrint('[GPS_HEALTH_CLIENT] cachedPresence=invalid_coordinates');
        return null;
      }
      final updatedAt = _millisFromPresenceTime(
        location['updatedAt'] ?? data['lastLocationAt'],
      );
      if (updatedAt == null) {
        debugPrint('[GPS_HEALTH_CLIENT] cachedPresence=missing_timestamp');
        return null;
      }
      final age = DateTime.now().millisecondsSinceEpoch - updatedAt;
      if (age < 0 || age > 24 * 60 * 60 * 1000) {
        debugPrint('[GPS_HEALTH_CLIENT] cachedPresence=stale ageMs=$age');
        return null;
      }
      final accuracy = (location['accuracyMeters'] as num?)?.toDouble() ??
          (location['accuracy'] as num?)?.toDouble() ??
          0;
      debugPrint(
        '[GPS_HEALTH_CLIENT] cachedPresence latitude=$latitude '
        'longitude=$longitude accuracy=$accuracy ageMs=$age',
      );
      return <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracy,
        'heading': (location['heading'] as num?)?.toDouble() ?? 0,
        'speed': (location['speed'] as num?)?.toDouble() ?? 0,
        'updatedAt': updatedAt,
        'gpsStatus': accuracy > 0 && accuracy <= 100 ? 'active' : 'unknown',
        'gpsSignalQuality': _gpsSignalQuality(accuracy),
        'permission': 'cachedForeground',
        'backgroundTracking': 'foregroundOnly',
      };
    } catch (error, stackTrace) {
      debugPrint('[GPS_HEALTH_CLIENT] cachedPresenceException=$error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  int? _millisFromPresenceTime(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    final parsed = DateTime.tryParse('$value');
    return parsed?.millisecondsSinceEpoch;
  }

  String _gpsSignalQuality(double accuracyMeters) {
    if (accuracyMeters <= 25) return 'high';
    if (accuracyMeters <= 80) return 'medium';
    return 'reduced';
  }

  @override
  Future<void> close() {
    _stopPresenceHeartbeat();
    final authSubscription = _authStateSubscription;
    final presenceSubscription = _presenceSubscription;
    if (authSubscription != null) unawaited(authSubscription.cancel());
    if (presenceSubscription != null) {
      unawaited(presenceSubscription.cancel());
    }
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }

  void _handleSetNewMessage(SetNewMessage event, Emitter emit) {
    emit(state.copyWith(message: event.value));
  }

  void _handleLoadChatMessages(LoadChatMessages event, Emitter emit) async {
    final directory = await getApplicationDocumentsDirectory();
    final chats = File(
      '${directory.path}/${state.activeRequest!.requestId}.json',
    );

    if (await chats.exists()) {
      final contents = await chats.readAsString();
      final jsonData = await jsonDecode(contents) as List;

      final messagesList = jsonData.map((e) => Message.fromJson(e)).toList();
      emit(
        state.copyWith(
          chatMessages: messagesList,
          chatStatus: ChatStatus.newMessage,
        ),
      );
    }
  }

  void _handleMessageUser(MessageUser event, Emitter emit) async {
    try {
      final User? user = auth.currentUser;
      // final SharedPreferences prefs = await SharedPreferences.getInstance();
      // final String? activeRequest = prefs.getString('activeRequest');
      // final String? code = prefs.getString('code');

      final messageData = {
        'requestId': state.activeRequest!.requestId,
        'senderId': user!.uid,
        'message': event.message,
        'timeStamp': '${DateTime.now()}',
      };

      await _communicationService.sendText(
        chatId: state.activeRequest!.requestId,
        message: event.message,
      );

      add(IncomingMessage(data: messageData));
    } catch (_) {
      emit(state.copyWith(message: event.message));
    }
  }
}

class _RiderLocationUnavailable implements Exception {
  const _RiderLocationUnavailable(this.message);

  final String message;
}

class _RiderAvailabilityTimeout implements Exception {
  const _RiderAvailabilityTimeout();
}

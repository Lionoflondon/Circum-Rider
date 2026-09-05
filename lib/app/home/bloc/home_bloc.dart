import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../models/dispatch_request.m..dart';
import '../models/message.m.dart';
import '../models/place_coordinates.m.dart';
import '../repo/direction_service.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> with WidgetsBindingObserver {
  static const _mapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const _presenceHeartbeatInterval = Duration(seconds: 45);
  static const _desiredOnlineStateKey = 'desiredOnlineState';

  FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  final DirectionsService _directionsService = DirectionsService();
  final RiderCommunicationService _communicationService =
      RiderCommunicationService();

  List<DirectionStep> _currentRoute = [];
  Timer? _presenceHeartbeatTimer;
  Timer? _presenceReconnectTimer;
  Position? _lastPresencePosition;
  bool _presenceHeartbeatInFlight = false;
  int _availabilityOperation = 0;
  int _presenceReconnectAttempt = 0;

  bool get _isLogicallyOnline {
    if (state.riderIntentOnline) return true;
    switch (state.rideStatus) {
      case RideStatus.online:
      case RideStatus.acceptedARide:
      case RideStatus.userConfirmedRide:
      case RideStatus.arrivedAtPickupLocation:
      case RideStatus.outForDelivery:
        return true;
      case RideStatus.offline:
      case RideStatus.delivered:
        return false;
    }
  }

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
    if (uid == null || uid.isEmpty) return ['Rider profile'];
    final riderDoc = await db
        .collection('riders')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 15));
    return _remainingVerificationItems(riderDoc.data());
  }

  Future<RiderAccountState> _loadAccountState(String? uid) async {
    if (uid == null || uid.isEmpty) {
      return RiderAccountState.onboardingNotStarted;
    }
    final records = await Future.wait([
      db.collection('riders').doc(uid).get(),
      db.collection('riderProfiles').doc(uid).get(),
    ]).timeout(const Duration(seconds: 15));
    return RiderAccountStateResolver.resolve({
      ...(records[1].data() ?? const <String, dynamic>{}),
      ...(records[0].data() ?? const <String, dynamic>{}),
    });
  }

  HomeBloc() : super(HomeState()) {
    WidgetsBinding.instance.addObserver(this);
    on<CheckForPushToken>(_handleCheckForPushToken);
    on<SetRideStatus>(_handleSetRideStatus);
    on<PresenceHeartbeatResult>(_handlePresenceHeartbeatResult);
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isLogicallyOnline) {
          _startPresenceHeartbeat();
          _schedulePresenceReconnect(immediate: true);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopPresenceHeartbeat();
        _stopPresenceReconnect();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _handleCheckForPushToken(CheckForPushToken event, Emitter emit) async {
    final User? user = auth.currentUser;
    var internalAccess = false;
    if (user != null) {
      try {
        internalAccess = (await user.getIdTokenResult().timeout(
                      const Duration(seconds: 15),
                    ))
                .claims?['founderRider'] ==
            true;
      } catch (_) {
        internalAccess = false;
      }
    }
    if (!kIsWeb && Platform.isIOS) {
      await firebaseMessaging.requestPermission();
    }
    if (!kIsWeb && Platform.isIOS) {
      await firebaseMessaging.getAPNSToken();
    }
    final fcmToken = await firebaseMessaging.getToken();
    if (fcmToken != null) {
      try {
        final documentReference = db.collection('riders').doc(user?.uid);

        // Get the document snapshot
        final documentSnapshot = await documentReference.get();
        if (documentSnapshot.exists) {
          final remaining = _remainingVerificationItems(
            documentSnapshot.data(),
          );
          emit(
            state.copyWith(
              canGoOnline: internalAccess || remaining.isEmpty,
              verificationChecklist: remaining,
            ),
          );
          await db
              .collection("riders")
              .doc(user?.uid)
              .update({'fcmToken': fcmToken, 'updatedAt': DateTime.now()}).then(
                  (value) {},
                  onError: (e) {});
        }
      } catch (_) {
        // Push token updates should not block the Rider home state.
      }
    }
  }

  void _handleSetRideStatus(
    SetRideStatus event,
    Emitter<HomeState> emit,
  ) async {
    final operation = ++_availabilityOperation;
    final User? user = auth.currentUser;
    var internalAccess = false;
    if (user == null) {
      emit(
        state.copyWith(message: 'Sign in before changing Rider availability.'),
      );
      return;
    }
    try {
      internalAccess = (await user.getIdTokenResult().timeout(
                    const Duration(seconds: 15),
                  ))
              .claims?['founderRider'] ==
          true;
    } catch (_) {
      internalAccess = false;
    }
    if (event.status == RideStatus.offline) {
      try {
        _stopPresenceHeartbeat();
        _stopPresenceReconnect();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_desiredOnlineStateKey, false);
        emit(
          state.copyWith(
            rideStatus: RideStatus.offline,
            onlineTransition: OnlineTransition.offline,
            riderIntentOnline: false,
            clearMessage: true,
          ),
        );
        await FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('goOffline')
            .call()
            .timeout(const Duration(seconds: 20));
        if (operation != _availabilityOperation) return;
        emit(
          state.copyWith(
            rideStatus: RideStatus.offline,
            onlineTransition: OnlineTransition.offline,
            riderIntentOnline: false,
            clearMessage: true,
            requestStatus: RequestStatus.initial,
          ),
        );
      } on FirebaseFunctionsException catch (error) {
        emit(state.copyWith(message: error.message ?? 'Could not go offline.'));
      } catch (_) {
        emit(
          state.copyWith(
            rideStatus: RideStatus.offline,
            onlineTransition: OnlineTransition.blocked,
            message: 'Could not go offline. Check your connection and retry.',
          ),
        );
      }
      return;
    } else {
      RiderAccountState accountState;
      List<String> remaining;
      try {
        accountState = await _loadAccountState(user.uid);
        remaining = await _loadRemainingVerificationItems(user.uid);
      } catch (_) {
        emit(
          state.copyWith(
            rideStatus: RideStatus.offline,
            onlineTransition: OnlineTransition.blocked,
            message: 'Rider status could not be checked. Try again.',
          ),
        );
        return;
      }
      if (!internalAccess &&
          !RiderAccountStateResolver.canOperate(accountState)) {
        emit(
          state.copyWith(
            rideStatus: RideStatus.offline,
            canGoOnline: false,
            message:
                'Your Rider account is not approved for operational access.',
          ),
        );
        return;
      }
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
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_desiredOnlineStateKey, true);
          emit(
            state.copyWith(
              rideStatus: RideStatus.online,
              onlineTransition: OnlineTransition.acquiringPermission,
              riderIntentOnline: true,
              clearMessage: true,
            ),
          );
          final locationPayload = await _freshPresenceLocationPayload(emit);
          if (operation != _availabilityOperation) return;
          emit(
            state.copyWith(
              onlineTransition: OnlineTransition.registeringOnline,
              message: 'Registering your availability…',
            ),
          );
          final response =
              await FirebaseFunctions.instanceFor(region: 'us-central1')
                  .httpsCallable('goOnline')
                  .call(<String, dynamic>{'location': locationPayload}).timeout(
                      const Duration(seconds: 20));
          if (operation != _availabilityOperation) return;
          if (!isPresenceRegistrationAcknowledged(response.data)) {
            throw StateError('Online registration was not acknowledged.');
          }
          _stopPresenceReconnect();
          emit(
            state.copyWith(
              rideStatus: RideStatus.online,
              onlineTransition: OnlineTransition.online,
              riderIntentOnline: true,
              canGoOnline: true,
              clearMessage: true,
            ),
          );
          _startPresenceHeartbeat();
          add(GetAvailableRequests());
          add(
            SetDrawerHeight(
              minDrawerHeight: state.minDrawerHeight,
              maxDrawerHeight: 0.75.sh,
            ),
          );
          add(SetPanelControlStatus(status: PanelControlStatus.isOpened));
        } on RiderLocationException catch (error) {
          _stopPresenceHeartbeat();
          _stopPresenceReconnect();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_desiredOnlineStateKey, false);
          emit(
            state.copyWith(
              rideStatus: RideStatus.offline,
              onlineTransition: OnlineTransition.blocked,
              riderIntentOnline: false,
              message: error.message,
            ),
          );
        } on FirebaseFunctionsException catch (error) {
          debugPrint('Rider presence registration failed code=${error.code}');
          if (_isTransientPresenceFailure(error.code)) {
            emit(
              state.copyWith(
                rideStatus: RideStatus.online,
                onlineTransition: OnlineTransition.reconnecting,
                riderIntentOnline: true,
                message: _presenceFailureMessage(error.code),
              ),
            );
            _startPresenceHeartbeat();
            _schedulePresenceReconnect();
          } else {
            _stopPresenceHeartbeat();
            _stopPresenceReconnect();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_desiredOnlineStateKey, false);
            emit(
              state.copyWith(
                rideStatus: RideStatus.offline,
                onlineTransition: OnlineTransition.blocked,
                riderIntentOnline: false,
                message: _presenceFailureMessage(error.code),
              ),
            );
          }
        } catch (_) {
          emit(
            state.copyWith(
              rideStatus: RideStatus.online,
              onlineTransition: OnlineTransition.reconnecting,
              riderIntentOnline: true,
              message:
                  'Circum connection interrupted. Reconnecting automatically.',
            ),
          );
          _startPresenceHeartbeat();
          _schedulePresenceReconnect();
        }
        return;
      }
    }
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
      // Offer cards are owned by RiderOfferFeed. This legacy bloc retains only
      // assigned delivery DTOs; projected offers intentionally lack private GPS/contact fields.
      if (response.data['riderId'] != auth.currentUser?.uid) {
        throw StateError(
            'Offer authorization does not match the signed-in Rider');
      }
      emit(
        state.copyWith(
          dispatchRequests: const [],
          requestStatus: RequestStatus.success,
        ),
      );
    } catch (e) {
      emit(state.copyWith(requestStatus: RequestStatus.failure));
    }
  }

  void _handleSetHomeLocationData(SetHomeLocationData event, Emitter emit) {
    emit(state.copyWith(locationData: event.locationData));
  }

  void _handleAcceptRide(AcceptRide event, Emitter emit) async {
    try {
      final User? user = auth.currentUser;
      final requests = state.dispatchRequests;
      if (user == null ||
          event.selectedRequestIndex < 0 ||
          event.selectedRequestIndex >= requests.length) {
        emit(state.copyWith(rideStatus: RideStatus.online));
        return;
      }
      // Obtain shared preferences.
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final documentReference = db.collection('riders').doc(user.uid);
      // Get the document snapshot
      final documentSnapshot = await documentReference.get();

      final riderData = documentSnapshot.data();

      emit(
        state.copyWith(
          rideStatus: RideStatus.acceptedARide,
          selectedRequestIndex: event.selectedRequestIndex,
          activeRequest: requests[event.selectedRequestIndex],
        ),
      );

      final double? riderLng = prefs.getDouble('longitude');
      final double? riderLat = prefs.getDouble('latitude');

      final riderCoordinates = PlaceCoordinate(lat: riderLat!, lng: riderLng!);
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

      PolylineResult startingPolylineResult =
          await points.getRouteBetweenCoordinates(
        googleApiKey: _mapsApiKey,
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
        googleApiKey: _mapsApiKey,
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
            '${user.displayName?.split(' ').first.trim() ?? 'Your Rider'} will be picking up your parcel soon.',
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
      Timer? assignmentTimer;

      assignmentTimer = Timer.periodic(const Duration(seconds: 2), (
        timer,
      ) async {
        final requestID = requests[event.selectedRequestIndex].requestId;
        final docReference = db
            .collection('deliveryRequests')
            .where('requestId', isEqualTo: requestID)
            .where('riderId', isEqualTo: user.uid);

        try {
          final docResponse = await docReference.get().timeout(
                const Duration(seconds: 10),
              );
          final doc = docResponse.docs.firstOrNull;

          if (doc != null) {
            final data = doc.data();
            if (data['riderId'] != null && data['riderId'] == user.uid) {
              // Set user as the active delivery;
              await documentReference.update({
                'activeDelivery': doc.id,
                'updatedAt': DateTime.now(),
              }).timeout(const Duration(seconds: 10));
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
          if (!rideAssigned.isCompleted) rideAssigned.complete(false);
          timer.cancel();
        }
      });

      final rideAssignedResult = await rideAssigned.future.timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          assignmentTimer?.cancel();
          return false;
        },
      );
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
        const riderMarkerId = MarkerId('rider_location_marker');
        final Marker riderLocationMarker = Marker(
          markerId: riderMarkerId,
          position: LatLng(
            riderLat!,
            riderLng!,
          ), // Destination address location
          icon: icon,
        );

        final Map<MarkerId, Marker> markers = Map.of(state.markers);

        markers[riderMarkerId] = riderLocationMarker;

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
    User? user = auth.currentUser;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final desiredOnline = prefs.getBool(_desiredOnlineStateKey) == true;
    final double? riderLng = prefs.getDouble('longitude');
    final double? riderLat = prefs.getDouble('latitude');
    String? statusString = prefs.getString('status');
    RideStatus? status;
    final presenceSnapshot = user == null
        ? null
        : await db.collection('riderPresence').doc(user.uid).get();
    final presence = presenceSnapshot?.data();
    final presenceOnline = presence?['isOnline'] == true &&
        '${presence?['availabilityStatus'] ?? ''}'.toLowerCase() != 'offline';
    emit(state.copyWith(riderIntentOnline: desiredOnline || presenceOnline));
    if (desiredOnline || presenceOnline || statusString == 'online') {
      add(SetRideStatus(status: RideStatus.online));
    }
    final documentReference = db
        .collection('deliveryRequests')
        .where('riderId', isEqualTo: user!.uid);

    final docResponse = await documentReference.get();
    // final doc = docResponse.docs.firstOrNull;

    for (final doc in docResponse.docs) {
      final data = doc.data();
      final activeRequest = DispatchRequest.fromJson(data);

      PlaceCoordinate pickupCoordinates;
      PlaceCoordinate desinationCoordinate;

      final deliveryStatus = '${data['status'] ?? ''}';
      final activeDelivery = deliveryStatus == 'accepted' ||
          deliveryStatus == 'outForDelivery' ||
          deliveryStatus == 'arrivedAtPickup' ||
          deliveryStatus == 'arrived_at_pickup' ||
          deliveryStatus == 'arrivedAtDropoff' ||
          deliveryStatus == 'arrived_at_dropoff';
      if (!activeDelivery) continue;

      if (deliveryStatus == 'accepted') {
        status = RideStatus.userConfirmedRide;
        pickupCoordinates = PlaceCoordinate(lat: riderLat!, lng: riderLng!);
        desinationCoordinate = PlaceCoordinate(
          lat: activeRequest.pickupData.position.geopoint.latitude,
          lng: activeRequest.pickupData.position.geopoint.longitude,
        );
        add(
          GetPolylines(
            desinationCoordinate: desinationCoordinate,
            pickupCoordinate: pickupCoordinates,
          ),
        );
        emit(
          state.copyWith(
            actionButtonStatus: ActionButtonStatus.goingToPickupLocation,
          ),
        );
      }

      if (deliveryStatus == 'outForDelivery') {
        status = RideStatus.outForDelivery;
        pickupCoordinates = PlaceCoordinate(
          lat: activeRequest.pickupData.position.geopoint.latitude,
          lng: activeRequest.pickupData.position.geopoint.longitude,
        );
        desinationCoordinate = PlaceCoordinate(
          lat: activeRequest.dropoffData.position.geopoint.latitude,
          lng: activeRequest.dropoffData.position.geopoint.longitude,
        );
        add(
          GetPolylines(
            desinationCoordinate: desinationCoordinate,
            pickupCoordinate: pickupCoordinates,
          ),
        );
        emit(
          state.copyWith(actionButtonStatus: ActionButtonStatus.outForDelivery),
        );
      }

      if (status != null) add(SetRideStatus(status: status));

      emit(state.copyWith(rideStatus: status));

      if (data['status'] != 'confirmed') {
        emit(state.copyWith(activeRequest: activeRequest));
        add(BroadcastLocation());
      }
    }

    if (docResponse.docs.isEmpty) {
      add(CancelRequest());
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
    _presenceHeartbeatTimer = Timer.periodic(_presenceHeartbeatInterval, (_) {
      if (_isLogicallyOnline) unawaited(_sendPresenceHeartbeat());
    });
  }

  void _handlePresenceHeartbeatResult(
    PresenceHeartbeatResult event,
    Emitter<HomeState> emit,
  ) {
    if (!_isLogicallyOnline) return;
    emit(
      state.copyWith(
        onlineTransition: event.succeeded
            ? OnlineTransition.online
            : OnlineTransition.reconnecting,
        message: event.succeeded
            ? null
            : 'Connection interrupted. Reconnecting automatically…',
        clearMessage: event.succeeded,
      ),
    );
    if (event.succeeded) {
      _stopPresenceReconnect();
    } else {
      _schedulePresenceReconnect();
    }
  }

  void _stopPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
  }

  void _schedulePresenceReconnect({bool immediate = false}) {
    if (!state.riderIntentOnline || _presenceReconnectTimer != null) return;
    final seconds = immediate
        ? 0
        : <int>[2, 4, 8, 16, 30][_presenceReconnectAttempt.clamp(0, 4)];
    _presenceReconnectAttempt++;
    _presenceReconnectTimer = Timer(Duration(seconds: seconds), () {
      _presenceReconnectTimer = null;
      if (!isClosed && state.riderIntentOnline) {
        add(SetRideStatus(status: RideStatus.online));
      }
    });
  }

  void _stopPresenceReconnect() {
    _presenceReconnectTimer?.cancel();
    _presenceReconnectTimer = null;
    _presenceReconnectAttempt = 0;
  }

  Future<void> _sendPresenceHeartbeat() async {
    if (_presenceHeartbeatInFlight) return;
    if (auth.currentUser == null || !_isLogicallyOnline) {
      _stopPresenceHeartbeat();
      return;
    }
    _presenceHeartbeatInFlight = true;
    try {
      final locationPayload = await _currentPresenceLocationPayload(
        highAccuracy: false,
      );
      if (locationPayload == null) {
        throw const RiderLocationException(
          'A current location is unavailable.',
        );
      }
      final response =
          await FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('updateRiderPresence')
              .call(<String, dynamic>{'location': locationPayload}).timeout(
                  const Duration(seconds: 20));
      final result = response.data;
      if (!isClosed) {
        add(
          PresenceHeartbeatResult(
            succeeded: result is Map && result['success'] == true,
          ),
        );
      }
    } catch (error) {
      debugPrint('Rider presence heartbeat failed type=${error.runtimeType}');
      if (!isClosed) add(PresenceHeartbeatResult(succeeded: false));
    } finally {
      _presenceHeartbeatInFlight = false;
    }
  }

  Future<Map<String, dynamic>?> _currentPresenceLocationPayload({
    required bool highAccuracy,
  }) async {
    var permission = LocationPermission.denied;
    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) return null;
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 15));
      if (isFreshDispatchLocation(
        capturedAt: position.timestamp,
        accuracyMeters: position.accuracy,
      )) {
        _lastPresencePosition = position;
        return _presenceLocationPayload(position, permission);
      }
    } catch (_) {
      // A recent valid fix can bridge one transient GPS refresh failure.
    }
    final cached = _lastPresencePosition;
    if (cached != null &&
        isFreshDispatchLocation(
          capturedAt: cached.timestamp,
          accuracyMeters: cached.accuracy,
        )) {
      return _presenceLocationPayload(cached, permission);
    }
    return null;
  }

  Future<Map<String, dynamic>> _freshPresenceLocationPayload(
    Emitter<HomeState> emit,
  ) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const RiderLocationException(
        'Location Services are off. Enable them in Settings to go online.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const RiderLocationException(
        'Location permission is required. Allow location access in Settings.',
      );
    }
    emit(
      state.copyWith(
        onlineTransition: OnlineTransition.acquiringLocation,
        message: 'Getting your location…',
      ),
    );
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(const Duration(seconds: 20));
    final capturedAt = position.timestamp;
    if (!isFreshDispatchLocation(
      capturedAt: capturedAt,
      accuracyMeters: position.accuracy,
    )) {
      throw const RiderLocationException(
        'We could not get an accurate current location. Move to an open area and try again.',
      );
    }
    _lastPresencePosition = position;
    return _presenceLocationPayload(position, permission);
  }

  Map<String, dynamic> _presenceLocationPayload(
    Position position,
    LocationPermission permission,
  ) {
    return <String, dynamic>{
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracyMeters': position.accuracy,
      'heading': position.heading,
      'speed': position.speed,
      'updatedAt': position.timestamp.millisecondsSinceEpoch,
      'gpsStatus': position.accuracy <= 100 ? 'active' : 'poorAccuracy',
      'gpsSignalQuality': _gpsSignalQuality(position.accuracy),
      'permission': permission.name,
      'backgroundTracking': kIsWeb ? 'foregroundOnly' : 'available',
    };
  }

  String _presenceFailureMessage(String code) {
    switch (code) {
      case 'unauthenticated':
        return 'Sign in before changing Rider availability.';
      case 'permission-denied':
        return 'Rider availability could not be verified. Try signing in again.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Circum connection interrupted. Reconnecting automatically.';
      case 'failed-precondition':
        return 'Your Rider account is not currently able to go online.';
      default:
        return 'Could not go online. Check your connection and retry.';
    }
  }

  bool _isTransientPresenceFailure(String code) => const {
        'aborted',
        'cancelled',
        'deadline-exceeded',
        'internal',
        'resource-exhausted',
        'unavailable',
        'unknown',
      }.contains(code);

  String _gpsSignalQuality(double accuracyMeters) {
    if (accuracyMeters <= 25) return 'high';
    if (accuracyMeters <= 80) return 'medium';
    return 'reduced';
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPresenceHeartbeat();
    _stopPresenceReconnect();
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

class RiderLocationException implements Exception {
  const RiderLocationException(this.message);
  final String message;
}

bool isFreshDispatchLocation({
  required DateTime capturedAt,
  required double accuracyMeters,
  DateTime? now,
}) {
  final evaluatedAt = now ?? DateTime.now();
  return accuracyMeters.isFinite &&
      accuracyMeters > 0 &&
      accuracyMeters <= 100 &&
      evaluatedAt.difference(capturedAt).abs() <= const Duration(minutes: 2);
}

bool isPresenceRegistrationAcknowledged(Object? value) {
  if (value is! Map || value['success'] != true) return false;
  final presence = value['presence'];
  if (presence is Map) return presence['dispatchEligible'] == true;
  return value['dispatchEligible'] == true;
}

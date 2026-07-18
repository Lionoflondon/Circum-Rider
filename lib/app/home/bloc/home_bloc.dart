import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  static const _mapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const _presenceHeartbeatInterval = Duration(seconds: 45);

  FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  final DirectionsService _directionsService = DirectionsService();
  final RiderCommunicationService _communicationService =
      RiderCommunicationService();

  List<DirectionStep> _currentRoute = [];
  int _currentStepIndex = 0;
  Timer? _presenceHeartbeatTimer;

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
    on<CheckForPushToken>(_handleCheckForPushToken);
    on<SetRideStatus>(_handleSetRideStatus);
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

  void _handleCheckForPushToken(CheckForPushToken event, Emitter emit) async {
    final User? user = auth.currentUser;
    final internalAccess = user == null
        ? false
        : (await user.getIdTokenResult()).claims?['founderRider'] == true;
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
          final remaining =
              _remainingVerificationItems(documentSnapshot.data());
          emit(state.copyWith(
              canGoOnline: internalAccess || remaining.isEmpty,
              verificationChecklist: remaining));
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

  void _handleSetRideStatus(SetRideStatus event, Emitter emit) async {
    final User? user = auth.currentUser;
    final internalAccess = user == null
        ? false
        : (await user.getIdTokenResult()).claims?['founderRider'] == true;
    if (user == null) {
      emit(state.copyWith(
          message: 'Sign in before changing Rider availability.'));
      return;
    }
    if (event.status == RideStatus.offline) {
      try {
        _stopPresenceHeartbeat();
        await FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('goOffline')
            .call();
        emit(state.copyWith(
            rideStatus: RideStatus.offline,
            message: null,
            requestStatus: RequestStatus.initial));
      } on FirebaseFunctionsException catch (error) {
        emit(state.copyWith(message: error.message ?? 'Could not go offline.'));
      }
      return;
    } else {
      final accountState = await _loadAccountState(user?.uid);
      if (!internalAccess &&
          !RiderAccountStateResolver.canOperate(accountState)) {
        emit(state.copyWith(
          rideStatus: RideStatus.offline,
          canGoOnline: false,
          message: 'Your Rider account is not approved for operational access.',
        ));
        return;
      }
      final remaining = await _loadRemainingVerificationItems(user?.uid);
      if (!internalAccess &&
          event.status == RideStatus.online &&
          remaining.isNotEmpty) {
        emit(state.copyWith(
          rideStatus: RideStatus.offline,
          canGoOnline: false,
          verificationChecklist: remaining,
          message: 'Complete your verification to start earning.',
        ));
        return;
      }
      if (event.status == RideStatus.online) {
        try {
          final locationPayload =
              await _currentPresenceLocationPayload(highAccuracy: false);
          await FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('goOnline')
              .call(locationPayload == null
                  ? null
                  : <String, dynamic>{'location': locationPayload});
          _startPresenceHeartbeat();
          emit(state.copyWith(
              rideStatus: RideStatus.online, canGoOnline: true, message: null));
          add(GetAvailableRequests());
          add(SetDrawerHeight(
              minDrawerHeight: state.minDrawerHeight,
              maxDrawerHeight: 0.75.sh));
          add(SetPanelControlStatus(status: PanelControlStatus.isOpened));
        } on FirebaseFunctionsException catch (error) {
          _stopPresenceHeartbeat();
          emit(state.copyWith(
              rideStatus: RideStatus.offline,
              message: error.message ?? 'Could not go online. Try again.'));
        } catch (_) {
          _stopPresenceHeartbeat();
          emit(state.copyWith(
              rideStatus: RideStatus.offline,
              message:
                  'Could not go online. Check your connection and retry.'));
        }
        return;
      }
    }
  }

  void _handleGetAvailableRequests(event, emit) async {
    try {
      emit(state.copyWith(
          dispatchRequests: [], requestStatus: RequestStatus.loading));
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final HttpsCallable callable =
          functions.httpsCallable('getAvailableRequests');
      final response = await callable.call();
      final dispatchRequests = (response.data['nearestRequests'] as List)
          .map((doc) => DispatchRequest.fromJson(doc))
          .toList();
      emit(state.copyWith(
          dispatchRequests: dispatchRequests,
          requestStatus: RequestStatus.success));
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
      // Obtain shared preferences.
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final documentReference = db.collection('riders').doc(user?.uid);
      // Get the document snapshot
      final documentSnapshot = await documentReference.get();

      final riderData = documentSnapshot.data();

      emit(state.copyWith(
          rideStatus: RideStatus.acceptedARide,
          selectedRequestIndex: event.selectedRequestIndex,
          activeRequest: state.dispatchRequests![event.selectedRequestIndex]));

      final double? riderLng = prefs.getDouble('longitude');
      final double? riderLat = prefs.getDouble('latitude');

      final riderCoordinates = PlaceCoordinate(lat: riderLat!, lng: riderLng!);
      final userPickupCoordinates = PlaceCoordinate(
        lat: state.dispatchRequests![event.selectedRequestIndex].pickupData
            .position.geopoint.latitude,
        lng: state.dispatchRequests![event.selectedRequestIndex].pickupData
            .position.geopoint.longitude,
      );

      final userDestinationCoordinates = PlaceCoordinate(
        lat: state.dispatchRequests![event.selectedRequestIndex].dropoffData
            .position.geopoint.latitude,
        lng: state.dispatchRequests![event.selectedRequestIndex].dropoffData
            .position.geopoint.longitude,
      );

// Create the Ployfills for the routes between the rider and the pickup locations
      add(GetPolylines(
          pickupCoordinate: riderCoordinates,
          desinationCoordinate: userPickupCoordinates));

      PolylinePoints points = PolylinePoints();

      PolylineResult startingPolylineResult =
          await points.getRouteBetweenCoordinates(
              googleApiKey: _mapsApiKey,
              request: PolylineRequest(
                origin: PointLatLng(riderLat, riderLng),
                destination: PointLatLng(
                    userPickupCoordinates.lat, userPickupCoordinates.lng),
                mode: TravelMode.driving,
              ));

      PolylineResult endingPolylineResult =
          await points.getRouteBetweenCoordinates(
              googleApiKey: _mapsApiKey,
              request: PolylineRequest(
                origin: PointLatLng(
                    userPickupCoordinates.lat, userPickupCoordinates.lng),
                destination: PointLatLng(userDestinationCoordinates.lat,
                    userDestinationCoordinates.lng),
                mode: TravelMode.driving,
              ));

      final totalTime = 120 +
          startingPolylineResult.totalDurationValue! +
          endingPolylineResult.totalDistanceValue!;

      final formattedDeliveryTime = formattedTimeAfterSeconds(totalTime);
      final riderPhone = riderData?['phone'] ?? user?.phoneNumber ?? '';
      final riderPhoto =
          '${riderData?['profileThumbnailUrl'] ?? riderData?['profilePhotoUrl'] ?? riderData?['photoURL'] ?? riderData?['photoUrl'] ?? user?.photoURL ?? ''}';

      // final userData = await firebaseMessaging
      //     .subscribeToTopic('your_topic_name')
      //         'Successfully subscribed to your_topic_name')); // Replace with your topic name
      await MessagingServer().sendMessage(
          data: {
            'type': 'connection',
            'status': 'accepted',
            'data': '''{
                'courierName': '${user?.displayName}',
                'photoURL': '$riderPhoto',
                'rating': '${riderData?['rating'] ?? '0'}',
                'plateNumber': '${riderData!['plateNumber']}',
                'typeOfVehicle': '${riderData['typeOfVehicle']}',
                'estimatedDeliveryTime': '$formattedDeliveryTime',
                'phoneNumber': '$riderPhone',
                'riderId': '${user?.uid}',
                'code': '${riderData['fcmToken']}'
              }'''
          },
          code: event.code,
          message:
              '${user?.displayName!.split(' ').first.trim()} will be picking up your parcel soon.');

      await prefs.setString('courierName', '${user?.displayName}');
      await prefs.setString('rating', '${riderData['rating']}');
      await prefs.setString('plateNumber', '${riderData['plateNumber']}');
      await prefs.setString('typeOfVehicle', '${riderData['typeOfVehicle']}');
      await prefs.setString('estimatedDeliveryTime', formattedDeliveryTime);
      await prefs.setString('phoneNumber', '$riderPhone');
      await prefs.setString('riderId', '${user?.uid}');
      await prefs.setString('code', '${riderData['fcmToken']}');
      await prefs.setString('userCode', event.code);

      // Verify that the ride was assigned to this rider

      final Completer<bool> rideAssigned = Completer();

      Timer.periodic(const Duration(seconds: 2), (timer) async {
        final requestID =
            state.dispatchRequests?[event.selectedRequestIndex].requestId;
        final docReference = db
            .collection('deliveryRequests')
            .where('requestId', isEqualTo: '$requestID');

        final docResponse = await docReference.get();
        final doc = docResponse.docs.firstOrNull;

        if (doc != null) {
          final data = doc.data();
          if (data['riderId'] != null && data['riderId'] == user!.uid) {
            // Set user as the active delivery;
            await documentReference.update(
                {'activeDelivery': doc.id, 'updatedAt': DateTime.now()});
            rideAssigned.complete(true);

            timer.cancel();
          } else if (timer.tick ==
                  15 // Automatically cancel request after 30 sec
              ) {
            rideAssigned.complete(false);
            timer.cancel();
          }
        } else {
          rideAssigned.complete(false);
          timer.cancel();
        }
      });

      final rideAssignedResult = await rideAssigned.future;
      // The ride was not assigned to this rider in 30s
      if (rideAssignedResult == false) {
        emit(state.copyWith(
          rideStatus: RideStatus.online,
        ));
        add(CancelRequest());
      }
      if (rideAssignedResult == true) {
        await prefs.setString('activeRequest',
            state.dispatchRequests[event.selectedRequestIndex].requestId);
        emit(state.copyWith(
            rideStatus: RideStatus.userConfirmedRide,
            activeRequest: state.dispatchRequests?[event.selectedRequestIndex],
            actionButtonStatus: ActionButtonStatus.goingToPickupLocation));

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
      SetSourceAndDestinationStatus event, Emitter emit) {
    emit(state.copyWith(sourceAndDestinationStatus: event.status));
  }

  void _handleSetMapCameraStatus(SetMapCameraStatus event, Emitter emit) {
    emit(state.copyWith(mapCameraStatus: event.status));
  }

  void _handleSetDrawerHeight(SetDrawerHeight event, Emitter emit) {
    emit(state.copyWith(
        minDrawerHeight: event.minDrawerHeight,
        maxDrawerHeight: event.maxDrawerHeight));
  }

  void _handleSetPanelControlStatus(SetPanelControlStatus event, Emitter emit) {
    emit(state.copyWith(panelControlStatus: event.status));
  }

  void _handleGetPolylines(GetPolylines event, Emitter emit) async {
    _currentRoute = await _directionsService.getDetailedDirections(
        LatLng(event.pickupCoordinate.lat, event.pickupCoordinate.lng),
        LatLng(event.desinationCoordinate.lat, event.desinationCoordinate.lng));

    if (_currentRoute.isNotEmpty) {
      // Create a more detailed list of points by breaking down each route step
      List<LatLng> routePoints = _currentRoute
          .expand((step) => step.polylinePoints.isNotEmpty
              ? step.polylinePoints
              : [step.startLocation, step.endLocation])
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
        position:
            LatLng(event.pickupCoordinate.lat, event.pickupCoordinate.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
      );

      final Marker destinationMarker = Marker(
        markerId: const MarkerId('destination_marker'),
        position: LatLng(
            event.desinationCoordinate.lat, event.desinationCoordinate.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        ),
      );

      Map<MarkerId, Marker> markers = {
        const MarkerId('source_marker'): sourceMarker,
        const MarkerId('destination_marker'): destinationMarker
      };

      emit(state.copyWith(
        polylines: polyLines,
        markers: markers,
      ));

      add(SetSourceAndDestinationStatus(
          status: SourceAndDestinationStatus.selected));
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
    emit(state.copyWith(
        polylines: polylines,
        markers: markers,
        polylineCoordinates: [],
        dispatchRequests: []));
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
                "assets/svg/bike_top.svg");
        final Marker riderLocationMarker = Marker(
            markerId: MarkerId('rider_location_marker'),
            position:
                LatLng(riderLat!, riderLng!), // Destination address location
            icon: icon);

        Map<MarkerId, Marker> markers = Map.of(state.markers);

        markers[MarkerId('rider_location_marker')] = riderLocationMarker;

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
              }'''
            },
            code: state.activeRequest!.code,
            message: "Broadcasting rider's location");
        await Future.delayed(const Duration(seconds: 5));
        emit(state.copyWith(broadcastStatus: BroadcastStatus.initialized));
      }
    } catch (e) {
      emit(state.copyWith(broadcastStatus: BroadcastStatus.initialized));
    }
  }

  void _handleCheckForActiveRequest(
      CheckForActiveRequest event, Emitter emit) async {
    User? user = auth.currentUser;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? activeRequest = prefs.getString('activeRequest');
    final double? riderLng = prefs.getDouble('longitude');
    final double? riderLat = prefs.getDouble('latitude');
    final String? riderId = prefs.getString('riderId');
    String? statusString = prefs.getString('status');
    RideStatus? status;
    if (statusString == 'online') {
      status = RideStatus.online;
      add(SetRideStatus(status: RideStatus.online));
      add(GetAvailableRequests());
      add(SetDrawerHeight(
          minDrawerHeight: state.minDrawerHeight, maxDrawerHeight: 0.75.sh));
      add(SetPanelControlStatus(status: PanelControlStatus.isOpened));
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

      if (data['status'] == 'accepted') {
        status = RideStatus.userConfirmedRide;
        pickupCoordinates = PlaceCoordinate(lat: riderLat!, lng: riderLng!);
        desinationCoordinate = PlaceCoordinate(
            lat: activeRequest.pickupData.position.geopoint.latitude,
            lng: activeRequest.pickupData.position.geopoint.longitude);
        add(GetPolylines(
            desinationCoordinate: desinationCoordinate,
            pickupCoordinate: pickupCoordinates));
        emit(state.copyWith(
            actionButtonStatus: ActionButtonStatus.goingToPickupLocation));
      }

      if (data['status'] == 'outForDelivery') {
        status = RideStatus.outForDelivery;
        pickupCoordinates = PlaceCoordinate(
            lat: activeRequest.pickupData.position.geopoint.latitude,
            lng: activeRequest.pickupData.position.geopoint.longitude);
        desinationCoordinate = PlaceCoordinate(
            lat: activeRequest.dropoffData.position.geopoint.latitude,
            lng: activeRequest.dropoffData.position.geopoint.longitude);
        add(GetPolylines(
            desinationCoordinate: desinationCoordinate,
            pickupCoordinate: pickupCoordinates));
        emit(state.copyWith(
            actionButtonStatus: ActionButtonStatus.outForDelivery));
      }

      add(SetRideStatus(status: status ?? RideStatus.offline));

      emit(state.copyWith(rideStatus: status));

      if (data['status'] != 'confirmed') {
        emit(state.copyWith(
          activeRequest: activeRequest,
        ));
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

    emit(state.copyWith(
        chatMessages: chatMessages, chatStatus: ChatStatus.newMessage));
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
    if (auth.currentUser == null || state.rideStatus != RideStatus.online) {
      _stopPresenceHeartbeat();
      return;
    }
    try {
      final locationPayload =
          await _currentPresenceLocationPayload(highAccuracy: false);
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('updateRiderPresence')
          .call(locationPayload == null
              ? <String, dynamic>{}
              : <String, dynamic>{'location': locationPayload});
    } catch (_) {
      // Dispatch excludes stale riders until heartbeats recover.
    }
  }

  Future<Map<String, dynamic>?> _currentPresenceLocationPayload({
    required bool highAccuracy,
  }) async {
    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) return null;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
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
    } catch (_) {
      return null;
    }
  }

  String _gpsSignalQuality(double accuracyMeters) {
    if (accuracyMeters <= 25) return 'high';
    if (accuracyMeters <= 80) return 'medium';
    return 'reduced';
  }

  @override
  Future<void> close() {
    _stopPresenceHeartbeat();
    return super.close();
  }

  void _handleSetNewMessage(SetNewMessage event, Emitter emit) {
    emit(state.copyWith(message: event.value));
  }

  void _handleLoadChatMessages(LoadChatMessages event, Emitter emit) async {
    final directory = await getApplicationDocumentsDirectory();
    final chats =
        File('${directory.path}/${state.activeRequest!.requestId}.json');

    if (await chats.exists()) {
      final contents = await chats.readAsString();
      final jsonData = await jsonDecode(contents) as List;

      final messagesList = jsonData.map((e) => Message.fromJson(e)).toList();
      emit(state.copyWith(
          chatMessages: messagesList, chatStatus: ChatStatus.newMessage));
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
        'timeStamp': '${DateTime.now()}'
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

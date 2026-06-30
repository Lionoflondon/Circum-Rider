import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
// import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../helper/bitmap_descriptor_helper.dart';
import '../../../helper/chats_help.dart';
import '../../../helper/formatted_string_after_seconds.dart';
import '../../../helper/messaging_server.dart';
import '../../../utils/theme/theme.dart';
import '../models/dispatch_request.m..dart';
import '../models/message.m.dart';
import '../models/place_coordinates.m.dart';
import '../repo/direction_service.dart';
import '../repo/home_repo.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  FirebaseAuth auth = FirebaseAuth.instance;
  // Init firestore and geoFlutterFire
  // final geo = GeoFlutterFire();
  FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  final DirectionsService _directionsService = DirectionsService();

  List<DirectionStep> _currentRoute = [];
  int _currentStepIndex = 0;

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
    on<ArrivedAtPickUpLocation>(_handleArrivedAtPickUpLocation);
    on<StartDelivery>(_handleStartDelivery);
    on<RideCompleted>(_handleRideCompleted);
    on<CancelRequest>(_handlerCancelRequest);
    on<BroadcastLocation>(_handleBroadcastLocation);
    on<CheckForActiveRequest>(_handleCheckForActiveRequest);
    on<IncomingMessage>(_handleIncomingMessage);
    on<SetNewMessage>(_handleSetNewMessage);
    on<LoadChatMessages>(_handleLoadChatMessages);
    on<MessageUser>(_handleMessageUser);
    on<RateUser>(_handleRateUser);
  }

  void _handleCheckForPushToken(CheckForPushToken event, Emitter emit) async {
    // if (Firebase.apps.isEmpty) print('Firebase not initialized');
    // if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    final User? user = auth.currentUser;
    if (!kIsWeb && Platform.isIOS) {
      await firebaseMessaging.requestPermission();
    }
    final apnsToken = !kIsWeb && Platform.isIOS
        ? await firebaseMessaging.getAPNSToken()
        : null;
    print('apnsToken: $apnsToken');
    final fcmToken = await firebaseMessaging.getToken();
    if (fcmToken != null) {
      try {
        final documentReference = db.collection('riders').doc(user?.uid);

        // Get the document snapshot
        final documentSnapshot = await documentReference.get();
        if (documentSnapshot.exists) {
          print('FCMToken: $fcmToken');
          final remaining =
              _remainingVerificationItems(documentSnapshot.data());
          emit(state.copyWith(
              canGoOnline: remaining.isEmpty,
              verificationChecklist: remaining));
          await db
              .collection("riders")
              .doc(user?.uid)
              .update({'fcmToken': fcmToken, 'updatedAt': DateTime.now()}).then(
                  (value) => print("DocumentSnapshot successfully updated!"),
                  onError: (e) => print("Error updating document $e"));
        }
      } catch (e) {
        print('Push Token update error');
        print(e);
      }
    } else {
      print('fcmToken Is null');
      print('apnsToken: $apnsToken');
    }
  }

  void _handleSetRideStatus(SetRideStatus event, Emitter emit) async {
    final User? user = auth.currentUser;
    final pref = await SharedPreferences.getInstance();
    if (event.status == RideStatus.offline) {
      // print('isOffline');
      add(SetDrawerHeight(
          minDrawerHeight: state.minDrawerHeight,
          maxDrawerHeight: state.minDrawerHeight));
      add(SetPanelControlStatus(status: PanelControlStatus.isClosed));

      await db
          .collection("riders")
          .doc(user?.uid)
          .update({'status': 'offline'}).then((value) => print("Offline"),
              onError: (e) => print("Error updating document $e"));

      await pref.setString('status', 'offline');
    } else {
      final remaining = await _loadRemainingVerificationItems(user?.uid);
      if (event.status == RideStatus.online && remaining.isNotEmpty) {
        emit(state.copyWith(
          rideStatus: RideStatus.offline,
          canGoOnline: false,
          verificationChecklist: remaining,
          message: 'Complete your verification to start earning.',
        ));
        return;
      }
      add(GetAvailableRequests());
      add(SetDrawerHeight(
          minDrawerHeight: state.minDrawerHeight, maxDrawerHeight: 0.75.sh));
      add(SetPanelControlStatus(status: PanelControlStatus.isOpened));

      if (event.status == RideStatus.online) {
        emit(state.copyWith(rideStatus: event.status));
        await db
            .collection("riders")
            .doc(user?.uid)
            .update({'status': 'online'}).then((value) => print("online"),
                onError: (e) => print("Error updating document $e"));

        await pref.setString('status', 'online');
      }
    }
    emit(state.copyWith(rideStatus: event.status));
  }

  void _handleGetAvailableRequests(event, emit) async {
    try {
      emit(state.copyWith(
          dispatchRequests: [], requestStatus: RequestStatus.loading));
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final HttpsCallable callable =
          functions.httpsCallable('getAvaliableRequests');
      final response = await callable.call();
      final dispatchRequests = (response.data['nearestRequests'] as List)
          .map((doc) => DispatchRequest.fromJson(doc))
          .toList();
      emit(state.copyWith(
          dispatchRequests: dispatchRequests,
          requestStatus: RequestStatus.success));
    } catch (e) {
      print('failure');
      print(e);
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

      // print('riderData: $riderData');

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
              googleApiKey: 'AIzaSyDWH0L6pjdf2W_ZZrjfv6z5OvMZQ2TVNMI',
              request: PolylineRequest(
                origin: PointLatLng(riderLat, riderLng),
                destination: PointLatLng(
                    userPickupCoordinates.lat, userPickupCoordinates.lng),
                mode: TravelMode.driving,
              ));

      PolylineResult endingPolylineResult =
          await points.getRouteBetweenCoordinates(
              googleApiKey: 'AIzaSyDWH0L6pjdf2W_ZZrjfv6z5OvMZQ2TVNMI',
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

      // print(startingPolylineResult.durationValue);
      // print(startingPolylineResult.duration);
      // print(endingPolylineResult.durationValue);
      // print(endingPolylineResult.duration);

      final formattedDeliveryTime = formattedTimeAfterSeconds(totalTime);
      final riderPhone = riderData?['phone'] ?? user?.phoneNumber ?? '';

      // final userData = await firebaseMessaging
      //     .subscribeToTopic('your_topic_name')
      //     .then((value) => print(
      //         'Successfully subscribed to your_topic_name')); // Replace with your topic name
      await MessagingServer().sendMessage(
          data: {
            'type': 'connection',
            'status': 'accepted',
            'data': '''{
                'courierName': '${user?.displayName}',
                'photoURL': '${user?.photoURL}',
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
        print('Doc length: ${docResponse.docs.length}');
        final doc = docResponse.docs.firstOrNull;

        if (doc != null) {
          final data = doc.data();
          if (data['riderId'] != null && data['riderId'] == user!.uid) {
            // print('Ride assigned to me 🎉');
            // print(timer.tick);

            print('Document ID: ${doc.id}');

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
    } catch (e) {
      print(e);
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

  void _handleArrivedAtPickUpLocation(
      ArrivedAtPickUpLocation event, Emitter emit) async {
    emit(state.copyWith(
        actionButtonStatus: ActionButtonStatus.arrivedPickupLocation));
  }

  void _handleStartDelivery(StartDelivery event, Emitter emit) async {
    try {
      emit(state.copyWith(requestStatus: RequestStatus.loading));
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? activeRequest = prefs.getString('activeRequest');
      final documentReference = db
          .collection('deliveryRequests')
          .where('requestId', isEqualTo: activeRequest);

      final docResponse = await documentReference.get();
      // print('Doc length: ${docResponse.docs.length}');
      final doc = docResponse.docs.firstOrNull;
      if (doc != null) {
        // await doc.data().update('status', (value) => 'outForDelivery');

        await db
            .collection('deliveryRequests')
            .doc(doc.id)
            .update({'status': 'outForDelivery', 'updatedAt': DateTime.now()});

        final newRideData = doc.data();
        newRideData['status'] = 'outForDelivery';

        final activeRide = DispatchRequest.fromJson(newRideData);
        PlaceCoordinate pickupCoordinates = PlaceCoordinate(
            lat: activeRide.pickupData.position.geopoint.latitude,
            lng: activeRide.pickupData.position.geopoint.longitude);
        PlaceCoordinate desinationCoordinate = PlaceCoordinate(
            lat: activeRide.dropoffData.position.geopoint.latitude,
            lng: activeRide.dropoffData.position.geopoint.longitude);
        add(GetPolylines(
            desinationCoordinate: desinationCoordinate,
            pickupCoordinate: pickupCoordinates));
        emit(state.copyWith(
            activeRequest: activeRide,
            actionButtonStatus: ActionButtonStatus.outForDelivery,
            rideStatus: RideStatus.outForDelivery,
            requestStatus: RequestStatus.success));
      }
    } catch (e) {
      print(e);
      emit(state.copyWith(requestStatus: RequestStatus.failure));
    }
  }

  void _handleRideCompleted(RideCompleted event, Emitter emit) async {
    try {
      emit(state.copyWith(requestStatus: RequestStatus.loading));
      final uuid1 = const Uuid().v4();
      final uuid2 = const Uuid().v4();
      final uuiduuid = '$uuid1$uuid2';
      final User user = auth.currentUser!;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? activeRequest = prefs.getString('activeRequest');
      final code = prefs.getString('code');
      final String? riderId = prefs.getString('riderId');

      final historyId = await HomeRepo().endTrip(
          riderId: riderId!,
          requestId: activeRequest!,
          riderName: user.displayName!);

      await prefs.setString('lastTrip', historyId);

      await MessagingServer().sendMessage(data: {
        'type': 'delivery-completed',
        'data': '''{
                    'riderId': '$riderId',
                    'code': '$code',
                    'historyId': '$historyId'
                  }'''
      }, code: state.activeRequest!.code, message: "Delivery completed");

      add(CancelRequest());

      emit(state.copyWith(
        actionButtonStatus: ActionButtonStatus.initialized,
        rideStatus: RideStatus.delivered,
        requestStatus: RequestStatus.success,
        dispatchRequests: [],
      ));

      add(GetAvailableRequests());
    } catch (e) {
      print(e);
      emit(state.copyWith(requestStatus: RequestStatus.failure));
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

    print('>>>>>>>>>>>>>>>>>>>>>');
    print('Cancelled Data');
    print('>>>>>>>>>>>>>>>>>>>>>');
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

        print('code: ${state.activeRequest!.code}');
        // final SharedPreferences prefs = await SharedPreferences.getInstance();
        final courierName = prefs.getString('courierName');
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
                'photoURL': '${auth.currentUser?.photoURL}',
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
      print(e);
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
      print('online-online');
      status = RideStatus.online;
      add(SetRideStatus(status: RideStatus.online));
      add(GetAvailableRequests());
      add(SetDrawerHeight(
          minDrawerHeight: state.minDrawerHeight, maxDrawerHeight: 0.75.sh));
      add(SetPanelControlStatus(status: PanelControlStatus.isOpened));
    }
    print('Checking for active requests');
    print('activeRequest: $activeRequest');

    final documentReference = db
        .collection('deliveryRequests')
        .where('riderId', isEqualTo: user!.uid);

    final docResponse = await documentReference.get();
    print('Doc length: ${docResponse.docs.length}');
    // final doc = docResponse.docs.firstOrNull;

    for (final doc in docResponse.docs) {
      final data = doc.data();
      print(data);
      print('There is an active ride assigned to me 🎉');
      final activeRequest = DispatchRequest.fromJson(data);
      // print('code: ${activeRequest.code}');
      // print('currency: ${activeRequest.currency}');
      // print('requestId: ${activeRequest.requestId}');

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

      print('RideStatus: $status');
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
      print('No active ride');
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

  void _handleSetNewMessage(SetNewMessage event, Emitter emit) {
    emit(state.copyWith(message: event.value));
  }

  void _handleLoadChatMessages(LoadChatMessages event, Emitter emit) async {
    final directory = await getApplicationDocumentsDirectory();
    final chats =
        File('${directory.path}/${state.activeRequest!.requestId}.json');

    if (await chats.exists()) {
      print('Loading chats');
      final contents = await chats.readAsString();
      // print(contents);
      final jsonData = await jsonDecode(contents) as List;

      final messagesList = jsonData.map((e) => Message.fromJson(e)).toList();
      emit(state.copyWith(
          chatMessages: messagesList, chatStatus: ChatStatus.newMessage));
    }
  }

  void _handleMessageUser(MessageUser event, Emitter emit) async {
    try {
      print('Sending messsage ');
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

      await MessagingServer().sendMessage(data: {
        "type": "message",
        "data": """{
                "requestId": "${state.activeRequest!.requestId}",
                "senderId": "${user.uid}",
                "message": "${event.message}",
                "timeStamp": "${DateTime.now()}"
              }"""
      }, code: state.activeRequest!.code, message: '');

      add(IncomingMessage(data: messageData));

      ChatsHelper().storeChat(messageData);
    } catch (e) {
      print('Sending messsage failed');
      print(e);
    }
  }

  void _handleRateUser(RateUser event, Emitter emit) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? lastTrip = prefs.getString('lastTrip');
      await db
          .collection('history')
          .doc(lastTrip)
          .update({'userRating': event.rating, 'updatedAt': DateTime.now()});
    } catch (e) {
      print(e);
    }
  }
}

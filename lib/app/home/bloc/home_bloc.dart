import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helper/messaging_server.dart';
import '../../../utils/theme/theme.dart';
import '../models/dispatch_request.m..dart';
import '../models/place_coordinates.m.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeState()) {
    FirebaseAuth auth = FirebaseAuth.instance;
    // Init firestore and geoFlutterFire
    final geo = GeoFlutterFire();
    FirebaseFirestore db = FirebaseFirestore.instance;
    final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

    on<HomeEvent>((event, emit) {
      // TODO: implement event handler
    });

    on<CheckForPushToken>(
      (event, emit) async {
        // if (Firebase.apps.isEmpty) print('Firebase not initialized');
        // if (Firebase.apps.isEmpty) await Firebase.initializeApp();
        if (Platform.isIOS) {
          await firebaseMessaging.requestPermission();
        }
        final apnsToken = await firebaseMessaging.getAPNSToken();
        print('apnsToken: $apnsToken');
        final fcmToken = await firebaseMessaging.getToken();
        if (fcmToken != null) {
          try {
            final User? user = auth.currentUser;

            final documentReference = db.collection('riders').doc(user?.uid);

            // Get the document snapshot
            final documentSnapshot = await documentReference.get();
            if (documentSnapshot.exists) {
              print('FCMToken: $fcmToken');
              await db.collection("riders").doc(user?.uid).update({
                'fcmToken': fcmToken,
              }).then(
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
      },
    );

    on<SetRideStatus>(
      (event, emit) {
        if (event.status == RideStatus.offline) {
          // print('isOffline');
          add(SetDrawerHeight(
              minDrawerHeight: state.minDrawerHeight,
              maxDrawerHeight: state.minDrawerHeight));
          add(SetPanelControlStatus(status: PanelControlStatus.isClosed));
        } else {
          add(GetAvailableRequests());
          add(SetDrawerHeight(
              minDrawerHeight: state.minDrawerHeight,
              maxDrawerHeight: 0.75.sh));

          add(SetPanelControlStatus(status: PanelControlStatus.isOpened));
        }
        emit(state.copyWith(rideStatus: event.status));
      },
    );

    on<GetAvailableRequests>(
      (event, emit) async {
        try {
          final User? user = auth.currentUser;
          //  await db.collection("deliveryRequests").get()
          // Create a geoFirePoint (The location of the rider)

          // final coordinates = new Coordinates(
          //     state.locationData!.latitude, state.locationData!.longitude);
          var address = await placemarkFromCoordinates(
              state.locationData!.latitude, state.locationData!.longitude);
          print(address[0].locality);

          GeoFirePoint center = geo.point(
              latitude: state.locationData!.latitude,
              longitude: state.locationData!.longitude);

          // get the collection reference or query
          var collectionReference = db
              .collection('deliveryRequests')
              .where('pickupLocality', isEqualTo: '${address[0].locality}');
          // radius in km
          double radius = 50;
          String field = 'pickupPosition';

          Stream<List<DocumentSnapshot>> stream = geo
              .collection(collectionRef: collectionReference)
              .within(
                  center: center,
                  radius: radius,
                  field: field,
                  strictMode: true);

          Completer<List<DispatchRequest>> _completer = Completer();

          final docStream = stream.listen(
            (
              List<DocumentSnapshot> documentList,
            ) {
              final dispatchRequests = documentList
                  .map((doc) => DispatchRequest.fromJson(doc.data()))
                  .toList();

              _completer.complete(dispatchRequests);
              print('completed');
            },
          );
          final _dispatchRequests = await _completer.future;
          docStream.cancel();
          emit(state.copyWith(dispatchRequests: _dispatchRequests));
          // Stop Stream
          // stream
          // print(state.dispatchRequests);

          // print(stream);
        } catch (e) {}
      },
    );

    on<SetHomeLocationData>((event, emit) {
      emit(state.copyWith(locationData: event.locationData));
    });

    on<AcceptRide>(
      (event, emit) async {
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
            activeRequest:
                state.dispatchRequests![event.selectedRequestIndex]));

        final double? riderLng = prefs.getDouble('longitude');
        final double? riderLat = prefs.getDouble('latitude');

        final riderCoordinates =
            PlaceCoordinate(lat: riderLat!, lng: riderLng!);
        final userPickupCoordinates = PlaceCoordinate(
          lat: state.dispatchRequests![event.selectedRequestIndex].pickupData
              .position.geopoint.latitude,
          lng: state.dispatchRequests![event.selectedRequestIndex].pickupData
              .position.geopoint.longitude,
        );

// Create the Ployfills for the routes between the rider and the pickup locations
        add(GetPolylines(
            pickupCoordinate: riderCoordinates,
            desinationCoordinate: userPickupCoordinates));

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
                'rating': '${riderData!['rating']}',
                'plateNumber': '${riderData['plateNumber']}',
                'typeOfVehicle': '${riderData['typeOfVehicle']}',
                'estimatedDeliveryTime': '2min',
                'phoneNumber': '${user?.phoneNumber}',
                'riderId': '${user?.uid}',
                'code': '${riderData['fcmToken']}'
              }'''
            },
            code: event.code,
            message:
                '${user?.displayName!.split(' ').first.trim()} will be picking up your parcel soon.');

        // Verify that the ride was assigned to this rider

        final Completer<bool> rideAssigned = Completer();

        Timer.periodic(const Duration(seconds: 2), (timer) async {
          final requestID =
              state.dispatchRequests?[event.selectedRequestIndex].requestId;
          final documentReference = db
              .collection('deliveryRequests')
              .where('requestId', isEqualTo: '$requestID');

          final docResponse = await documentReference.get();
          print('Doc length: ${docResponse.docs.length}');
          docResponse.docs.map((i) {
            final data = i.data();
            if (data['riderId'] != null && data['riderId'] == user!.uid) {
              print('Ride assigned to me 🎉');
              print(timer.tick);
              rideAssigned.complete(true);

              timer.cancel();
            } else if (timer.tick ==
                    15 // Automatically cancel request after 30 sec
                ) {
              rideAssigned.complete(false);
              timer.cancel();
            }
            // count++;
          }).toList();

          if (docResponse.docs.length < 1) {
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
              state.dispatchRequests![event.selectedRequestIndex].requestId);
          emit(state.copyWith(
              rideStatus: RideStatus.userConfirmedRide,
              activeRequest:
                  state.dispatchRequests?[event.selectedRequestIndex]));

          add(BroadcastLocation());
        }
      },
    );

    on<SetSourceAndDestinationStatus>(
      (event, emit) {
        emit(state.copyWith(sourceAndDestinationStatus: event.status));
      },
    );

    on<SetMapCameraStatus>(
      (event, emit) {
        emit(state.copyWith(mapCameraStatus: event.status));
      },
    );

    on<SetDrawerHeight>((event, emit) {
      emit(state.copyWith(
          minDrawerHeight: event.minDrawerHeight,
          maxDrawerHeight: event.maxDrawerHeight));
    });

    on<SetPanelControlStatus>(
      (event, emit) => emit(state.copyWith(panelControlStatus: event.status)),
    );

    on<GetPolylines>(
      (event, emit) async {
        List<LatLng> latLngList = [];

        PolylinePoints points = PolylinePoints();

        PolylineResult polylineResult = await points.getRouteBetweenCoordinates(
          'AIzaSyDWH0L6pjdf2W_ZZrjfv6z5OvMZQ2TVNMI',
          PointLatLng(event.pickupCoordinate.lat, event.pickupCoordinate.lng),
          PointLatLng(
              event.desinationCoordinate.lat, event.desinationCoordinate.lng),
          travelMode: TravelMode.driving,
        );

        if (polylineResult.points.isNotEmpty) {
          double tripDistance;
          tripDistance =
              double.parse(polylineResult.distance!.split(' ').first.trim());
          // print(polylineResult.distance);
          // print(polylineResult.distanceText);
          // print(polylineResult.distanceValue);
          polylineResult.points.forEach((ele) {
            latLngList.add(LatLng(ele.latitude, ele.longitude));
          });

          List<Polyline> polyLines = [];
          polyLines.add(Polyline(
              polylineId: const PolylineId('PolylineId'),
              points: latLngList,
              width: 3,
              color: AppColors.primary));

          final Marker sourceMarker = Marker(
            markerId: const MarkerId('source_marker'),
            position: LatLng(event.pickupCoordinate.lat,
                event.pickupCoordinate.lng), // Source address location
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          );

          final Marker destinationMarker = Marker(
            markerId: const MarkerId('destination_marker'),
            position: LatLng(event.desinationCoordinate.lat,
                event.desinationCoordinate.lng), // Destination address location
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          );

          Map<MarkerId, Marker> markers = {
            const MarkerId('source_marker'): sourceMarker,
            const MarkerId('destination_marker'): destinationMarker
          };

          emit(state.copyWith(
            polylines: polyLines, markers: markers, // distance: tripDistance
          ));

          add(SetSourceAndDestinationStatus(
              status: SourceAndDestinationStatus.selected));
        }
      },
    );

    on<CancelRequest>(
      (event, emit) {
        List<Polyline> polylines = [];
        Map<MarkerId, Marker> markers = {};
        emit(state.copyWith(polylines: polylines, markers: markers));
      },
    );

    on<BroadcastLocation>(
      (event, emit) async {
        Timer.periodic(const Duration(seconds: 5), (timer) async {
          try {
            final SharedPreferences prefs =
                await SharedPreferences.getInstance();
            final double? riderLng = prefs.getDouble('longitude');
            final double? riderLat = prefs.getDouble('latitude');
            final String? riderId = prefs.getString('riderId');
            if (state.activeRequest != null &&
                (state.rideStatus == RideStatus.userConfirmedRide ||
                    state.rideStatus == RideStatus.outForDelivery)) {
              print('code: ${state.activeRequest!.code}');
              await MessagingServer().sendMessage(
                  data: {
                    'type': 'location-broadcast',
                    'data': '''{
                'riderId': '$riderId',
                'latitude': '$riderLat',
                'longitude': '$riderLng',
              }'''
                  },
                  code: state.activeRequest!.code,
                  message: "Broadcasting rider's location");
            } else {
              timer.cancel();
            }
          } catch (e) {
            print(e);
            timer.cancel();
          }
        });
      },
    );

    on<CheckForActiveRequest>(
      (event, emit) async {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String? activeRequest = prefs.getString('activeRequest');
        final double? riderLng = prefs.getDouble('longitude');
        final double? riderLat = prefs.getDouble('latitude');
        final String? riderId = prefs.getString('riderId');
        if (activeRequest != null) {
          final documentReference = db
              .collection('deliveryRequests')
              .where('requestId', isEqualTo: activeRequest);

          final docResponse = await documentReference.get();
          print('Doc length: ${docResponse.docs.length}');
          final doc = docResponse.docs.firstOrNull;
          if (doc != null) {
            print('There is an active ride');
            final data = doc.data();
            print(data);
            if (data['riderId'] != null && data['riderId'] == riderId) {
              print('Ride assigned to me 🎉');
              final activeRequest = DispatchRequest.fromJson(data);
              print('code: ${activeRequest.code}');
              print('currency: ${activeRequest.currency}');
              print('requestId: ${activeRequest.requestId}');

              PlaceCoordinate pickupCoordinates;
              PlaceCoordinate desinationCoordinate;

              RideStatus? status;
              if (data['status'] == 'accepted') {
                status = RideStatus.userConfirmedRide;
                pickupCoordinates =
                    PlaceCoordinate(lat: riderLat!, lng: riderLng!);
                desinationCoordinate = PlaceCoordinate(
                    lat: activeRequest.pickupData.position.geopoint.latitude,
                    lng: activeRequest.pickupData.position.geopoint.longitude);
                add(GetPolylines(
                    desinationCoordinate: desinationCoordinate,
                    pickupCoordinate: pickupCoordinates));
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
              }

              print('RideStatus: $status');
              add(SetRideStatus(status: status ?? RideStatus.offline));

              emit(state.copyWith(
                  activeRequest: activeRequest, rideStatus: status));

              add(BroadcastLocation());
            }
          }
        } else {
          print('There is no active ride 🏍️');
        }
      },
    );

    // Function to send a notification message
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:geolocator/geolocator.dart';

import '../../../helper/messaging_server.dart';
import '../models/dispatch_request.m..dart';

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
        final fcmToken = await FirebaseMessaging.instance.getToken();
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
        }
      },
    );

    on<SetOnlinePresence>(
      (event, emit) {
        if (event.isOffline == false) {
          add(GetAvailableRequests());
        }
        emit(state.copyWith(isOffline: event.isOffline));
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

          stream.listen((List<DocumentSnapshot> documentList) {
            final dispatchRequests = documentList
                .map((doc) => DispatchRequest.fromJson(doc.data()))
                .toList();

            _completer.complete(dispatchRequests);
          });
          final _dispatchRequests = await _completer.future;
          emit(state.copyWith(dispatchRequests: _dispatchRequests));
          print(state.dispatchRequests);

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

        final documentReference = db.collection('riders').doc(user?.uid);
        // Get the document snapshot
        final documentSnapshot = await documentReference.get();

        final riderData = documentSnapshot.data();

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
                'riderId': '${user?.uid}'
                'code': '${riderData['fcmToken']}'
              }'''
            },
            code: event.code,
            message:
                '${user?.displayName!.split(' ').first.trim()} will be picking up your parcel soon.');
      },
    );

    // Function to send a notification message
  }
}

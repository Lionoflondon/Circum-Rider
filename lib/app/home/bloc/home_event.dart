part of 'home_bloc.dart';

abstract class HomeEvent {
  HomeEvent();
}

class SetRideStatus extends HomeEvent {
  final RideStatus status;

  SetRideStatus({required this.status});
}

class GetAvailableRequests extends HomeEvent {}

class SetHomeLocationData extends HomeEvent {
  final Position locationData;

  SetHomeLocationData({required this.locationData});
}

class CheckForPushToken extends HomeEvent {}

class AcceptRide extends HomeEvent {
  final String topic;
  final String code;
  final int selectedRequestIndex;
  AcceptRide(
      {required this.topic,
      required this.code,
      required this.selectedRequestIndex});
}

class SetSourceAndDestinationStatus extends HomeEvent {
  final SourceAndDestinationStatus status;
  SetSourceAndDestinationStatus({required this.status});
}

class SetMapCameraStatus extends HomeEvent {
  final MapCameraStatus status;
  SetMapCameraStatus({required this.status});
}

class SetDrawerHeight extends HomeEvent {
  final double minDrawerHeight;
  final double maxDrawerHeight;
  SetDrawerHeight(
      {required this.minDrawerHeight, required this.maxDrawerHeight});
}

class SetPanelControlStatus extends HomeEvent {
  final PanelControlStatus status;
  SetPanelControlStatus({required this.status});
}

class CancelRequest extends HomeEvent {
  final String? requestId;
  CancelRequest({this.requestId});
}

class GetPolylines extends HomeEvent {
  final PlaceCoordinate pickupCoordinate;
  final PlaceCoordinate desinationCoordinate;
  GetPolylines(
      {required this.pickupCoordinate, required this.desinationCoordinate});
}

class BroadcastLocation extends HomeEvent {}

class CheckForActiveRequest extends HomeEvent {}

class ArrivedAtPickUpLocation extends HomeEvent {}

class StartDelivery extends HomeEvent {}

class RideCompleted extends HomeEvent {}

class SetNewMessage extends HomeEvent {
  final String value;
  SetNewMessage({required this.value});
}

class IncomingMessage extends HomeEvent {
  final dynamic data;

  IncomingMessage({required this.data});
}

class LoadChatMessages extends HomeEvent {}

class MessageUser extends HomeEvent {
  final String message;
  MessageUser({required this.message});
}

class RateUser extends HomeEvent {
  final double rating;

  RateUser({required this.rating});
}

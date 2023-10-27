part of 'home_bloc.dart';

abstract class HomeEvent {
  HomeEvent();
}

class SetOnlinePresence extends HomeEvent {
  final bool isOffline;

  SetOnlinePresence({required this.isOffline});
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
  AcceptRide({required this.topic, required this.code});
}

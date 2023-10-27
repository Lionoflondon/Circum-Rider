part of 'home_bloc.dart';

class HomeState {
  final List ongoingRequests;
  bool isOffline;
  final Position? locationData;
  List<DispatchRequest>? dispatchRequests;

  HomeState(
      {this.ongoingRequests = const [],
      this.isOffline = true,
      this.locationData,
      this.dispatchRequests});

  HomeState copyWith(
      {List? ongoingRequests,
      bool? isOffline,
      Position? locationData,
      List<DispatchRequest>? dispatchRequests}) {
    return HomeState(
        ongoingRequests: ongoingRequests ?? this.ongoingRequests,
        isOffline: isOffline ?? this.isOffline,
        locationData: locationData ?? this.locationData,
        dispatchRequests: dispatchRequests ?? this.dispatchRequests);
  }
}

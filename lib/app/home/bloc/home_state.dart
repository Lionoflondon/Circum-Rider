part of 'home_bloc.dart';

// default MapCameraStatus is initial, lat 0, lng 0
enum MapCameraStatus {
  initialized,
  showingDeviceLocation,
  showingSourceAndDestinationLocations
}

enum SourceAndDestinationStatus { unselected, selected }

enum RideStatus {
  offline,
  online,
  acceptedARide,
  userConfirmedRide,
  arrivedAtPickupLocation,
  outForDelivery,
  delivered
}

enum PanelControlStatus { initialized, isOpened, isClosed }

enum BroadcastStatus { initialized, broadcasting }

enum RequestStatus { initial, loading, success, failure }

enum ChatStatus { initial, newMessage }

enum ActionButtonStatus {
  initialized,
  goingToPickupLocation,
  arrivedPickupLocation,
  outForDelivery,
  delivered
}

class HomeState {
  final List ongoingRequests;
  RideStatus rideStatus;
  final Position? locationData;
  List<DispatchRequest> dispatchRequests;
  DispatchRequest? activeRequest;
  int? selectedRequestIndex;
  Map<MarkerId, Marker> markers;
  List<Polyline> polylines;
  List<LatLng> polylineCoordinates;
  SourceAndDestinationStatus sourceAndDestinationStatus;
  MapCameraStatus mapCameraStatus;
  PanelControlStatus panelControlStatus;
  BroadcastStatus broadcastStatus;
  ActionButtonStatus actionButtonStatus;
  double minDrawerHeight;
  double maxDrawerHeight;
  List<Message> chatMessages;
  ChatStatus chatStatus;
  String? message;
  bool canGoOnline;
  List<String> verificationChecklist;
  RequestStatus requestStatus;

  HomeState({
    this.ongoingRequests = const [],
    this.rideStatus = RideStatus.offline,
    this.locationData,
    this.dispatchRequests = const [],
    this.markers = const {},
    this.polylines = const [],
    this.polylineCoordinates = const [],
    this.sourceAndDestinationStatus = SourceAndDestinationStatus.unselected,
    this.mapCameraStatus = MapCameraStatus.initialized,
    this.panelControlStatus = PanelControlStatus.initialized,
    this.actionButtonStatus = ActionButtonStatus.initialized,
    this.minDrawerHeight = 180,
    this.maxDrawerHeight = 180,
    this.selectedRequestIndex,
    this.activeRequest,
    this.broadcastStatus = BroadcastStatus.initialized,
    this.chatMessages = const [],
    this.chatStatus = ChatStatus.initial,
    this.message,
    this.canGoOnline = false,
    this.verificationChecklist = const [],
    this.requestStatus = RequestStatus.initial,
  });

  HomeState copyWith(
      {List? ongoingRequests,
      RideStatus? rideStatus,
      Position? locationData,
      Map<MarkerId, Marker>? markers,
      List<Polyline>? polylines,
      List<LatLng>? polylineCoordinates,
      List<DispatchRequest>? dispatchRequests,
      SourceAndDestinationStatus? sourceAndDestinationStatus,
      MapCameraStatus? mapCameraStatus,
      PanelControlStatus? panelControlStatus,
      ActionButtonStatus? actionButtonStatus,
      BroadcastStatus? broadcastStatus,
      double? minDrawerHeight,
      double? maxDrawerHeight,
      int? selectedRequestIndex,
      DispatchRequest? activeRequest,
      List<Message>? chatMessages,
      ChatStatus? chatStatus,
      String? message,
      bool? canGoOnline,
      List<String>? verificationChecklist,
      RequestStatus? requestStatus}) {
    return HomeState(
        ongoingRequests: ongoingRequests ?? this.ongoingRequests,
        rideStatus: rideStatus ?? this.rideStatus,
        locationData: locationData ?? this.locationData,
        dispatchRequests: dispatchRequests ?? this.dispatchRequests,
        markers: markers ?? this.markers,
        polylines: polylines ?? this.polylines,
        polylineCoordinates: polylineCoordinates ?? this.polylineCoordinates,
        sourceAndDestinationStatus:
            sourceAndDestinationStatus ?? this.sourceAndDestinationStatus,
        broadcastStatus: broadcastStatus ?? this.broadcastStatus,
        mapCameraStatus: mapCameraStatus ?? this.mapCameraStatus,
        minDrawerHeight: minDrawerHeight ?? this.minDrawerHeight,
        maxDrawerHeight: maxDrawerHeight ?? this.maxDrawerHeight,
        panelControlStatus: panelControlStatus ?? this.panelControlStatus,
        actionButtonStatus: actionButtonStatus ?? this.actionButtonStatus,
        selectedRequestIndex: selectedRequestIndex ?? this.selectedRequestIndex,
        activeRequest: activeRequest ?? this.activeRequest,
        chatMessages: chatMessages ?? this.chatMessages,
        chatStatus: chatStatus ?? this.chatStatus,
        message: message ?? this.message,
        canGoOnline: canGoOnline ?? this.canGoOnline,
        verificationChecklist:
            verificationChecklist ?? this.verificationChecklist,
        requestStatus: requestStatus ?? this.requestStatus);
  }
}

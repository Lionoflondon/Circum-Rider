part of 'home_bloc.dart';

// default MapCameraStatus is initial, lat 0, lng 0
enum MapCameraStatus {
  initialized,
  showingDeviceLocation,
  showingSourceAndDestinationLocations,
}

enum SourceAndDestinationStatus { unselected, selected }

enum RideStatus {
  offline,
  online,
  acceptedARide,
  userConfirmedRide,
  arrivedAtPickupLocation,
  outForDelivery,
  delivered,
}

enum PanelControlStatus { initialized, isOpened, isClosed }

enum BroadcastStatus { initialized, broadcasting }

enum RequestStatus { initial, loading, success, failure }

enum RiderAvailabilityStatus {
  offline,
  goingOnline,
  waitingForLocation,
  online,
  temporarilyUnavailable,
  goingOffline,
  activeDelivery,
  error,
}

class RiderAvailability {
  const RiderAvailability({
    this.status = RiderAvailabilityStatus.offline,
    this.lastFix,
    this.lastHeartbeat,
    this.dispatchEligible = false,
    this.activeDeliveryId,
  });

  final RiderAvailabilityStatus status;
  final DateTime? lastFix;
  final DateTime? lastHeartbeat;
  final bool dispatchEligible;
  final String? activeDeliveryId;

  bool get isOnline =>
      status == RiderAvailabilityStatus.online ||
      status == RiderAvailabilityStatus.activeDelivery;

  bool get intendsToBeOnline => switch (status) {
    RiderAvailabilityStatus.goingOnline ||
    RiderAvailabilityStatus.waitingForLocation ||
    RiderAvailabilityStatus.online ||
    RiderAvailabilityStatus.temporarilyUnavailable ||
    RiderAvailabilityStatus.goingOffline => true,
    RiderAvailabilityStatus.activeDelivery => true,
    RiderAvailabilityStatus.offline || RiderAvailabilityStatus.error => false,
  };

  RiderAvailability copyWith({
    RiderAvailabilityStatus? status,
    DateTime? lastFix,
    DateTime? lastHeartbeat,
    bool? dispatchEligible,
    String? activeDeliveryId,
  }) {
    return RiderAvailability(
      status: status ?? this.status,
      lastFix: lastFix ?? this.lastFix,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      dispatchEligible: dispatchEligible ?? this.dispatchEligible,
      activeDeliveryId: activeDeliveryId ?? this.activeDeliveryId,
    );
  }

  factory RiderAvailability.fromPresence(
    Map<String, dynamic> presence, {
    DateTime? now,
  }) {
    final evaluatedAt = now ?? DateTime.now();
    final location = presence['currentLocation'];
    final locationMap = location is Map ? location : const {};
    final lastFix = _time(
      locationMap['updatedAt'] ?? presence['lastLocationAt'],
    );
    final heartbeat = _time(presence['lastHeartbeatAt']);
    final locationFresh =
        lastFix != null &&
        evaluatedAt.difference(lastFix) <= const Duration(minutes: 2);
    final heartbeatFresh =
        heartbeat != null &&
        evaluatedAt.difference(heartbeat) <= const Duration(minutes: 2);
    final rawStatus =
        '${presence['availabilityStatus'] ?? presence['status'] ?? ''}'
            .trim()
            .toLowerCase();
    final activeDeliveryId =
        '${presence['activeDeliveryId'] ?? presence['currentDeliveryId'] ?? ''}'
            .trim();
    final explicitlyOnline =
        presence['isOnline'] == true ||
        rawStatus == 'online' ||
        rawStatus == 'available' ||
        rawStatus == 'busy' ||
        rawStatus == 'going_online' ||
        rawStatus == 'connection_lost';
    final eligible =
        presence['dispatchEligible'] == true && locationFresh && heartbeatFresh;
    final status = !explicitlyOnline || rawStatus == 'offline'
        ? RiderAvailabilityStatus.offline
        : activeDeliveryId.isNotEmpty
        ? RiderAvailabilityStatus.activeDelivery
        : !locationFresh
        ? RiderAvailabilityStatus.waitingForLocation
        : eligible
        ? RiderAvailabilityStatus.online
        : RiderAvailabilityStatus.temporarilyUnavailable;
    return RiderAvailability(
      status: status,
      lastFix: lastFix,
      lastHeartbeat: heartbeat,
      dispatchEligible: eligible,
      activeDeliveryId: activeDeliveryId.isEmpty ? null : activeDeliveryId,
    );
  }

  static DateTime? _time(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse('${value ?? ''}');
  }
}

enum ChatStatus { initial, newMessage }

enum ActionButtonStatus {
  initialized,
  goingToPickupLocation,
  arrivedPickupLocation,
  outForDelivery,
  delivered,
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
  RiderAvailability availability;

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
    this.availability = const RiderAvailability(),
  });

  HomeState copyWith({
    List? ongoingRequests,
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
    RequestStatus? requestStatus,
    RiderAvailability? availability,
  }) {
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
      requestStatus: requestStatus ?? this.requestStatus,
      availability: availability ?? this.availability,
    );
  }
}

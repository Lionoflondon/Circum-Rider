import 'package:cloud_functions/cloud_functions.dart';

class RiderDeliveryTransitionResult {
  final String status;

  const RiderDeliveryTransitionResult(this.status);
}

abstract class RiderDeliveryController {
  Future<RiderDeliveryTransitionResult> transition({
    required String deliveryId,
    required String action,
    String? pin,
  });
}

class CallableRiderDeliveryController implements RiderDeliveryController {
  final FirebaseFunctions functions;

  CallableRiderDeliveryController({FirebaseFunctions? functions})
      : functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  Future<RiderDeliveryTransitionResult> transition({
    required String deliveryId,
    required String action,
    String? pin,
  }) async {
    final result = await functions
        .httpsCallable('updateDeliveryTrackingStatus')
        .call(<String, dynamic>{
      'deliveryId': deliveryId,
      'action': action,
      if (pin != null) 'pin': pin,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return RiderDeliveryTransitionResult('${data['status'] ?? ''}');
  }
}

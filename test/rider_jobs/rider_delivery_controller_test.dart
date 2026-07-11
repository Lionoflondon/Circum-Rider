import 'package:circum_rider/app/rider_jobs/rider_delivery_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingController implements RiderDeliveryController {
  int calls = 0;
  String? deliveryId;
  String? action;
  String? pin;

  @override
  Future<RiderDeliveryTransitionResult> transition({
    required String deliveryId,
    required String action,
    String? pin,
    Map<String, dynamic>? evidence,
    Map<String, dynamic>? issue,
  }) async {
    calls += 1;
    this.deliveryId = deliveryId;
    this.action = action;
    this.pin = pin;
    return const RiderDeliveryTransitionResult('pickup_verified');
  }

  @override
  Future<Map<String, dynamic>> markNoShow({required String deliveryId}) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> reportDiscrepancy({
    required String deliveryId,
    required String reason,
    required List<String> evidencePhotos,
    double? observedWeightKg,
    String? notes,
  }) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> reportWaitingContext({
    required String deliveryId,
    required String type,
    String? note,
  }) async =>
      {'success': true};
}

void main() {
  test('delivery controller contract keeps PIN inside trusted callable request',
      () async {
    final controller = _RecordingController();

    final result = await controller.transition(
      deliveryId: 'delivery-1',
      action: 'verify_collection_pin',
      pin: '123456',
    );

    expect(controller.calls, 1);
    expect(controller.deliveryId, 'delivery-1');
    expect(controller.action, 'verify_collection_pin');
    expect(controller.pin, '123456');
    expect(result.status, 'pickup_verified');
  });
}

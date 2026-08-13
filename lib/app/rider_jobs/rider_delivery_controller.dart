import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class RiderDeliveryTransitionResult {
  final String status;

  const RiderDeliveryTransitionResult(this.status);
}

abstract class RiderDeliveryController {
  Future<RiderDeliveryTransitionResult> transition({
    required String deliveryId,
    required String action,
    String? pin,
    Map<String, dynamic>? evidence,
    Map<String, dynamic>? issue,
  });

  Future<Map<String, dynamic>> reportDiscrepancy({
    required String deliveryId,
    required String reason,
    required List<String> evidenceIds,
    double? observedWeightKg,
    String? notes,
  });

  Future<Map<String, dynamic>> markNoShow({required String deliveryId});

  Future<Map<String, dynamic>> reportWaitingContext({
    required String deliveryId,
    required String type,
    String? note,
  });

  Future<Map<String, dynamic>> confirmIrisAssessment({
    required String deliveryId,
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
    Map<String, dynamic>? evidence,
    Map<String, dynamic>? issue,
  }) async {
    if (action == 'arrived_at_pickup' || action == 'arrived_at_dropoff') {
      final arrival = await functions.httpsCallable('recordRiderArrival').call({
        'deliveryId': deliveryId,
        'phase': action == 'arrived_at_dropoff' ? 'dropoff' : 'pickup',
      });
      final arrivalData = Map<String, dynamic>.from(arrival.data as Map);
      final decision = arrivalData['decision'] is Map
          ? Map<String, dynamic>.from(arrivalData['decision'] as Map)
          : const <String, dynamic>{};
      if (arrivalData['success'] != true) {
        throw StateError(
            '${decision['riderMessage'] ?? 'Arrival could not be confirmed.'}');
      }
      return RiderDeliveryTransitionResult('${decision['state'] ?? ''}');
    }
    final result = await functions
        .httpsCallable('updateDeliveryTrackingStatus')
        .call(<String, dynamic>{
      'deliveryId': deliveryId,
      'action': action,
      if (pin != null) 'pin': pin,
      if (evidence != null) 'evidence': evidence,
      if (issue != null) 'issue': issue,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return RiderDeliveryTransitionResult('${data['status'] ?? ''}');
  }

  @override
  Future<Map<String, dynamic>> reportDiscrepancy({
    required String deliveryId,
    required String reason,
    required List<String> evidenceIds,
    double? observedWeightKg,
    String? notes,
  }) async {
    final result = await functions.httpsCallable('reportLoadDiscrepancy').call({
      'requestId': deliveryId,
      'reason': reason,
      'evidenceIds': evidenceIds,
      if (observedWeightKg != null) 'observedWeightKg': observedWeightKg,
      if (notes != null) 'riderNotes': notes,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<Map<String, dynamic>> markNoShow({required String deliveryId}) async {
    final result = await functions.httpsCallable('markRiderNoShow').call({
      'deliveryId': deliveryId,
      'idempotencyKey': '$deliveryId:no_show',
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<Map<String, dynamic>> reportWaitingContext({
    required String deliveryId,
    required String type,
    String? note,
  }) async {
    final result = await functions.httpsCallable('reportWaitingContext').call({
      'deliveryId': deliveryId,
      'type': type,
      if (note != null) 'note': note,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<Map<String, dynamic>> confirmIrisAssessment({
    required String deliveryId,
  }) async {
    final result = await functions
        .httpsCallable('confirmRiderIrisAssessment')
        .call({'deliveryId': deliveryId});
    return Map<String, dynamic>.from(result.data as Map);
  }
}

class RiderEvidenceUploader {
  final ImagePicker picker;
  final FirebaseFunctions functions;

  RiderEvidenceUploader({ImagePicker? picker, FirebaseFunctions? functions})
      : picker = picker ?? ImagePicker(),
        functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<String?> capture({
    required String deliveryId,
    required String stage,
    ImageSource source = ImageSource.camera,
  }) async {
    final image = await picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    final result =
        await functions.httpsCallable('submitDeliveryEvidence').call({
      'deliveryId': deliveryId,
      'stage': stage,
      'contentType': image.mimeType ?? 'image/jpeg',
      'imageBase64': base64Encode(bytes),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final evidenceId = '${data['evidenceId'] ?? ''}'.trim();
    if (evidenceId.isEmpty) throw StateError('Evidence was not verified.');
    return evidenceId;
  }
}

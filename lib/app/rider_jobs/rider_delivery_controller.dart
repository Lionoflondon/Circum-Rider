import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

const _riderDeliveryOperationTimeout = Duration(seconds: 30);

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
    required List<String> evidencePhotos,
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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      ).timeout(_riderDeliveryOperationTimeout);
      final arrival = await functions.httpsCallable('recordRiderArrival').call({
        'deliveryId': deliveryId,
        'phase': action == 'arrived_at_dropoff' ? 'dropoff' : 'pickup',
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracy,
          'clientRecordedAt': position.timestamp.millisecondsSinceEpoch,
          'mocked': position.isMocked,
        },
        'gpsAccuracyMeters': position.accuracy,
      }).timeout(_riderDeliveryOperationTimeout);
      final arrivalData = Map<String, dynamic>.from(arrival.data as Map);
      final decision = arrivalData['decision'] is Map
          ? Map<String, dynamic>.from(arrivalData['decision'] as Map)
          : const <String, dynamic>{};
      if (arrivalData['success'] != true) {
        throw StateError(
          '${decision['riderMessage'] ?? 'Arrival could not be confirmed.'}',
        );
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
    }).timeout(_riderDeliveryOperationTimeout);
    final data = Map<String, dynamic>.from(result.data as Map);
    return RiderDeliveryTransitionResult('${data['status'] ?? ''}');
  }

  @override
  Future<Map<String, dynamic>> reportDiscrepancy({
    required String deliveryId,
    required String reason,
    required List<String> evidencePhotos,
    double? observedWeightKg,
    String? notes,
  }) async {
    final result = await functions.httpsCallable('reportLoadDiscrepancy').call({
      'requestId': deliveryId,
      'reason': reason,
      'evidencePhotos': evidencePhotos,
      if (observedWeightKg != null) 'observedWeightKg': observedWeightKg,
      if (notes != null) 'riderNotes': notes,
    }).timeout(_riderDeliveryOperationTimeout);
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<Map<String, dynamic>> markNoShow({required String deliveryId}) async {
    final result = await functions.httpsCallable('markRiderNoShow').call({
      'deliveryId': deliveryId,
      'idempotencyKey': '$deliveryId:no_show',
    }).timeout(_riderDeliveryOperationTimeout);
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
    }).timeout(_riderDeliveryOperationTimeout);
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<Map<String, dynamic>> confirmIrisAssessment({
    required String deliveryId,
  }) async {
    final result = await functions
        .httpsCallable('confirmRiderIrisAssessment')
        .call({'deliveryId': deliveryId}).timeout(
            _riderDeliveryOperationTimeout);
    return Map<String, dynamic>.from(result.data as Map);
  }
}

class RiderEvidenceUploader {
  final FirebaseStorage storage;
  final ImagePicker picker;

  RiderEvidenceUploader({FirebaseStorage? storage, ImagePicker? picker})
      : storage = storage ?? FirebaseStorage.instance,
        picker = picker ?? ImagePicker();

  Future<String?> capture({
    required String deliveryId,
    required String stage,
  }) async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes().timeout(
          _riderDeliveryOperationTimeout,
        );
    final safeStage = stage.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final ref = storage.ref(
      'delivery_weight_evidence/$deliveryId/$safeStage/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref
        .putData(
            bytes,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'deliveryId': deliveryId,
                'uploadedBy': FirebaseAuth.instance.currentUser!.uid,
                'evidenceType': 'weight_discrepancy',
              },
            ))
        .timeout(_riderDeliveryOperationTimeout);
    return ref.getDownloadURL().timeout(_riderDeliveryOperationTimeout);
  }
}

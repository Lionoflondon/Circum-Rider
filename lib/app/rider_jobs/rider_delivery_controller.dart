import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

String _redactEvidenceDiagnostic(String value) {
  return value
      .replaceAll(
        RegExp(r'(token|access_token|auth)=[^&\s]+', caseSensitive: false),
        r'\1=[REDACTED]',
      )
      .replaceAll(
        RegExp(r'bearer\s+[^\s]+', caseSensitive: false),
        'Bearer [REDACTED]',
      );
}

class RiderEvidenceUploadException implements Exception {
  final String stage;
  final String deliveryId;
  final String storagePath;
  final String bucket;
  final int byteSize;
  final String contentType;
  final String? firebaseCode;
  final String message;

  const RiderEvidenceUploadException({
    required this.stage,
    required this.deliveryId,
    required this.storagePath,
    required this.bucket,
    required this.byteSize,
    required this.contentType,
    required this.firebaseCode,
    required this.message,
  });

  factory RiderEvidenceUploadException.fromError({
    required String stage,
    required String deliveryId,
    required String storagePath,
    required String bucket,
    required int byteSize,
    required String contentType,
    required Object error,
  }) {
    final firebaseError = error is FirebaseException ? error : null;
    final rawMessage = firebaseError?.message ?? error.toString();
    return RiderEvidenceUploadException(
      stage: stage,
      deliveryId: deliveryId,
      storagePath: storagePath,
      bucket: bucket,
      byteSize: byteSize,
      contentType: contentType,
      firebaseCode: firebaseError?.code,
      message: _redactEvidenceDiagnostic(rawMessage),
    );
  }

  String get userMessage =>
      'Evidence upload failed. Check your connection and retry.';

  @override
  String toString() {
    return 'RiderEvidenceUploadException('
        'stage=$stage, deliveryId=$deliveryId, bucket=$bucket, '
        'storagePath=$storagePath, byteSize=$byteSize, '
        'contentType=$contentType, firebaseCode=$firebaseCode, '
        'message=$message)';
  }
}

class RiderDeliveryTransitionResult {
  final String status;

  const RiderDeliveryTransitionResult(this.status);
}

class RiderCapturedEvidence {
  final String photoId;
  final String storagePath;
  final String bucket;
  final String checksum;
  final String mimeType;
  final int fileSize;

  const RiderCapturedEvidence({
    required this.photoId,
    required this.storagePath,
    required this.bucket,
    required this.checksum,
    required this.mimeType,
    required this.fileSize,
  });
}

abstract class RiderDeliveryController {
  Future<RiderDeliveryTransitionResult> completeDelivery({
    required String deliveryId,
    String? deliveryPin,
    String? evidenceId,
    Map<String, dynamic>? evidence,
    String? clientVersion,
    Map<String, dynamic>? deviceMetadata,
  });

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

  Future<Map<String, dynamic>> recordEvidence({
    required String deliveryId,
    required RiderCapturedEvidence evidence,
  });
}

class CallableRiderDeliveryController implements RiderDeliveryController {
  final FirebaseFunctions functions;

  CallableRiderDeliveryController({FirebaseFunctions? functions})
      : functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  Future<RiderDeliveryTransitionResult> completeDelivery({
    required String deliveryId,
    String? deliveryPin,
    String? evidenceId,
    Map<String, dynamic>? evidence,
    String? clientVersion,
    Map<String, dynamic>? deviceMetadata,
  }) async {
    final result = await functions.httpsCallable('completeDelivery').call({
      'deliveryId': deliveryId,
      if (deliveryPin != null) 'deliveryPin': deliveryPin,
      if (evidenceId != null) 'evidenceId': evidenceId,
      if (evidence != null) 'evidence': evidence,
      if (clientVersion != null) 'clientVersion': clientVersion,
      if (deviceMetadata != null) 'deviceMetadata': deviceMetadata,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return RiderDeliveryTransitionResult('${data['status'] ?? ''}');
  }

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
    });
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

  @override
  Future<Map<String, dynamic>> recordEvidence({
    required String deliveryId,
    required RiderCapturedEvidence evidence,
  }) async {
    final result =
        await functions.httpsCallable('recordDeliveryEvidence').call({
      'deliveryId': deliveryId,
      'photoId': evidence.photoId,
      'type': 'PHOTO',
      'storagePath': evidence.storagePath,
      'checksum': evidence.checksum,
      'mimeType': evidence.mimeType,
      'fileSize': evidence.fileSize,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}

class RiderEvidenceUploader {
  final FirebaseStorage storage;
  final ImagePicker picker;

  RiderEvidenceUploader({FirebaseStorage? storage, ImagePicker? picker})
      : storage = storage ?? FirebaseStorage.instance,
        picker = picker ?? ImagePicker();

  Future<RiderCapturedEvidence?> capture({
    required String deliveryId,
    required String stage,
  }) async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image == null) return null;
    final sourceMime = image.mimeType?.trim().toLowerCase() ?? '';
    final sourceName = image.name.toLowerCase();
    final jpegSelected = sourceMime == 'image/jpeg' ||
        (sourceMime.isEmpty &&
            (sourceName.endsWith('.jpg') || sourceName.endsWith('.jpeg')));
    final safeStage = stage.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final photoId = '${DateTime.now().microsecondsSinceEpoch}_$safeStage';
    final storagePath = 'deliveries/$deliveryId/evidence/photos/$photoId.jpg';
    final ref = storage.ref(storagePath);
    const contentType = 'image/jpeg';
    if (!jpegSelected) {
      final failure = RiderEvidenceUploadException.fromError(
        stage: 'validate_input',
        deliveryId: deliveryId,
        storagePath: storagePath,
        bucket: ref.bucket,
        byteSize: 0,
        contentType: sourceMime,
        error: StateError('Evidence photo must be a JPEG.'),
      );
      developer.log(failure.toString(), name: 'rider.evidence.upload');
      throw failure;
    }

    late final Uint8List bytes;
    try {
      bytes = await image.readAsBytes();
    } catch (error, stackTrace) {
      final failure = RiderEvidenceUploadException.fromError(
        stage: 'read_bytes',
        deliveryId: deliveryId,
        storagePath: storagePath,
        bucket: ref.bucket,
        byteSize: 0,
        contentType: contentType,
        error: error,
      );
      developer.log(
        failure.toString(),
        name: 'rider.evidence.upload',
        error: failure,
        stackTrace: stackTrace,
      );
      throw failure;
    }
    try {
      if (bytes.isEmpty) {
        throw StateError('Evidence image contains no bytes.');
      }
      await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
    } catch (error, stackTrace) {
      final failure = RiderEvidenceUploadException.fromError(
        stage: 'storage_put_data',
        deliveryId: deliveryId,
        storagePath: storagePath,
        bucket: ref.bucket,
        byteSize: bytes.length,
        contentType: contentType,
        error: error,
      );
      developer.log(
        failure.toString(),
        name: 'rider.evidence.upload',
        error: failure,
        stackTrace: stackTrace,
      );
      throw failure;
    }

    FullMetadata metadata;
    try {
      metadata = await ref.getMetadata();
    } catch (error, stackTrace) {
      final failure = RiderEvidenceUploadException.fromError(
        stage: 'storage_get_metadata',
        deliveryId: deliveryId,
        storagePath: storagePath,
        bucket: ref.bucket,
        byteSize: bytes.length,
        contentType: contentType,
        error: error,
      );
      developer.log(
        failure.toString(),
        name: 'rider.evidence.upload',
        error: failure,
        stackTrace: stackTrace,
      );
      throw failure;
    }
    return RiderCapturedEvidence(
      photoId: photoId,
      storagePath: storagePath,
      bucket: ref.bucket,
      checksum: metadata.md5Hash ?? '',
      mimeType: metadata.contentType ?? 'image/jpeg',
      fileSize: metadata.size ?? bytes.length,
    );
  }
}

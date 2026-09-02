import 'dart:io';

const riderDocumentMaxBytes = 8 * 1024 * 1024;

enum RiderDocumentSide { front, back, primary }

class RiderDocumentSelection {
  const RiderDocumentSelection({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String path;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  bool get isPdf => mimeType == 'application/pdf';

  static Future<RiderDocumentSelection> fromPath(
    String path, {
    String? fileName,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const RiderDocumentSelectionException(
        'The selected file is no longer available. Choose it again.',
      );
    }
    final size = await file.length();
    if (size <= 0) {
      throw const RiderDocumentSelectionException(
        'The selected file is empty. Choose another file.',
      );
    }
    if (size > riderDocumentMaxBytes) {
      throw const RiderDocumentSelectionException(
        'Documents must be 8 MiB or smaller.',
      );
    }
    final name = (fileName ?? path.split(Platform.pathSeparator).last).trim();
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : path.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => throw const RiderDocumentSelectionException(
          'Choose a JPG, PNG, WEBP or PDF document.',
        ),
    };
    return RiderDocumentSelection(
      path: path,
      fileName: name,
      mimeType: mimeType,
      sizeBytes: size,
    );
  }
}

class RiderDocumentDraft {
  const RiderDocumentDraft({this.front, this.back, this.primary});

  final RiderDocumentSelection? front;
  final RiderDocumentSelection? back;
  final RiderDocumentSelection? primary;

  RiderDocumentSelection? forSide(RiderDocumentSide side) => switch (side) {
        RiderDocumentSide.front => front,
        RiderDocumentSide.back => back,
        RiderDocumentSide.primary => primary,
      };

  RiderDocumentDraft select(
    RiderDocumentSide side,
    RiderDocumentSelection selection,
  ) =>
      switch (side) {
        RiderDocumentSide.front =>
          RiderDocumentDraft(front: selection, back: back, primary: primary),
        RiderDocumentSide.back =>
          RiderDocumentDraft(front: front, back: selection, primary: primary),
        RiderDocumentSide.primary =>
          RiderDocumentDraft(front: front, back: back, primary: selection),
      };

  bool complete({required bool requiresFrontAndBack}) =>
      requiresFrontAndBack ? front != null && back != null : primary != null;
}

class RiderDocumentSelectionException implements Exception {
  const RiderDocumentSelectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

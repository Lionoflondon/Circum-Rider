import 'dart:io';

import 'package:circum_rider/app/verification/rider_document_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rider-doc-test-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<RiderDocumentSelection> selection(
    String name,
    List<int> bytes,
  ) async {
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes);
    return RiderDocumentSelection.fromPath(file.path);
  }

  test('front and back selections remain independent', () async {
    final front = await selection('front.jpg', [1, 2, 3]);
    final back = await selection('back.png', [4, 5, 6]);

    final draft = const RiderDocumentDraft()
        .select(RiderDocumentSide.front, front)
        .select(RiderDocumentSide.back, back);

    expect(draft.front?.path, front.path);
    expect(draft.back?.path, back.path);
    expect(draft.front?.path, isNot(draft.back?.path));
    expect(draft.complete(requiresFrontAndBack: true), isTrue);
  });

  test('replacing one side never changes the other side', () async {
    final oldFront = await selection('old-front.jpg', [1]);
    final newFront = await selection('new-front.jpg', [2]);
    final back = await selection('back.jpg', [3]);
    final initial = const RiderDocumentDraft()
        .select(RiderDocumentSide.front, oldFront)
        .select(RiderDocumentSide.back, back);

    final updated = initial.select(RiderDocumentSide.front, newFront);

    expect(updated.front?.path, newFront.path);
    expect(updated.back?.path, back.path);
  });

  test('preview source can only be the selected file for the active side',
      () async {
    final jobsScreenshot = await selection('rider-jobs.png', [1, 2]);
    final idFront = await selection('licence-front.jpg', [3, 4]);
    final draft = const RiderDocumentDraft()
        .select(RiderDocumentSide.back, jobsScreenshot)
        .select(RiderDocumentSide.front, idFront);

    expect(draft.forSide(RiderDocumentSide.front)?.path, idFront.path);
    expect(
      draft.forSide(RiderDocumentSide.front)?.path,
      isNot(jobsScreenshot.path),
    );
  });

  test('front-only and back-only drafts cannot submit', () async {
    final front = await selection('front.pdf', [37, 80, 68, 70]);
    final back = await selection('back.webp', [1]);

    expect(
      const RiderDocumentDraft()
          .select(RiderDocumentSide.front, front)
          .complete(requiresFrontAndBack: true),
      isFalse,
    );
    expect(
      const RiderDocumentDraft()
          .select(RiderDocumentSide.back, back)
          .complete(requiresFrontAndBack: true),
      isFalse,
    );
  });

  test('canonical formats include PDF and reject HEIC', () async {
    final pdf = await selection('permit.pdf', [37, 80, 68, 70]);
    expect(pdf.mimeType, 'application/pdf');
    expect(pdf.isPdf, isTrue);

    final heic = File('${directory.path}/photo.heic');
    await heic.writeAsBytes([1, 2, 3]);
    expect(
      () => RiderDocumentSelection.fromPath(heic.path),
      throwsA(isA<RiderDocumentSelectionException>()),
    );
  });

  test('empty and oversized files are rejected', () async {
    final empty = File('${directory.path}/empty.jpg');
    await empty.writeAsBytes([]);
    expect(
      () => RiderDocumentSelection.fromPath(empty.path),
      throwsA(isA<RiderDocumentSelectionException>()),
    );

    final oversized = File('${directory.path}/large.pdf');
    await oversized.writeAsBytes(
      List<int>.filled(riderDocumentMaxBytes + 1, 0),
    );
    expect(
      () => RiderDocumentSelection.fromPath(oversized.path),
      throwsA(isA<RiderDocumentSelectionException>()),
    );
  });
}

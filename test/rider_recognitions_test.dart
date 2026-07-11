import 'package:circum_rider/app/recognitions/rider_recognitions.dart';
import 'package:circum_rider/app/rider_truth/rider_truth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider recognitions parse canonical nested fields', () {
    final recognitions = RiderRecognitions.from({
      'recognitions': {
        'legend': {'awarded': true, 'number': 8},
        'foundingRider': {'awarded': true, 'number': 12},
      },
    });

    expect(recognitions.legend.awarded, isTrue);
    expect(recognitions.legend.numberLabel(4), '#0008');
    expect(recognitions.foundingRider.awarded, isTrue);
    expect(recognitions.foundingRider.numberLabel(4), '#0012');
  });

  test('Rider recognitions preserve flat compatibility fields', () {
    final recognitions = RiderRecognitions.from({
      'isLegend': true,
      'legendNumber': 1000,
      'isFoundingRider': true,
      'foundingRiderNumber': 1,
    });

    expect(recognitions.legend.numberLabel(4), '#1000');
    expect(recognitions.foundingRider.numberLabel(4), '#0001');
  });

  test('Founding Rider recognition does not replace Rider rank', () {
    final rank = RiderRankSnapshot.from({
      'trustPoints': 0,
      'rank': 'Veteran',
      'recognitions': {
        'foundingRider': {'awarded': true, 'number': 1},
      },
    });
    final recognitions = RiderRecognitions.from({
      'trustPoints': 0,
      'rank': 'Veteran',
      'recognitions': {
        'foundingRider': {'awarded': true, 'number': 1},
      },
    });

    expect(rank?.rank, 'Agent');
    expect(rank?.trustPoints, 0);
    expect(recognitions.foundingRider.awarded, isTrue);
  });
}

class RiderRecognitionAward {
  const RiderRecognitionAward({
    required this.awarded,
    this.number,
  });

  final bool awarded;
  final int? number;

  String numberLabel(int width) =>
      number == null ? '' : '#${number.toString().padLeft(width, '0')}';

  static RiderRecognitionAward from(
    Map<String, dynamic> data,
    String key, {
    required String flatAwardedKey,
    required String flatNumberKey,
  }) {
    final recognitions =
        Map<String, dynamic>.from(data['recognitions'] as Map? ?? {});
    final nested = Map<String, dynamic>.from(recognitions[key] as Map? ?? {});
    return RiderRecognitionAward(
      awarded: nested['awarded'] == true || data[flatAwardedKey] == true,
      number: (nested['number'] as num?)?.toInt() ??
          (data[flatNumberKey] as num?)?.toInt(),
    );
  }
}

class RiderRecognitions {
  const RiderRecognitions({
    required this.legend,
    required this.foundingRider,
  });

  final RiderRecognitionAward legend;
  final RiderRecognitionAward foundingRider;

  bool get hasAny => legend.awarded || foundingRider.awarded;

  static RiderRecognitions from(Map<String, dynamic> data) => RiderRecognitions(
        legend: RiderRecognitionAward.from(
          data,
          'legend',
          flatAwardedKey: 'isLegend',
          flatNumberKey: 'legendNumber',
        ),
        foundingRider: RiderRecognitionAward.from(
          data,
          'foundingRider',
          flatAwardedKey: 'isFoundingRider',
          flatNumberKey: 'foundingRiderNumber',
        ),
      );
}

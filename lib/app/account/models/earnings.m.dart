class EarningsModel {
  double accountBalance;
  double totalAmountEarned;
  int totalTrips;
  Map<String, double> weeklyEarnings;

  EarningsModel(
      {required this.accountBalance,
      required this.totalAmountEarned,
      required this.totalTrips,
      required this.weeklyEarnings});

  factory EarningsModel.fromJson(data) {
    return EarningsModel(
        accountBalance: double.parse(
            double.parse(data['accountBalance'].toString()).toStringAsFixed(2)),
        totalAmountEarned: double.parse(
            double.parse(data['totalAmountEarned'].toString())
                .toStringAsFixed(2)),
        totalTrips: int.parse(data['totalTrips'].toString()),
        weeklyEarnings: convertDynamicToDouble(data['weeklyEarnings']));
  }
}

Map<String, double> convertDynamicToDouble(Map<String, dynamic> map) {
  Map<String, double> result = {};

  map.forEach((key, value) {
    // Check if the dynamic value can be converted to double
    if (value is double) {
      result[key] = value;
    } else if (value is int) {
      // If it's an integer, convert it to double
      result[key] = value.toDouble();
    } else if (value is String) {
      // If it's a string representing a number, parse and convert it to double
      result[key] =
          double.tryParse(value) ?? 0.0; // Default to 0.0 if parsing fails
    } else {
      // Handle other cases if necessary
      // For simplicity, you can skip or handle other types differently
    }
  });

  return result;
}

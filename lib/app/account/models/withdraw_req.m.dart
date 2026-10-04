class WithdrawRequestModel {
  String accountNumber;
  String bankName;
  String amount;
  bool saveAccountDetails;
  String riderId;
  final String? requestId;

  WithdrawRequestModel({
    required this.accountNumber,
    required this.bankName,
    required this.amount,
    required this.saveAccountDetails,
    required this.riderId,
    this.requestId,
  });

  factory WithdrawRequestModel.fromJson(data) {
    return WithdrawRequestModel(
      accountNumber: data['accountNumber'].toString(),
      bankName: data['bankName'].toString(),
      amount: data['amount'].toString(),
      saveAccountDetails: data['saveAccountDetails'] == true,
      requestId: data['id']?.toString() ?? data['requestId']?.toString(),
      riderId: data['riderId'].toString(),
    );
  }
}

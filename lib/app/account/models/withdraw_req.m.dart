class WithdrawRequestModel {
  String accountNumber;
  String bankName;
  String amount;
  bool saveAccountDetails;
  String riderId;

  WithdrawRequestModel({
    required this.accountNumber,
    required this.bankName,
    required this.amount,
    required this.saveAccountDetails,
    required this.riderId,
  });

  factory WithdrawRequestModel.fromJson(data) {
    return WithdrawRequestModel(
      accountNumber: data['accountNumber'].toString(),
      bankName: data['bankName'].toString(),
      amount: data['amount'].toString(),
      saveAccountDetails: data['saveAccountDetails'],
      riderId: data['riderId'].toString(),
    );
  }
}

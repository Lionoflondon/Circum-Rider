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
      accountNumber: '${data['accountNumber'] ?? ''}',
      bankName: '${data['bankName'] ?? 'Verified bank account'}',
      amount: '${data['amount'] ?? 0}',
      saveAccountDetails: data['saveAccountDetails'] == true,
      riderId: '${data['riderId'] ?? ''}',
    );
  }
}

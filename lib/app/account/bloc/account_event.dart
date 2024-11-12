part of 'account_bloc.dart';

abstract class AccountEvent {
  const AccountEvent();
}

class GetEarnings extends AccountEvent {}

class RequestWithdrawal extends AccountEvent {
  final String sortCode;
  final String address;
  final String amount;
  final String bankName;
  final String accountNumber;
  final bool saveAccountDetails;

  RequestWithdrawal(
      {required this.sortCode,
      required this.accountNumber,
      required this.address,
      required this.amount,
      required this.bankName,
      required this.saveAccountDetails});
}

class GetRequests extends AccountEvent {}

class CancelWithdrawalRequest extends AccountEvent {}

class ResetAccountStatus extends AccountEvent {
  final AccountStatus status;
  ResetAccountStatus({required this.status});
}

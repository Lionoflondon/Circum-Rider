part of 'account_bloc.dart';

abstract class AccountEvent {
  const AccountEvent();
}

class GetEarnings extends AccountEvent {}

class RequestWithdrawal extends AccountEvent {
  final String amount;
  final String bankName;
  final String accountNumber;
  final bool saveAccountDetails;

  RequestWithdrawal(
      {required this.accountNumber,
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

part of 'account_bloc.dart';

enum AccountStatus { initialized, loading, success, failure }

class AccountState {
  final EarningsModel? earnings;
  final AccountStatus status;
  final bool isWithdrawRequestActive;
  final WithdrawRequestModel? withdrawRequest;
  final String message;

  AccountState(
      {this.earnings,
      this.status = AccountStatus.initialized,
      this.isWithdrawRequestActive = false,
      this.withdrawRequest,
      this.message = ''});

  AccountState copyWith(
      {EarningsModel? earnings,
      AccountStatus? status,
      bool? isWithdrawRequestActive,
      WithdrawRequestModel? withdrawRequest,
      String? message}) {
    return AccountState(
        earnings: earnings ?? this.earnings,
        status: status ?? this.status,
        isWithdrawRequestActive:
            isWithdrawRequestActive ?? this.isWithdrawRequestActive,
        withdrawRequest: withdrawRequest ?? this.withdrawRequest,
        message: message ?? this.message);
  }

  AccountState clearWihdrawalRequest() {
    return AccountState(
        earnings: earnings,
        status: AccountStatus.success,
        isWithdrawRequestActive: false,
        withdrawRequest: null,
        message: 'Withdrawal request cancelled.');
  }
}

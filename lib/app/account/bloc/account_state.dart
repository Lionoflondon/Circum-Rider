part of 'account_bloc.dart';

enum AccountStatus { initialized, loading, success, failure }

class AccountState {
  final EarningsModel? earnings;
  final AccountStatus status;
  final bool isWithdrawRequestActive;
  final WithdrawRequestModel? withdrawRequest;

  AccountState(
      {this.earnings,
      this.status = AccountStatus.initialized,
      this.isWithdrawRequestActive = false,
      this.withdrawRequest});

  AccountState copyWith(
      {EarningsModel? earnings,
      AccountStatus? status,
      bool? isWithdrawRequestActive,
      WithdrawRequestModel? withdrawRequest}) {
    return AccountState(
        earnings: earnings ?? this.earnings,
        status: status ?? this.status,
        isWithdrawRequestActive:
            isWithdrawRequestActive ?? this.isWithdrawRequestActive,
        withdrawRequest: withdrawRequest ?? this.withdrawRequest);
  }

  AccountState clearWithdrawalRequest() {
    return AccountState(
        earnings: earnings,
        status: status,
        isWithdrawRequestActive: false,
        withdrawRequest: null);
  }
}

part of 'account_bloc.dart';

enum AccountStatus { initialized, loading, success, failure }

class AccountState {
  final EarningsModel? earnings;
  final AccountStatus status;

  AccountState({this.earnings, this.status = AccountStatus.initialized});

  AccountState copyWith({EarningsModel? earnings, AccountStatus? status}) {
    return AccountState(
        earnings: earnings ?? this.earnings, status: status ?? this.status);
  }
}

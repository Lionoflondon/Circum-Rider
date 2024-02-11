part of 'account_bloc.dart';

abstract class AccountEvent {
  const AccountEvent();
}

class GetEarnings extends AccountEvent {}

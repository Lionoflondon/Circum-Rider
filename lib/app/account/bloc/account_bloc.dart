import 'package:circum_rider/app/account/repo/earnings_repo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/earnings.m.dart';

part 'account_event.dart';
part 'account_state.dart';

class AccountBloc extends Bloc<AccountEvent, AccountState> {
  AccountBloc() : super(AccountState()) {
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseFirestore db = FirebaseFirestore.instance;
    User? user = auth.currentUser;
    on<AccountEvent>((event, emit) {
      // TODO: implement event handler
    });

    on<GetEarnings>(
      (event, emit) async {
        try {
          emit(state.copyWith(status: AccountStatus.loading));
          final earningsData =
              await EarningsRepo().fetchEarnings(riderId: user!.uid);
          print(earningsData);
          emit(state.copyWith(earnings: earningsData));
        } catch (e) {
          print('Failed to get earnings, reasons:');
          print(e);
        }
      },
    );
  }
}

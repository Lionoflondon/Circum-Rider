import 'package:circum_rider/app/account/repo/earnings_repo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/earnings.m.dart';
import '../models/withdraw_req.m.dart';

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
          // print(earningsData);
          emit(state.copyWith(
              earnings: earningsData, status: AccountStatus.initialized));
        } catch (e) {
          emit(state.copyWith(status: AccountStatus.failure));
          print('Failed to get earnings, reasons:');
          print(e);
        }
      },
    );

    on<RequestWithdrawal>(
      (event, emit) async {
        emit(state.copyWith(status: AccountStatus.loading));
        try {
          final docRef = db.collection('payoutRequests').doc();
          await docRef.set({
            'sortCode': event.sortCode,
            'accountNumber': event.accountNumber,
            'bankName': event.bankName,
            'amount': event.amount,
            'address': event.address,
            'saveAccountDetails': event.saveAccountDetails,
            'riderId': user!.uid
          });

          emit(state.copyWith(status: AccountStatus.success));
        } catch (e) {
          print(e);
          emit(state.copyWith(status: AccountStatus.failure));
        }
      },
    );

    on<GetRequests>(
      (event, emit) async {
        try {
          // emit(state.copyWith(status: AccountStatus.loading));
          final docRef = db
              .collection('payoutRequests')
              .where('riderId', isEqualTo: user!.uid);
          final docRes = await docRef.get();
          for (final doc in docRes.docs) {
            final data = doc.data();
            final req = WithdrawRequestModel.fromJson(data);
            emit(state.copyWith(
                isWithdrawRequestActive: true, withdrawRequest: req));
            // print(data);
          }
          emit(state.copyWith(status: AccountStatus.initialized));
        } catch (e) {
          print(e);
          emit(state.copyWith(status: AccountStatus.failure));
        }
      },
    );

    on<CancelWithdrawalRequest>(
      (event, emit) async {
        final docRef = db
            .collection('payoutRequests')
            .where('riderId', isEqualTo: user!.uid);

        final docRes = await docRef.get();

        final doc = docRes.docs.firstOrNull;

        if (doc != null) {
          await db.collection('payoutRequests').doc(doc.id).delete();
          emit(state.clearWihdrawalRequest());
        }
      },
    );

    on<ResetAccountStatus>(
      (event, emit) {
        emit(state.copyWith(status: event.status));
      },
    );
  }
}

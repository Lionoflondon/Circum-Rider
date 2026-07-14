import 'package:circum_rider/app/account/repo/earnings_repo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
    on<GetEarnings>(
      (event, emit) async {
        try {
          emit(state.copyWith(status: AccountStatus.loading));
          final earningsData =
              await EarningsRepo().fetchEarnings(riderId: user!.uid);
          emit(state.copyWith(
              earnings: earningsData, status: AccountStatus.initialized));
        } catch (_) {
          emit(state.copyWith(status: AccountStatus.failure));
        }
      },
    );

    on<RequestWithdrawal>(
      (event, emit) async {
        emit(state.copyWith(status: AccountStatus.loading));
        try {
          final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('requestRiderWithdrawal');
          final response = await callable.call({
            'amount': double.parse(event.amount),
          });
          final data = Map<String, dynamic>.from(response.data as Map);
          final request = WithdrawRequestModel(
            accountNumber: '',
            bankName: 'Stripe Connect',
            amount: '${data['amount'] ?? event.amount}',
            saveAccountDetails: false,
            riderId: user!.uid,
          );
          emit(state.copyWith(
            status: AccountStatus.success,
            isWithdrawRequestActive: true,
            withdrawRequest: request,
          ));
        } catch (_) {
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
            final status =
                '${data['status'] ?? data['payoutStatus'] ?? ''}'.toLowerCase();
            if (!{'requested', 'pending', 'approved', 'processing'}
                .contains(status)) {
              continue;
            }
            final req = WithdrawRequestModel.fromJson(data);
            emit(state.copyWith(
                isWithdrawRequestActive: true, withdrawRequest: req));
          }
          emit(state.copyWith(status: AccountStatus.initialized));
        } catch (_) {
          emit(state.copyWith(status: AccountStatus.failure));
        }
      },
    );

    on<CancelWithdrawalRequest>(
      (event, emit) async {
        emit(state.copyWith(status: AccountStatus.loading));
        try {
          final docRef = db
              .collection('payoutRequests')
              .where('riderId', isEqualTo: user!.uid);

          final docRes = await docRef.get();

          final doc = docRes.docs.firstOrNull;

          if (doc != null) {
            await FirebaseFunctions.instanceFor(region: 'us-central1')
                .httpsCallable('cancelRiderWithdrawal')
                .call({'requestId': doc.id});
            emit(state.clearWihdrawalRequest());
          } else {
            emit(state.copyWith(status: AccountStatus.initialized));
          }
        } catch (_) {
          emit(state.copyWith(status: AccountStatus.failure));
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

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
    const operationTimeout = Duration(seconds: 25);
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseFirestore db = FirebaseFirestore.instance;
    String requireUid() {
      final uid = auth.currentUser?.uid;
      if (uid == null) throw StateError('signed_out');
      return uid;
    }

    on<GetEarnings>(
      (event, emit) async {
        try {
          emit(state.copyWith(status: AccountStatus.loading, message: ''));
          final earningsData = await EarningsRepo()
              .fetchEarnings(riderId: requireUid())
              .timeout(operationTimeout);
          emit(state.copyWith(
              earnings: earningsData, status: AccountStatus.initialized));
        } catch (_) {
          emit(state.copyWith(
            status: AccountStatus.failure,
            message:
                'Earnings could not be loaded. Check your connection and retry.',
          ));
        }
      },
    );

    on<RequestWithdrawal>(
      (event, emit) async {
        emit(state.copyWith(status: AccountStatus.loading, message: ''));
        try {
          final uid = requireUid();
          final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('requestRiderWithdrawal');
          final response = await callable.call(
              {'amount': double.parse(event.amount)}).timeout(operationTimeout);
          final data = Map<String, dynamic>.from(response.data as Map);
          final request = WithdrawRequestModel(
            accountNumber: '',
            bankName: 'Stripe Connect',
            amount: '${data['amount'] ?? event.amount}',
            saveAccountDetails: false,
            riderId: uid,
          );
          emit(state.copyWith(
            status: AccountStatus.success,
            message: 'Withdrawal request submitted.',
            isWithdrawRequestActive: true,
            withdrawRequest: request,
          ));
        } catch (_) {
          emit(state.copyWith(
            status: AccountStatus.failure,
            message:
                'Withdrawal could not be requested. Check your payout account and retry.',
          ));
        }
      },
    );

    on<GetRequests>(
      (event, emit) async {
        try {
          final uid = requireUid();
          // emit(state.copyWith(status: AccountStatus.loading));
          final docRef =
              db.collection('payoutRequests').where('riderId', isEqualTo: uid);
          final docRes = await docRef.get().timeout(operationTimeout);
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
          emit(state.copyWith(
            status: AccountStatus.failure,
            message:
                'Payout history could not be loaded. Check your connection and retry.',
          ));
        }
      },
    );

    on<CancelWithdrawalRequest>(
      (event, emit) async {
        emit(state.copyWith(status: AccountStatus.loading, message: ''));
        try {
          final uid = requireUid();
          final docRef =
              db.collection('payoutRequests').where('riderId', isEqualTo: uid);

          final docRes = await docRef.get().timeout(operationTimeout);

          final doc = docRes.docs.firstOrNull;

          if (doc != null) {
            await FirebaseFunctions.instanceFor(region: 'us-central1')
                .httpsCallable('cancelRiderWithdrawal')
                .call({'requestId': doc.id}).timeout(operationTimeout);
            emit(state.clearWihdrawalRequest());
          } else {
            emit(state.copyWith(status: AccountStatus.initialized));
          }
        } catch (_) {
          emit(state.copyWith(
            status: AccountStatus.failure,
            message:
                'Withdrawal cancellation could not be completed. Try again.',
          ));
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

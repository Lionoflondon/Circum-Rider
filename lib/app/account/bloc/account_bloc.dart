import 'package:circum_rider/app/account/repo/earnings_repo.dart';
import 'package:circum_rider/app/stripe/rider_production_payment_api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/earnings.m.dart';
import '../models/withdraw_req.m.dart';

part 'account_event.dart';
part 'account_state.dart';

class AccountBloc extends Bloc<AccountEvent, AccountState> {
  AccountBloc(
      {FirebaseAuth? authentication,
      FirebaseFirestore? firestore,
      Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
          payout})
      : super(AccountState()) {
    final callPayout = payout ?? RiderProductionPaymentApi.payout;
    var earningsGeneration = 0;
    var financialInFlight = false;
    var payoutGeneration = 0;
    const operationTimeout = Duration(seconds: 25);
    FirebaseAuth auth = authentication ?? FirebaseAuth.instance;
    FirebaseFirestore db = firestore ?? FirebaseFirestore.instance;
    String requireUid() {
      final uid = auth.currentUser?.uid;
      if (uid == null) throw StateError('signed_out');
      return uid;
    }

    on<GetEarnings>(
      (event, emit) async {
        final operation = ++earningsGeneration;
        final initiatingUid = auth.currentUser?.uid;
        try {
          emit(state.copyWith(status: AccountStatus.loading, message: ''));
          final earningsData = await EarningsRepo()
              .fetchEarnings(riderId: requireUid())
              .timeout(operationTimeout);
          if (operation != earningsGeneration ||
              auth.currentUser?.uid != initiatingUid) return;
          emit(state.copyWith(
              earnings: earningsData, status: AccountStatus.initialized));
        } catch (_) {
          if (operation != earningsGeneration ||
              auth.currentUser?.uid != initiatingUid) return;
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
        if (financialInFlight) return;
        financialInFlight = true;
        ++payoutGeneration;
        final initiatingUid = auth.currentUser?.uid;
        emit(state.copyWith(status: AccountStatus.loading, message: ''));
        try {
          final uid = requireUid();
          final data = await callPayout(
            'requestRiderWithdrawal',
            {'amount': double.parse(event.amount)},
          ).timeout(operationTimeout);
          if (auth.currentUser?.uid != initiatingUid) return;
          final request = WithdrawRequestModel(
            accountNumber: '',
            bankName: 'Stripe Connect',
            amount: '${data['amount'] ?? event.amount}',
            saveAccountDetails: false,
            riderId: uid,
            requestId: data['requestId']?.toString(),
          );
          emit(state.copyWith(
            status: AccountStatus.success,
            message: 'Withdrawal request submitted.',
            isWithdrawRequestActive: true,
            withdrawRequest: request,
          ));
        } catch (_) {
          if (auth.currentUser?.uid != initiatingUid) return;
          emit(state.copyWith(
            status: AccountStatus.failure,
            message:
                'Withdrawal could not be requested. Check your payout account and retry.',
          ));
        } finally {
          financialInFlight = false;
          add(GetRequests());
        }
      },
    );

    on<GetRequests>(
      (event, emit) async {
        if (financialInFlight) return;
        final generation = ++payoutGeneration;
        final initiatingUid = auth.currentUser?.uid;
        try {
          final uid = requireUid();
          // emit(state.copyWith(status: AccountStatus.loading));
          final docRef =
              db.collection('payoutRequests').where('riderId', isEqualTo: uid);
          final docRes = await docRef.get().timeout(operationTimeout);
          if (generation != payoutGeneration ||
              auth.currentUser?.uid != initiatingUid) return;
          emit(AccountState(earnings: state.earnings));
          final documents = [...docRes.docs]..sort((a, b) {
              final first = a.data()['createdAt'];
              final second = b.data()['createdAt'];
              return (second is Timestamp ? second.millisecondsSinceEpoch : 0)
                  .compareTo(
                      first is Timestamp ? first.millisecondsSinceEpoch : 0);
            });
          for (final doc in documents) {
            final data = doc.data();
            final status =
                '${data['status'] ?? data['payoutStatus'] ?? ''}'.toLowerCase();
            if (!{'requested', 'pending', 'approved', 'processing'}
                .contains(status)) {
              continue;
            }
            final req = WithdrawRequestModel.fromJson({...data, 'id': doc.id});
            emit(state.copyWith(
                isWithdrawRequestActive: true, withdrawRequest: req));
            break;
          }
          emit(state.copyWith(status: AccountStatus.initialized));
        } catch (_) {
          if (generation != payoutGeneration ||
              auth.currentUser?.uid != initiatingUid) return;
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
        if (financialInFlight) return;
        financialInFlight = true;
        ++payoutGeneration;
        final initiatingUid = auth.currentUser?.uid;
        final selectedId = event.requestId ?? state.withdrawRequest?.requestId;
        emit(state.copyWith(status: AccountStatus.loading, message: ''));
        try {
          requireUid();
          final requestId = selectedId;
          if (requestId == null || requestId.isEmpty)
            throw StateError('No active withdrawal selected.');
          await callPayout('cancelRiderWithdrawal', {'requestId': requestId})
              .timeout(operationTimeout);
          if (auth.currentUser?.uid != initiatingUid) return;
          emit(state.clearWihdrawalRequest());
        } catch (_) {
          if (auth.currentUser?.uid != initiatingUid) return;
          emit(state.copyWith(
            status: AccountStatus.failure,
            message:
                'Withdrawal cancellation could not be completed. Try again.',
          ));
        } finally {
          financialInFlight = false;
          add(GetRequests());
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

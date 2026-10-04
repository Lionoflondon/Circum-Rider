import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../home/models/dispatch_request.m..dart';
part 'history_event.dart';
part 'history_state.dart';

class RiderHistoryPage {
  const RiderHistoryPage(this.rows, this.cursor, this.hasMore);
  final List<DispatchRequest> rows;
  final Object? cursor;
  final bool hasMore;
}

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  StreamSubscription<User?>? _sessionSubscription;
  HistoryBloc(
      {String? Function()? userId,
      Future<RiderHistoryPage> Function(String, bool, Object?)? loadPage})
      : super(HistoryState()) {
    final auth = userId == null ? FirebaseAuth.instance : null;
    final currentUid = userId ?? () => auth!.currentUser?.uid;
    final load = loadPage ??
        (String uid, bool descending, Object? cursor) async {
          Query<Map<String, dynamic>> query = FirebaseFirestore.instance
              .collection('history')
              .where('riderId', isEqualTo: uid)
              .orderBy('createdAt', descending: descending)
              .limit(40);
          if (cursor is DocumentSnapshot<Map<String, dynamic>>)
            query = query.startAfterDocument(cursor);
          final result = await query.get().timeout(const Duration(seconds: 25));
          return RiderHistoryPage(
              result.docs
                  .map((doc) => DispatchRequest.fromJson(doc.data()))
                  .toList(),
              result.docs.isEmpty ? null : result.docs.last,
              result.docs.length == 40);
        };
    Object? cursor;
    var generation = 0;
    String? queryUid;
    bool? queryDescending;
    on<_ResetHistory>((event, emit) {
      generation++;
      cursor = null;
      queryUid = null;
      queryDescending = null;
      emit(HistoryState());
    });
    _sessionSubscription = auth?.authStateChanges().listen((_) {
      if (!isClosed && queryUid != currentUid()) add(const _ResetHistory());
    });
    on<FetchHistory>((event, emit) async {
      final uid = currentUid();
      final append = event.loadMore &&
          queryUid == uid &&
          queryDescending == event.descending;
      if (append && state.loading) return;
      final operation = ++generation;
      if (!append) cursor = null;
      final prior = queryUid == uid ? state.ridesHistory : <DispatchRequest>[];
      queryUid = uid;
      queryDescending = event.descending;
      emit(HistoryState(ridesHistory: prior, loading: true));
      try {
        if (uid == null) throw StateError('signed_out');
        final result =
            await load(uid, event.descending, append ? cursor : null);
        if (operation != generation || currentUid() != uid) return;
        cursor = result.cursor;
        final merged = <String, DispatchRequest>{
          if (append)
            for (final row in prior) row.requestId: row,
          for (final row in result.rows) row.requestId: row,
        };
        emit(HistoryState(
            ridesHistory: merged.values.toList(), hasMore: result.hasMore));
      } catch (_) {
        if (operation != generation || currentUid() != uid) return;
        emit(HistoryState(
            ridesHistory: prior,
            loading: false,
            error:
                'History could not be loaded. Check your connection and retry.'));
      }
    });
  }
  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    return super.close();
  }
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/history/bloc/history_bloc.dart';
import 'package:circum_rider/app/home/models/dispatch_request.m..dart';

class _Row implements DispatchRequest {
  _Row(this.requestId);
  @override
  final String requestId;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  test(
      'refresh replaces in-flight older response and pagination deduplicates IDs',
      () async {
    final pending = <Completer<RiderHistoryPage>>[];
    final cursors = <Object?>[];
    final bloc = HistoryBloc(
        userId: () => 'rider',
        loadPage: (uid, descending, cursor) {
          cursors.add(cursor);
          final result = Completer<RiderHistoryPage>();
          pending.add(result);
          return result.future;
        });
    bloc.add(FetchHistory(descending: true));
    await tick();
    bloc.add(FetchHistory(descending: true));
    await tick();
    pending[1].complete(RiderHistoryPage([_Row('new')], 'new-cursor', true));
    await tick();
    pending[0]
        .complete(RiderHistoryPage([_Row('stale')], 'stale-cursor', true));
    await tick();
    expect(bloc.state.ridesHistory.map((r) => r.requestId), ['new']);
    bloc.add(FetchHistory(descending: true, loadMore: true));
    await tick();
    expect(cursors.last, 'new-cursor');
    pending[2].complete(
        RiderHistoryPage([_Row('new'), _Row('older')], 'older-cursor', false));
    await tick();
    expect(bloc.state.ridesHistory.map((r) => r.requestId), ['new', 'older']);
    await bloc.close();
  });
  test(
      'sort and empty refresh reset cursor and account changes reject stale data',
      () async {
    var uid = 'first';
    final pending = <Completer<RiderHistoryPage>>[];
    final cursors = <Object?>[];
    final bloc = HistoryBloc(
        userId: () => uid,
        loadPage: (id, order, cursor) {
          cursors.add(cursor);
          final result = Completer<RiderHistoryPage>();
          pending.add(result);
          return result.future;
        });
    bloc.add(FetchHistory(descending: true));
    await tick();
    pending[0].complete(RiderHistoryPage([_Row('old')], 'old-cursor', true));
    await tick();
    bloc.add(FetchHistory(descending: false));
    await tick();
    expect(cursors.last, isNull);
    pending[1].complete(const RiderHistoryPage([], null, false));
    await tick();
    bloc.add(FetchHistory(descending: false, loadMore: true));
    await tick();
    expect(cursors.last, isNull);
    uid = 'second';
    pending[2].complete(RiderHistoryPage([_Row('private-first')], null, false));
    await tick();
    expect(bloc.state.ridesHistory, isEmpty);
    await bloc.close();
  });
}

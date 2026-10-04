part of 'history_bloc.dart';

abstract class HistoryEvent {
  const HistoryEvent();
}

class FetchHistory extends HistoryEvent {
  bool descending;
  final bool loadMore;
  FetchHistory({required this.descending, this.loadMore = false});
}

class _ResetHistory extends HistoryEvent {
  const _ResetHistory();
}

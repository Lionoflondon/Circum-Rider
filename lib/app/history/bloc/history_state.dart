part of 'history_bloc.dart';

class HistoryState {
  final List<DispatchRequest> ridesHistory;
  final bool loading, hasMore;
  final String? error;
  HistoryState(
      {this.ridesHistory = const [],
      this.loading = false,
      this.hasMore = true,
      this.error});
  HistoryState copyWith(
          {List<DispatchRequest>? ridesHistory,
          bool? loading,
          bool? hasMore,
          String? error}) =>
      HistoryState(
          ridesHistory: ridesHistory ?? this.ridesHistory,
          loading: loading ?? this.loading,
          hasMore: hasMore ?? this.hasMore,
          error: error);
}

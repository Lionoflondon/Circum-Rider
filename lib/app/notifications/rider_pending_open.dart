import 'dart:async';
import 'dart:convert';

/// Account-scoped, bounded notification inbox. Stored payloads must use an
/// encrypted store; opening a target must still validate server ownership.
class RiderPendingOpen<T> {
  RiderPendingOpen(
      {required this.ready,
      required this.account,
      required this.open,
      this.interval = const Duration(seconds: 1),
      this.onError,
      this.read,
      this.write,
      this.encode,
      this.decode});
  final bool Function() ready;
  final String? Function() account;
  final Future<void> Function(T) open;
  final Duration interval;
  final void Function(Object)? onError;
  final Future<String?> Function()? read;
  final Future<void> Function(String)? write;
  final Object? Function(T)? encode;
  final T Function(Object?)? decode;
  final List<({T value, String? account, DateTime time})> _pending = [];
  Timer? _timer;
  bool _draining = false;
  Future<void>? _restore;
  Future<void> _storage = Future<void>.value();

  Future<void> restore() => _restore ??= _load();

  Future<void> _load() async {
    try {
      final raw = await read?.call();
      if (raw != null && decode != null) {
        for (final entry in (jsonDecode(raw) as List).take(20)) {
          final time =
              DateTime.fromMillisecondsSinceEpoch(entry['time'] as int);
          if (DateTime.now().difference(time).abs() > const Duration(hours: 24))
            continue;
          _pending.add((
            value: decode!(entry['value']),
            account: entry['account'] as String?,
            time: time
          ));
        }
      }
    } catch (error) {
      onError?.call(error);
    }
    if (_pending.isNotEmpty) _ensureTimer();
  }

  Future<void> _save() {
    if (write == null || encode == null) return Future<void>.value();
    final value = jsonEncode(_pending
        .map((entry) => {
              'value': encode!(entry.value),
              'account': entry.account,
              'time': entry.time.millisecondsSinceEpoch,
            })
        .toList());
    _storage = _storage.then((_) => write!(value)).catchError((Object error) {
      onError?.call(error);
    });
    return _storage;
  }

  void _ensureTimer() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(drain()));
  }

  Future<void> add(T value) async {
    final owner = account();
    await restore();
    _pending.add((value: value, account: owner, time: DateTime.now()));
    if (_pending.length > 20) {
      _pending.removeAt(0);
      onError?.call(StateError('Pending notification inbox reached capacity'));
    }
    await _save();
    _ensureTimer();
    await drain();
  }

  Future<void> drain() async {
    await restore();
    if (_draining || !ready() || account() == null) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty && ready() && account() != null) {
        final next = _pending.first;
        if ((next.account != null && next.account != account()) ||
            DateTime.now().difference(next.time).abs() >
                const Duration(hours: 24)) {
          _pending.removeAt(0);
          await _save();
          continue;
        }
        try {
          await open(next.value);
        } catch (error) {
          onError?.call(error);
          return;
        }
        _pending.removeAt(0);
        await _save();
      }
    } finally {
      _draining = false;
      if (_pending.isEmpty) {
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

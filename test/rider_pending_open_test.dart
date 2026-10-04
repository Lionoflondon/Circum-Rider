import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/notifications/rider_pending_open.dart';

void main() {
  test('tap survives unavailable navigation and waits for authentication',
      () async {
    var ready = false;
    String? account;
    final opened = <String>[];
    final pending = RiderPendingOpen<String>(
        ready: () => ready,
        account: () => account,
        open: (value) async => opened.add(value));
    addTearDown(pending.dispose);
    await pending.add('offer-1');
    await pending.drain();
    ready = true;
    await pending.drain();
    expect(opened, isEmpty);
    account = 'rider-a';
    await pending.drain();
    expect(opened, ['offer-1']);
    await pending.drain();
    expect(opened, ['offer-1']);
  });
  test('tap captured by one account is discarded after an account switch',
      () async {
    var ready = false;
    var account = 'a';
    final opened = <String>[];
    final pending = RiderPendingOpen<String>(
        ready: () => ready,
        account: () => account,
        open: (value) async => opened.add(value));
    addTearDown(pending.dispose);
    await pending.add('private-offer');
    account = 'b';
    ready = true;
    await pending.drain();
    expect(opened, isEmpty);
  });
  test('encrypted-store replay survives restart and is consumed once',
      () async {
    String? disk;
    final opened = <String>[];
    RiderPendingOpen<String> make(bool ready) => RiderPendingOpen<String>(
        ready: () => ready,
        account: () => 'rider-a',
        open: (value) async => opened.add(value),
        read: () async => disk,
        write: (value) async {
          disk = value;
        },
        encode: (value) => value,
        decode: (value) => value as String);
    final first = make(false);
    await first.add('offer-restart');
    first.dispose();
    final restarted = make(true);
    addTearDown(restarted.dispose);
    await restarted.drain();
    expect(opened, ['offer-restart']);
    final again = make(true);
    addTearDown(again.dispose);
    await again.drain();
    expect(opened, ['offer-restart']);
  });
  test('failed navigation retains the target for retry', () async {
    var fail = true;
    var attempts = 0;
    var errors = 0;
    final pending = RiderPendingOpen<String>(
        ready: () => true,
        account: () => 'a',
        open: (_) async {
          attempts++;
          if (fail) throw StateError('not ready');
        },
        onError: (_) {
          errors++;
        });
    addTearDown(pending.dispose);
    await pending.add('offer');
    expect(errors, 1);
    fail = false;
    await pending.drain();
    expect(attempts, 2);
    await pending.drain();
    expect(attempts, 2);
  });
}

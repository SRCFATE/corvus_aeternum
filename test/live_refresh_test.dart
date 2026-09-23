import 'dart:async';

import 'package:corvus_aeternum/core/live_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('events during a refresh wait and disposal cancels pending work',
      (tester) async {
    final changes = StreamController<void>.broadcast();
    final first = Completer<void>();
    var calls = 0;
    final live = LiveRefresh(changes.stream, () async {
      calls++;
      if (calls == 1) await first.future;
    });
    changes.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(calls, 1);
    for (var i = 0; i < 10; i++) {
      changes.add(null);
    }
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 1);
    first.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(calls, 2);
    changes.add(null);
    await tester.pump();
    live.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 2);
    expect(changes.hasListener, isFalse);
    await changes.close();
  });
}

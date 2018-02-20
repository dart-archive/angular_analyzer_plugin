import 'dart:async';

import 'package:test/test.dart';
import 'case.dart';
import 'producer.dart';

abstract class FuzzTestMixin {
  final FuzzCaseProducer fuzzProducer = new FuzzCaseProducer();

  /// How to get a test case -- completion fuzzing overrides this.
  FuzzCase get nextCase => fuzzProducer.nextCase;

  // ignore: non_constant_identifier_names
  Future test_fuzz_continually() async {
    const iters = 1000000;
    for (var i = 0; i < iters; ++i) {
      final nextCase = fuzzProducer.nextCase;
      print("Fuzz $i: ${nextCase.transformCount} transforms");
      await checkNoCrash(nextCase);
    }
  }

  /// What to do for each fuzz case in attempt to produce a crash
  Future perform(FuzzCase fuzzCase);

  /// What to do before each testCase
  dynamic setUp();

  Future checkNoCrash(FuzzCase fuzzCase) {
    final zoneCompleter = new Completer<Null>();
    var complete = false;
    final reason =
        '<<==DART CODE==>>\n${fuzzCase.dart}\n<<==HTML CODE==>>\n${fuzzCase.html}\n<<==DONE==>>';

    runZoned(() {
      setUp();
      final resultFuture = perform(fuzzCase);
      Future.wait([resultFuture]).then((_) {
        zoneCompleter.complete();
        complete = true;
      });
    }, onError: (e, stacktrace) {
      print("Fuzz Failure \n$reason\n$e\n$stacktrace");
      if (!complete) {
        zoneCompleter.complete();
        complete = true;
      }
    });

    return zoneCompleter.future;
  }
}

/// More or less expect(), but without failing the test. Returns a [Future] so
/// that you can chain things to do when this succeeds or fails.
Future check(Object actual, Matcher matcher, {String reason}) {
  final matchState = {};

  print('failed');
  final description = new StringDescription();
  description.add('Expected: ').addDescriptionOf(matcher).add('\n');
  description.add('  Actual: ').addDescriptionOf(actual).add('\n');

  final mismatchDescription = new StringDescription();
  matcher.describeMismatch(actual, mismatchDescription, matchState, false);

  if (mismatchDescription.length > 0) {
    description.add('   Which: $mismatchDescription\n');
  }
  if (reason != null) {
    description.add(reason).add('\n');
  }

  print(description.toString());
  return new Future.error(description);
}

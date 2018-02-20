import 'dart:async';

import 'completion_contributor_test_util.dart';
import 'fuzz_util.dart';

void main() {
  new CompletionFuzzTest().test_fuzz_continually();
}

//@reflectiveTest
class CompletionFuzzTest extends AbstractCompletionContributorTest {
  final FuzzCaseProducer fuzzProducer = new FuzzCaseProducer();

  @override
  void setUp() {
    testFile = '/test.html';
    super.setUp();
  }

  // ignore: non_constant_identifier_names
  Future test_fuzz_continually() async {
    const iters = 1000000;
    for (var i = 0; i < iters; ++i) {
      final rawCase = fuzzProducer.nextCase;
      final completionOffset = fuzzProducer.randomPos(rawCase.html);
      final nextCase = new FuzzCase(rawCase.transformCount, rawCase.dart,
          rawCase.html.replaceRange(completionOffset, completionOffset, '^'));
      print("Fuzz $i: ${nextCase.transformCount} transforms");
      await checkNoCrash(nextCase.dart, nextCase.html);
    }
  }

  Future checkNoCrash(String dart, String html) {
    final zoneCompleter = new Completer<Null>();
    var complete = false;
    final reason =
        '<<==DART CODE==>>\n$dart\n<<==HTML CODE==>>\n$html\n<<==DONE==>>';

    runZoned(() {
      setUp();
      final dartSource = newSource('/test.dart', dart);
      addTestSource(html, skipExpects: true);
      final resultFuture = resolveSingleTemplate(dartSource).then((result) {
        if (result != null) {
          computeSuggestions(skipExpects: true);
        }
      });
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

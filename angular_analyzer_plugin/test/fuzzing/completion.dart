import 'dart:async';

import '../completion_contributor_test_util.dart';
import 'base.dart';
import 'case.dart';
import 'producer.dart';

class CompletionFuzzTest extends AbstractCompletionContributorTest
    implements Fuzzable {
  @override
  void setUp() {
    testFile = '/test.html';
    super.setUp();
  }

  @override
  FuzzCase getNextCase(FuzzCaseProducer fuzzProducer) {
    final rawCase = fuzzProducer.nextCase;
    final completionOffset = fuzzProducer.randomPos(rawCase.html);
    return new FuzzCase(rawCase.seed, rawCase.transformCount, rawCase.dart,
        rawCase.html.replaceRange(completionOffset, completionOffset, '^'));
  }

  @override
  Future perform(FuzzCase fuzzCase) async {
    final dartSource = newSource('/test.dart', fuzzCase.dart);
    addTestSource(fuzzCase.html, skipExpects: true);
    final result = await resolveSingleTemplate(dartSource);
    if (result != null) {
      await computeSuggestions(skipExpects: true);
    }
  }
}

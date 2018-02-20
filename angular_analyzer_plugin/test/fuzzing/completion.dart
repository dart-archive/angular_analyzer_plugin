import 'dart:async';

import '../completion_contributor_test_util.dart';
import 'base.dart';
import 'case.dart';

void main() {
  new CompletionFuzzTest().test_fuzz_continually();
}

class CompletionFuzzTest extends AbstractCompletionContributorTest
    with FuzzTestMixin {
  @override
  void setUp() {
    testFile = '/test.html';
    super.setUp();
  }

  @override
  FuzzCase get nextCase {
    final rawCase = fuzzProducer.nextCase;
    final completionOffset = fuzzProducer.randomPos(rawCase.html);
    return new FuzzCase(rawCase.transformCount, rawCase.dart,
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

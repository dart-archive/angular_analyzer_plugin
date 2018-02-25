import 'dart:async';

import 'package:angular_analyzer_plugin/src/model.dart';

import '../abstract_angular.dart';
import 'base.dart';
import 'case.dart';
import 'producer.dart';

class AnalysisFuzzTest extends AbstractAngularTest implements Fuzzable {
  @override
  FuzzCase getNextCase(FuzzCaseProducer producer) => producer.nextCase;

  @override
  Future perform(FuzzCase fuzzCase) async {
    newSource('/test.dart', fuzzCase.dart);
    newSource('/test.html', fuzzCase.html);
    final result = await angularDriver.resolveDart('/test.dart');
    if (result.directives.isNotEmpty) {
      final directive = result.directives.first;
      if (directive is Component &&
          directive.view?.templateUriSource?.fullName == '/test.html') {
        return angularDriver.resolveHtml('/test.html');
      }
    }
  }
}

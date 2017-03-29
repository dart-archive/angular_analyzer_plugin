import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/tasks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';
import 'package:analyzer/task/dart.dart';
import 'package:angular_analyzer_plugin/ast.dart';

import 'abstract_angular.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(ConverterTest);
}

@reflectiveTest
class ConverterTest extends AbstractAngularTest {
  String dartCode;
  String htmlCode;
  Source dartSource;
  Source htmlSource;

  List<AbstractDirective> directives;

  Template template;
  List<ResolvedRange> ranges;

  void test_scratch() {
    _addDartSource(r'''
@Component(
    externalselector: 'my-aaa',
    templateUrl: 'test_panel.html',
    directives: const [CounterComponent, NgIf, NgFor, NgForm, NgModel])
class ComponentA {
  List<String> items;
  String header;
}

@Component(
    selector: 'my-counter',
    inputs: const ['count'],
    outputs: const ['resetEvent: reset'],
    template: '{{count}} <button (click)="increment()" [value2/angular2.dart';

    @Component(
    selector: 'my-aaa',
    templateUrl: 'test_panel.html',
    directives: const [CounterComponent, NgIf, NgFor, NgForm, NgModel])class ComponentA {
  List<String> items;
  String header;
}

@Component(
    selector: 'my-counter',
    inputs: const ['count'],
    outputs: const ['resetEvent: reset'],
    template: '{{count}} <but]="\'add\'"></button>')
class CounterComponent {
  int count;
  @Input() int maxCount;
  EventEmitter<String> resetEvent;
  @Output() EventEmitter<
''');
    _addHtmlSource(r"""
(click)=t'h1.hidden = !h1.hidden; counter.resedt()'  <my-counter
        }
        ]),
        });
        {
        \'\'\');
'090cedb3f2833a3f260b    (ien = !h1.hidden; countncremented)
""");
    _resolveSingleTemplate(dartSource);
    var template = outputs[HTML_TEMPLATE];
  }

  void _addDartSource(String code) {
    dartCode = '''
import '/angular2/angular2.dart';
$code
''';
    dartSource = newSource('/test_panel.dart', dartCode);
  }

  void _addHtmlSource(String code) {
    htmlCode = code;
    htmlSource = newSource('/test_panel.html', htmlCode);
  }

  void _resolveSingleTemplate(Source dartSource) {
    directives = computeLibraryDirectives(dartSource);
    List<View> views = computeLibraryViews(dartSource);
    View view = views.last;
    // resolve this View
    computeResult(view, HTML_TEMPLATE);
    template = outputs[HTML_TEMPLATE];
    ranges = template.ranges;
    fillErrorListener(HTML_TEMPLATE_ERRORS);
  }

  ResolvedRange _findResolvedRange(String search,
      [ResolvedRangeCondition condition]) {
    return getResolvedRangeAtString(htmlCode, ranges, search, condition);
  }
}

import 'package:analysis_server/plugin/analysis/navigation/navigation_core.dart';
import 'package:analysis_server/plugin/analysis/occurrences/occurrences_core.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as protocol;
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/navigation.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'abstract_angular.dart';

void main() {
  defineReflectiveSuite(() {
    // TODO get these working again in the latest SDK
    //defineReflectiveTests(AngularNavigationContributorTest);
    //defineReflectiveTests(AngularOccurrencesContributorTest);
    defineReflectiveTests(EmptyTest);
  });
}

@reflectiveTest
class EmptyTest {
  // ignore: non_constant_identifier_names
  void test_soTheSuitePasses() {
    expect(null, isNull);
  }
}

@reflectiveTest
class AngularNavigationContributorTest extends AbstractAngularTest {
  String code;

  List<_RecordedNavigationRegion> regions = <_RecordedNavigationRegion>[];
  NavigationCollector collector = new NavigationCollectorMock();

  _RecordedNavigationRegion region;
  protocol.Location targetLocation;

  @override
  void setUp() {
    super.setUp();
    when(collector.addRegion(
        argThat(const isInstanceOf<int>()),
        argThat(const isInstanceOf<int>()),
        typed(any),
        typed(any))).thenAnswer((invocation) {
      final offset = invocation.positionalArguments[0] as int;
      final length = invocation.positionalArguments[1] as int;
      final targetKind = invocation.positionalArguments[2];
      final targetLocation = invocation.positionalArguments[3];
      regions.add(new _RecordedNavigationRegion(
          offset, length, targetKind, targetLocation));
    });
  }

  // ignore: non_constant_identifier_names
  void test_dart_templates() {
    code = r'''
import '/angular2/src/core/metadata.dart';

@Component(selector: 'text-panel', inputs: const ['text: my-text'])
@View(template: r"<div>some text</div>")
class TextPanel {
  String text; // 1
  @Input() longform; // 4
}

@Component(selector: 'UserPanel')
@View(template: r"""
<div>
  <text-panel [my-text]='user.name' [longform]='""'></text-panel> // close
</div>
""", directives: [TextPanel])
class UserPanel {
  User user; // 2
}

class User {
  String name; // 3
}
''';
    final source = newSource('/test.dart', code);
    //LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    //computeResult(target, DART_TEMPLATES);
    // compute navigation regions
    new AngularNavigationContributor()
        .computeNavigation(collector, source, null, null);
    // input references setter
    {
      _findRegionString('text', ': my-text');
      expect(region.targetKind, protocol.ElementKind.SETTER);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf('text; // 1'));
    }
    // template references component (open tag)
    {
      _findRegionString('text-panel', ' [my-text]');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("text-panel', inputs"));
    }
    // template references component (close tag)
    {
      _findRegionString('text-panel', '> // close');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("text-panel', inputs"));
    }
    // template references input
    {
      _findRegionString('my-text', ']=');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("my-text'])"));
    }
    // template references field
    {
      _findRegionString('user', ".name' ");
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("user; // 2"));
    }
    // template references field
    {
      _findRegionString('name', "' [");
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("name; // 3"));
    }
    // template references input
    {
      _findRegionString('longform', ']=');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("longform; // 4"));
    }
  }

  // ignore: non_constant_identifier_names
  void test_dart_view_templateUrl() {
    code = r'''
import '/angular2/src/core/metadata.dart';

@Component(selector: 'text-panel')
@View(templateUrl: 'text_panel.html')
class TextPanel {}
''';
    final dartSource = newSource('/test.dart', code);
    newSource('/text_panel.html', "");
    // compute views, so that we have the TEMPLATE_VIEWS result
    //{
    //  LibrarySpecificUnit target =
    //      new LibrarySpecificUnit(dartSource, dartSource);
    //  computeResult(target, VIEWS_WITH_HTML_TEMPLATES2);
    //}
    //// compute Angular templates
    //computeResult(htmlSource, HTML_TEMPLATES);
    // compute navigation regions
    new AngularNavigationContributor()
        .computeNavigation(collector, dartSource, null, null);
    // input references setter
    {
      _findRegionString("'text_panel.html'", ')');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/text_panel.html');
      expect(targetLocation.offset, 0);
    }
  }

  // ignore: non_constant_identifier_names
  void test_html_templates() {
    final dartCode = r'''
import '/angular2/src/core/metadata.dart';

@Component(selector: 'text-panel')
@View(templateUrl: 'text_panel.html')
class TextPanel {
  String text; // 1
}
''';
    final htmlCode = r"""
<div>
  {{text}}
</div>
""";
    newSource('/test.dart', dartCode);
    final htmlSource = newSource('/text_panel.html', htmlCode);
    // compute views, so that we have the TEMPLATE_VIEWS result
    //{
    //  LibrarySpecificUnit target =
    //      new LibrarySpecificUnit(dartSource, dartSource);
    //  computeResult(target, VIEWS_WITH_HTML_TEMPLATES2);
    //}
    //// compute Angular templates
    //computeResult(htmlSource, HTML_TEMPLATES);
    // compute navigation regions
    new AngularNavigationContributor()
        .computeNavigation(collector, htmlSource, null, null);
    // template references field
    {
      _findRegionString('text', "}}", codeOverride: htmlCode);
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, dartCode.indexOf("text; // 1"));
    }
  }

  void _findRegion(int offset, int length) {
    for (final region in regions) {
      if (region.offset == offset && region.length == length) {
        this.region = region;
        targetLocation = region.targetLocation;
        return;
      }
    }
    final regionsString = regions.join('\n');
    fail('Unable to find a region at ($offset, $length) in $regionsString');
  }

  void _findRegionString(String str, String suffix, {final codeOverride}) {
    final code = codeOverride != null ? codeOverride : this.code;
    final search = '$str$suffix';
    final offset = code.indexOf(search);
    expect(offset, isNonNegative, reason: 'Cannot find |$search| in |$code|');
    _findRegion(offset, str.length);
  }
}

@reflectiveTest
class AngularOccurrencesContributorTest extends AbstractAngularTest {
  String code;

  OccurrencesCollector collector = new OccurrencesCollectorMock();
  List<protocol.Occurrences> occurrencesList = <protocol.Occurrences>[];

  protocol.Occurrences occurrences;

  @override
  void setUp() {
    super.setUp();
    when(collector.addOccurrences(typed(any))).thenAnswer((invocation) {
      occurrencesList.add(invocation.positionalArguments.first);
    });
  }

  // ignore: non_constant_identifier_names
  void test_dart_templates() {
    code = r'''
import '/angular2/src/core/metadata.dart';

@Component(selector: 'text-panel', inputs: const ['text: my-text'])
@View(template: r"<div>some text</div>")
class TextPanel {
  String text; // 1
}

@Component(selector: 'UserPanel')
@View(template: r"""
<div>
  <text-panel [my-text]='user.value'></text-panel> // cl
</div>
""", directives: [TextPanel])
class UserPanel {
  ObjectContainer<String> user; // 2
}

class ObjectContainer<T> {
  T value; // 3
}
''';
    final source = newSource('/test.dart', code);
    //LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    //computeResult(target, DART_TEMPLATES);
    // compute navigation regions
    new AngularOccurrencesContributor()
        .computeOccurrences(collector, source);
    // "text" field
    {
      _findOccurrences(code.indexOf('text: my-text'));
      expect(occurrences.element.name, 'text');
      expect(occurrences.length, 'text'.length);
      expect(occurrences.offsets, contains(code.indexOf('text; // 1')));
    }
    // "text-panel" component
    {
      _findOccurrences(code.indexOf("text-panel', "));
      expect(occurrences.element.name, 'text-panel');
      expect(occurrences.length, 'text-panel'.length);
      expect(occurrences.offsets, contains(code.indexOf("text-panel [")));
      expect(occurrences.offsets, contains(code.indexOf("text-panel> // cl")));
    }
    // "user" field
    {
      _findOccurrences(code.indexOf("user.value'><"));
      expect(occurrences.element.name, 'user');
      expect(occurrences.length, 'user'.length);
      expect(occurrences.offsets, contains(code.indexOf('user; // 2')));
    }
    // "value" field
    {
      _findOccurrences(code.indexOf("value'><"));
      expect(occurrences.element.name, 'value');
      expect(occurrences.length, 'value'.length);
      expect(occurrences.offsets, contains(code.indexOf('value; // 3')));
    }
  }

  void _findOccurrences(int offset) {
    for (final occurrences in occurrencesList) {
      if (occurrences.offsets.contains(offset)) {
        this.occurrences = occurrences;
        return;
      }
    }
    final listStr = occurrencesList.join('\n');
    fail('Unable to find occurrences at $offset in $listStr');
  }
}

/// Instances of the class [GatheringErrorListener] implement an error listener
/// that collects all of the errors passed to it for later examination.
class GatheringErrorListener implements AnalysisErrorListener {
  /// A list containing the errors that were collected.
  final _errors = <AnalysisError>[];

  @override
  void onError(AnalysisError error) {
    _errors.add(error);
  }

  void addAll(List<AnalysisError> errors) {
    for (final error in errors) {
      onError(error);
    }
  }
}

class NavigationCollectorMock extends Mock implements NavigationCollector {}

class OccurrencesCollectorMock extends Mock implements OccurrencesCollector {}

class SourceMock extends Mock implements Source {
  final String fullPath;

  SourceMock([String name = 'mocked.dart']) : fullPath = name;

  @override
  String toString() => fullPath;
}

class _RecordedNavigationRegion {
  final int offset;
  final int length;
  final protocol.ElementKind targetKind;
  final protocol.Location targetLocation;

  _RecordedNavigationRegion(
      this.offset, this.length, this.targetKind, this.targetLocation);

  @override
  String toString() => '$offset $length $targetKind $targetLocation';
}

import 'dart:async';

import 'package:analyzer_plugin/utilities/navigation/navigation.dart';
//import 'package:analysis_server/plugin/analysis/occurrences/occurrences_core.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as protocol;
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/navigation.dart';
import 'package:angular_analyzer_plugin/src/navigation_request.dart';
import 'package:typed_mock/typed_mock.dart';
import 'package:unittest/unittest.dart';

import 'abstract_angular.dart';

void main() {
  defineReflectiveSuite(() {
    // TODO get these working again in the latest SDK
    defineReflectiveTests(AngularNavigationTest);
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
class AngularNavigationTest extends AbstractAngularTest {
  String code;

  /// Compute all the views declared in the given [dartSource], and resolve the
  /// external template of all the views.
  Future<DirectivesResult> resolveLinkedHtml(Source dartSource) async {
    final result = await angularDriver.resolveDart(dartSource.fullName);
    for (var d in result.directives) {
      if (d is Component && d.view.templateUriSource != null) {
        final htmlPath = d.view.templateUriSource.fullName;
        return await angularDriver.resolveHtml(htmlPath);
      }
    }

    return null;
  }

  /// Compute all the views declared in the given [dartSource], and return its
  /// result
  Future<DirectivesResult> resolveDart(Source dartSource) async =>
      await angularDriver.resolveDart(dartSource.fullName);

  List<_RecordedNavigationRegion> regions = <_RecordedNavigationRegion>[];
  NavigationCollector collector = new NavigationCollectorMock();

  _RecordedNavigationRegion region;
  protocol.Location targetLocation;

  @override
  void setUp() {
    super.setUp();
    when(collector.addRegion(anyInt, anyInt, anyObject, anyObject))
        .thenInvoke((offset, length, targetKind, targetLocation) {
      regions.add(new _RecordedNavigationRegion(
          offset, length, targetKind, targetLocation));
    });
  }

  // ignore: non_constant_identifier_names
  Future test_dart_templates() async {
    code = r'''
import '/angular/src/core/metadata.dart';

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
    // compute navigation regions
    final result = await resolveDart(source);
    new AngularNavigation().computeNavigation(
        new AngularNavigationRequest(null, null, null, result), collector,
        templatesOnly: false);
    // input references setter
    {
      _findRegionString('text', ': my-text');
      // TODO: reenable this check
      //expect(region.targetKind, protocol.ElementKind.SETTER);
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
  Future test_dart_view_templateUrl() async {
    code = r'''
import 'package:angular/src/core/metadata.dart';

@Component(selector: 'text-panel')
@View(templateUrl: 'text_panel.html')
class TextPanel {}
''';
    final dartSource = newSource('/test.dart', code);
    newSource('/text_panel.html', "");
    final result = await resolveDart(dartSource);
    new AngularNavigation().computeNavigation(
        new AngularNavigationRequest(null, null, null, result), collector,
        templatesOnly: false);
    // input references setter
    {
      _findRegionString("'text_panel.html'", ')');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/text_panel.html');
      expect(targetLocation.offset, 0);
    }
  }

  // ignore: non_constant_identifier_names
  Future test_html_templates() async {
    final dartCode = r'''
import 'package:angular/src/core/metadata.dart';

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
    final dartSource = newSource('/test.dart', dartCode);
    newSource('/text_panel.html', htmlCode);
    final result = await resolveLinkedHtml(dartSource);
    new AngularNavigation().computeNavigation(
        new AngularNavigationRequest(null, null, null, result), collector,
        templatesOnly: false);
    // template references field
    {
      _findRegionString('text', "}}", codeOverride: htmlCode);
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, dartCode.indexOf("text; // 1"));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_searchRange_perfectMatch() async {
    code = r'''
import 'package:angular/src/core/metadata.dart';

@Component(
    selector: 'test-comp', template: '{{fieldOne}}{{fieldTwo}}', directives: [])
class TestComponent {
  String fieldOne;
  String fieldTwo;
}
''';
    final source = newSource('/test.dart', code);
    // compute navigation regions
    final result = await resolveDart(source);
    new AngularNavigation().computeNavigation(
        new AngularNavigationRequest(
            null, 'fieldOne'.length, code.indexOf('fieldOne}}'), result),
        collector,
        templatesOnly: false);
    _findRegionString('fieldOne', '}}');
    expect(region.targetKind, protocol.ElementKind.UNKNOWN);
    expect(targetLocation.file, '/test.dart');
    expect(targetLocation.offset, code.indexOf('fieldOne;'));

    expect(regions, hasLength(1));
  }

  // ignore: non_constant_identifier_names
  Future test_searchRange_narrowMiss() async {
    code = r'''
import 'package:angular/src/core/metadata.dart';

@Component(
    selector: 'test-comp', template: '{{fieldOne}}{{fieldTwo}}', directives: [])
class TestComponent {
  String fieldOne;
  String fieldTwo;
}
''';
    final source = newSource('/test.dart', code);
    // compute navigation regions
    final result = await resolveDart(source);
    new AngularNavigation().computeNavigation(
        new AngularNavigationRequest(
            null, '}}{{'.length, code.indexOf('}}{{'), result),
        collector,
        templatesOnly: false);
    expect(regions, hasLength(0));
  }

  // ignore: non_constant_identifier_names
  Future test_searchRange_overlapLeftAndRight() async {
    code = r'''
import 'package:angular/src/core/metadata.dart';

@Component(
    selector: 'test-comp', template: '{{fieldOne}}{{fieldTwo}}', directives: [])
class TestComponent {
  String fieldOne;
  String fieldTwo;
}
''';
    final source = newSource('/test.dart', code);
    // compute navigation regions
    final result = await resolveDart(source);
    new AngularNavigation().computeNavigation(
        new AngularNavigationRequest(
            null, 'e}}{{f'.length, code.indexOf('e}}{{f'), result),
        collector,
        templatesOnly: false);
    {
      _findRegionString('fieldOne', '}}');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf('fieldOne;'));
    }
    {
      _findRegionString('fieldTwo', '}}');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf('fieldTwo;'));
    }

    expect(regions, hasLength(2));
  }

  // ignore: non_constant_identifier_names
  Future test_searchRange_fitPerfectlyLeftAndRight() async {
    code = r'''
import 'package:angular/src/core/metadata.dart';

@Component(
    selector: 'test-comp', template: '{{fieldOne}}{{fieldTwo}}', directives: [])
class TestComponent {
  String fieldOne;
  String fieldTwo;
}
''';
    final source = newSource('/test.dart', code);
    // compute navigation regions
    final result = await resolveDart(source);
    new AngularNavigation().computeNavigation(
        new AngularNavigationRequest(null, 'fieldOne}}{{fieldTwo'.length,
            code.indexOf('fieldOne}}{{fieldTwo'), result),
        collector,
        templatesOnly: false);
    {
      _findRegionString('fieldOne', '}}');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf('fieldOne;'));
    }
    {
      _findRegionString('fieldTwo', '}}');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf('fieldTwo;'));
    }

    expect(regions, hasLength(2));
  }

  // ignore: non_constant_identifier_names
  Future test_searchRange_overlapsEntirely() async {
    code = r'''
import 'package:angular/src/core/metadata.dart';

@Component(
    selector: 'test-comp', template: 'blah {{fieldOne}} blah', directives: [])
class TestComponent {
  String fieldOne;
  String fieldTwo;
}
''';
    final source = newSource('/test.dart', code);
    // compute navigation regions
    final result = await resolveDart(source);
    new AngularNavigation().computeNavigation(
        new AngularNavigationRequest(
            null, ' {{fieldOne}} '.length, code.indexOf(' {{'), result),
        collector,
        templatesOnly: false);
    {
      _findRegionString('fieldOne', '}}');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf('fieldOne;'));
    }

    expect(regions, hasLength(1));
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

//@reflectiveTest
//class AngularOccurrencesContributorTest extends AbstractAngularTest {
//  String code;
//
//  OccurrencesCollector collector = new OccurrencesCollectorMock();
//  List<protocol.Occurrences> occurrencesList = <protocol.Occurrences>[];
//
//  protocol.Occurrences occurrences;
//
//  @override
//  void setUp() {
//    super.setUp();
//    when(collector.addOccurrences(anyObject)).thenInvoke(occurrencesList.add);
//  }
//
//  // ignore: non_constant_identifier_names
//  void test_dart_templates() {
//    code = r'''
//import 'package:angular/src/core/metadata.dart';
//
//@Component(selector: 'text-panel', inputs: const ['text: my-text'])
//@View(template: r"<div>some text</div>")
//class TextPanel {
//  String text; // 1
//}
//
//@Component(selector: 'UserPanel')
//@View(template: r"""
//<div>
//  <text-panel [my-text]='user.value'></text-panel> // cl
//</div>
//""", directives: [TextPanel])
//class UserPanel {
//  ObjectContainer<String> user; // 2
//}
//
//class ObjectContainer<T> {
//  T value; // 3
//}
//''';
//    final source = newSource('/test.dart', code);
//    //LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
//    //computeResult(target, DART_TEMPLATES);
//    // compute navigation regions
//    new AngularOccurrencesContributor()
//        .computeOccurrences(collector, null, source);
//    // "text" field
//    {
//      _findOccurrences(code.indexOf('text: my-text'));
//      expect(occurrences.element.name, 'text');
//      expect(occurrences.length, 'text'.length);
//      expect(occurrences.offsets, contains(code.indexOf('text; // 1')));
//    }
//    // "text-panel" component
//    {
//      _findOccurrences(code.indexOf("text-panel', "));
//      expect(occurrences.element.name, 'text-panel');
//      expect(occurrences.length, 'text-panel'.length);
//      expect(occurrences.offsets, contains(code.indexOf("text-panel [")));
//      expect(occurrences.offsets, contains(code.indexOf("text-panel> // cl")));
//    }
//    // "user" field
//    {
//      _findOccurrences(code.indexOf("user.value'><"));
//      expect(occurrences.element.name, 'user');
//      expect(occurrences.length, 'user'.length);
//      expect(occurrences.offsets, contains(code.indexOf('user; // 2')));
//    }
//    // "value" field
//    {
//      _findOccurrences(code.indexOf("value'><"));
//      expect(occurrences.element.name, 'value');
//      expect(occurrences.length, 'value'.length);
//      expect(occurrences.offsets, contains(code.indexOf('value; // 3')));
//    }
//  }
//
//  void _findOccurrences(int offset) {
//    for (final occurrences in occurrencesList) {
//      if (occurrences.offsets.contains(offset)) {
//        this.occurrences = occurrences;
//        return;
//      }
//    }
//    final listStr = occurrencesList.join('\n');
//    fail('Unable to find occurrences at $offset in $listStr');
//  }
//}

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

class NavigationCollectorMock extends TypedMock implements NavigationCollector {
}

//class OccurrencesCollectorMock extends TypedMock
//    implements OccurrencesCollector {}

class SourceMock extends TypedMock implements Source {
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

import 'dart:async';

import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as protocol;
import 'package:analyzer_plugin/utilities/navigation/navigation.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/navigation.dart';
import 'package:angular_analyzer_plugin/src/navigation_request.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_angular.dart';

// 'typed' is deprecated and shouldn't be used.
// ignore_for_file: deprecated_member_use

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AngularNavigationTest);
  });
}

@reflectiveTest
class AngularNavigationTest extends AbstractAngularTest {
  String code;

  List<_RecordedNavigationRegion> regions = <_RecordedNavigationRegion>[];

  NavigationCollector collector = new NavigationCollectorMock();

  _RecordedNavigationRegion region;
  protocol.Location targetLocation;

  /// Compute all the views declared in the given [dartSource], and return its
  /// result
  Future<DirectivesResult> resolveDart(Source dartSource) async =>
      await angularDriver.requestDartResult(dartSource.fullName);

  /// Resolve the external templates of the views declared in the [dartSource].
  Future<DirectivesResult> resolveLinkedHtml(Source dartSource) async {
    final result = await angularDriver.requestDartResult(dartSource.fullName);
    for (var d in result.directives) {
      if (d is Component && d.view.templateUriSource != null) {
        final htmlPath = d.view.templateUriSource.fullName;
        return await angularDriver.requestHtmlResult(htmlPath);
      }
    }

    return null;
  }

  @override
  void setUp() {
    super.setUp();
    // TODO(mfairhurst): remove `as dynamic`. See https://github.com/dart-lang/sdk/issues/33934
    when(collector.addRegion(
            typed(argThat(const isInstanceOf<int>())),
            typed(argThat(const isInstanceOf<int>())),
            typed(any),
            typed(any)) as dynamic)
        .thenAnswer((invocation) {
      final offset = invocation.positionalArguments[0] as int;
      final length = invocation.positionalArguments[1] as int;
      final targetKind =
          invocation.positionalArguments[2] as protocol.ElementKind;
      final targetLocation =
          invocation.positionalArguments[3] as protocol.Location;
      regions.add(new _RecordedNavigationRegion(
          offset, length, targetKind, targetLocation));
    });
  }

  // ignore: non_constant_identifier_names
  Future test_dart_templates() async {
    code = r'''
import '/angular/src/core/metadata.dart';

@Component(selector: 'text-panel', template: r"<div>some text</div>")
class TextPanel {
  @Input('my-text') String text; // 1
  @Input() longform; // 4
}

@Component(selector: 'UserPanel', template: r"""
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
    new AngularNavigation(angularDriver.contentOverlay).computeNavigation(
        new AngularNavigationRequest(null, null, null, result), collector,
        templatesOnly: false);
    // template references component (open tag)
    {
      _findRegionString('text-panel', ' [my-text]');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("text-panel', template"));
    }
    // template references component (close tag)
    {
      _findRegionString('text-panel', '> // close');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("text-panel', template"));
    }
    // template references input
    {
      _findRegionString('my-text', ']=');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("my-text"));
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

@Component(selector: 'text-panel', templateUrl: 'text_panel.html')
class TextPanel {}
''';
    final dartSource = newSource('/test.dart', code);
    newSource('/text_panel.html', "");
    final result = await resolveDart(dartSource);
    new AngularNavigation(angularDriver.contentOverlay).computeNavigation(
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
  Future test_dart_view_templateUrl_notForTemplateOnly() async {
    code = r'''
import 'package:angular/src/core/metadata.dart';

@Component(selector: 'text-panel', templateUrl: 'test.html')
class TextPanel {}
''';
    final dartSource = newSource('/test.dart', code);
    newSource('/test.html', ''); // empty template HTML file.
    final result = await resolveLinkedHtml(dartSource);
    new AngularNavigation(angularDriver.contentOverlay).computeNavigation(
        new AngularNavigationRequest(null, null, null, result), collector,
        templatesOnly: true);
    // no resolved ranges.
    expect(regions, isEmpty);
  }

  // ignore: non_constant_identifier_names
  Future test_html_templates() async {
    final dartCode = r'''
import 'package:angular/src/core/metadata.dart';

@Component(selector: 'text-panel', templateUrl: 'text_panel.html')
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
    new AngularNavigation(angularDriver.contentOverlay).computeNavigation(
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
  Future test_navigate_attrIf() async {
    code = r'''
import 'package:angular/src/core/metadata.dart';

@Component(selector: 'foo', template: r"""
<div
  [attr.foo]="123"
  [attr.foo.if]="true">
</div>
""")
class TextPanel {
}
''';
    final source = newSource('/test.dart', code);
    // compute navigation regions
    final result = await resolveDart(source);
    new AngularNavigation(angularDriver.contentOverlay).computeNavigation(
        new AngularNavigationRequest(null, null, null, result), collector,
        templatesOnly: false);
    {
      _findRegionString('foo', '.if');
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf('foo]'));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_navigateOnfocusin() async {
    code = r'''
import 'package:angular/src/core/metadata.dart';

@Component(selector: 'test-comp', template: '<div (focusin)=""></div>')
class TestComponent {
}
''';
    final source = newSource('/test.dart', code);
    // compute navigation regions
    final result = await resolveDart(source);
    new AngularNavigation(angularDriver.contentOverlay).computeNavigation(
        new AngularNavigationRequest(
            null, 'focusin'.length, code.indexOf('focusin'), result),
        collector,
        templatesOnly: false);

    expect(regions, hasLength(0));
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
    new AngularNavigation(angularDriver.contentOverlay).computeNavigation(
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
    new AngularNavigation(angularDriver.contentOverlay).computeNavigation(
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
    new AngularNavigation(angularDriver.contentOverlay).computeNavigation(
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
    new AngularNavigation(angularDriver.contentOverlay).computeNavigation(
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
    new AngularNavigation(angularDriver.contentOverlay).computeNavigation(
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

  void _findRegionString(String str, String suffix,
      {final String codeOverride}) {
    final code = codeOverride != null ? codeOverride : this.code;
    final search = '$str$suffix';
    final offset = code.indexOf(search);
    expect(offset, isNonNegative, reason: 'Cannot find |$search| in |$code|');
    _findRegion(offset, str.length);
  }
}

/// Instances of the class [GatheringErrorListener] implement an error listener
/// that collects all of the errors passed to it for later examination.
class GatheringErrorListener implements AnalysisErrorListener {
  /// A list containing the errors that were collected.
  final _errors = <AnalysisError>[];

  void addAll(List<AnalysisError> errors) {
    for (final error in errors) {
      onError(error);
    }
  }

  @override
  void onError(AnalysisError error) {
    _errors.add(error);
  }
}

class NavigationCollectorMock extends Mock implements NavigationCollector {}

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

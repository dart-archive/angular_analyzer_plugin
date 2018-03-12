import 'package:analyzer_plugin/protocol/protocol_common.dart' as protocol;
import 'package:analyzer_plugin/protocol/protocol_constants.dart' as protocol;
import 'package:analyzer_plugin/utilities/analyzer_converter.dart' as protocol;
import 'package:analyzer_plugin/utilities/navigation/navigation.dart';
import 'package:analyzer/dart/element/element.dart' as engine;
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/navigation_request.dart';
import 'package:analyzer/src/dart/analysis/file_state.dart';

class AngularNavigation implements NavigationContributor {
  final FileContentOverlay _contentOverlay;

  AngularNavigation(this._contentOverlay);

  @override
  void computeNavigation(
      NavigationRequest baseRequest, NavigationCollector collector,
      {templatesOnly: false}) {
    // cast this
    final AngularNavigationRequest request = baseRequest;
    final length = request.length;
    final offset = request.offset;
    final result = request.result;

    if (result == null) {
      return;
    }

    final span = offset != null && length != null
        ? new SourceRange(offset, length)
        : null;
    final directives = result.directives;
    final views = directives
        .map((d) => d is Component ? d.view : null)
        .where((v) => v != null);

    if (!templatesOnly) {
      // special dart navigable regions
      for (final directive in directives) {
        _addDirectiveRegions(collector, directive, span);
      }
      for (final view in views) {
        _addViewRegions(collector, view, span);
      }
    }

    final resolvedTemplates = result.fullyResolvedDirectives
        .map((d) => d is Component ? d.view?.template : null)
        .where((v) => v != null);
    for (final template in resolvedTemplates) {
      _addTemplateRegions(collector, template, span);
    }
  }

  void _addDirectiveRegions(NavigationCollector collector,
      AbstractDirective directive, SourceRange targetRange) {
    for (final input in directive.inputs) {
      if (!isTargeted(input.setterRange, targetRange: targetRange)) {
        continue;
      }
      final setter = input.setter;
      if (setter == null) {
        continue;
      }

      final compilationElement =
          setter.getAncestor((e) => e is engine.CompilationUnitElement);
      final lineInfo =
          (compilationElement as engine.CompilationUnitElement).lineInfo;

      final offsetLineLocation = lineInfo.getLocation(setter.nameOffset);
      collector.addRegion(
          input.setterRange.offset,
          input.setterRange.length,
          new protocol.AnalyzerConverter().convertElementKind(setter.kind),
          new protocol.Location(
              setter.source.fullName,
              setter.nameOffset,
              setter.nameLength,
              offsetLineLocation.lineNumber,
              offsetLineLocation.columnNumber));
    }
  }

  void _addTemplateRegions(NavigationCollector collector, Template template,
      SourceRange targetRange) {
    for (final resolvedRange in template.ranges) {
      if (!isTargeted(resolvedRange.range, targetRange: targetRange)) {
        continue;
      }

      final offset = resolvedRange.range.offset;
      final element = resolvedRange.element;

      if (element.nameOffset == null) {
        continue;
      }

      final lineInfo = element.compilationElement?.lineInfo ??
          new LineInfo.fromContent(
              _contentOverlay[element.source.fullName] ?? "");

      if (lineInfo == null) {
        continue;
      }

      final offsetLineLocation = lineInfo.getLocation(element.nameOffset);
      collector.addRegion(
          offset,
          resolvedRange.range.length,
          protocol.ElementKind.UNKNOWN,
          new protocol.Location(
              element.source.fullName,
              element.nameOffset,
              element.nameLength,
              offsetLineLocation.lineNumber,
              offsetLineLocation.columnNumber));
    }
  }

  void _addViewRegions(
      NavigationCollector collector, View view, SourceRange targetRange) {
    if (view.templateUriSource != null &&
        isTargeted(view.templateUrlRange, targetRange: targetRange)) {
      collector.addRegion(
          view.templateUrlRange.offset,
          view.templateUrlRange.length,
          protocol.ElementKind.UNKNOWN,
          new protocol.Location(view.templateUriSource.fullName, 0, 0, 1, 1));
    }
  }

  /// A null target range indicates everything is targeted. Otherwise, intersect
  bool isTargeted(SourceRange toTest, {SourceRange targetRange}) =>
      // <a><b></b></a> or <a><b></a></b>, but not <a></a><b></b>.
      targetRange == null || targetRange.intersects(toTest);
}

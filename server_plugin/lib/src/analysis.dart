import 'package:analysis_server/plugin/analysis/navigation/navigation_core.dart';
import 'package:analysis_server/plugin/analysis/occurrences/occurrences_core.dart';
import 'package:analysis_server/protocol/protocol_generated.dart' as protocol;
import 'package:analysis_server/plugin/protocol/protocol_dart.dart' as protocol;
import 'package:analyzer_plugin/protocol/protocol_common.dart' as protocol;
import 'package:analyzer/dart/element/element.dart' as engine;
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:meta/meta.dart';

class AngularNavigation {
  void computeNavigation(NavigationCollector collector, Source source,
      int offset, int length, LineInfo lineInfo, DirectivesResult result,
      {@required bool templatesOnly}) {
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
        _addDirectiveRegions(collector, lineInfo, directive, span);
      }
      for (final view in views) {
        _addViewRegions(collector, lineInfo, view, span);
      }
    }

    final resolvedTemplates = result.fullyResolvedDirectives
        .map((d) => d is Component ? d.view?.template : null)
        .where((v) => v != null);
    for (final template in resolvedTemplates) {
      _addTemplateRegions(collector, lineInfo, template, span);
    }
  }

  void _addDirectiveRegions(NavigationCollector collector, LineInfo lineInfo,
      AbstractDirective directive, SourceRange targetRange) {
    for (final input in directive.inputs) {
      if (!rangesOverlap(input.setterRange, targetRange)) {
        continue;
      }
      final setter = input.setter;
      if (setter == null) {
        continue;
      }
      // TODO(mfairhurst) proper ranges for setters defined in other files
      final offsetLineLocation = lineInfo.getLocation(setter.nameOffset);
      collector.addRegion(
          input.setterRange.offset,
          input.setterRange.length,
          protocol.convertElementKind(setter.kind),
          new protocol.Location(
              setter.source.fullName,
              setter.nameOffset,
              setter.nameLength,
              offsetLineLocation.lineNumber,
              offsetLineLocation.columnNumber));
    }
  }

  void _addTemplateRegions(NavigationCollector collector, LineInfo lineInfo,
      Template template, SourceRange targetRange) {
    for (final resolvedRange in template.ranges) {
      if (!rangesOverlap(resolvedRange.range, targetRange)) {
        continue;
      }

      final offset = resolvedRange.range.offset;
      final element = resolvedRange.element;
      final compilationElement = element.compilationElement;
      // TODO(mfairhurst) proper ranges for template to template references
      final offsetLineLocation = (compilationElement?.lineInfo ?? lineInfo)
          .getLocation(element.nameOffset);
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

  void _addViewRegions(NavigationCollector collector, LineInfo lineInfo,
      View view, SourceRange targetRange) {
    if (view.templateUriSource != null &&
        rangesOverlap(view.templateUrlRange, targetRange)) {
      collector.addRegion(
          view.templateUrlRange.offset,
          view.templateUrlRange.length,
          protocol.ElementKind.UNKNOWN,
          new protocol.Location(view.templateUriSource.fullName, 0, 0, 1, 1));
    }
  }

  bool rangesOverlap(SourceRange a, SourceRange b) =>
      // <a><b></b></a> or <a><b></a></b>, but not <a></a><b></b>.
      a == null || b == null || a.contains(b.offset) || b.contains(a.offset);
}

class AngularOccurrencesContributor implements OccurrencesContributor {
  @override
  void computeOccurrences(
      OccurrencesCollector collector, AnalysisContext context, Source source) {
    //List<Source> librarySources = context.getLibrariesContaining(source);
    //for (Source librarySource in librarySources) {
    //  // directives
    //  {
    //    List<AbstractDirective> directives = context.getResult(
    //        new LibrarySpecificUnit(librarySource, source), DIRECTIVES_IN_UNIT);
    //    for (AbstractDirective directive in directives) {
    //      _addDirectiveOccurrences(collector, directive);
    //    }
    //  }
    //  // templates
    //  {
    //    List<Template> templates = context.getResult(
    //        new LibrarySpecificUnit(librarySource, source), DART_TEMPLATES);
    //    for (Template template in templates) {
    //      _addTemplateOccurrences(collector, template);
    //    }
    //  }
    //}
  }

  void addDirectiveOccurrences(
      OccurrencesCollector collector, AbstractDirective directive) {
    final elementsOffsets = <engine.PropertyAccessorElement, List<int>>{};
    for (final input in directive.inputs) {
      final setter = input.setter;
      if (setter == null) {
        continue;
      }
      var offsets = elementsOffsets[setter];
      if (offsets == null) {
        offsets = <int>[setter.nameOffset];
        elementsOffsets[setter] = offsets;
      }
      offsets.add(input.setterRange.offset);
    }
    // convert map into Occurrences
    elementsOffsets.forEach((setter, offsets) {
      final protocolElement = _newProtocolElementForEngine(setter);
      final length = protocolElement.location.length;
      final occurrences =
          new protocol.Occurrences(protocolElement, offsets, length);
      collector.addOccurrences(occurrences);
    });
  }

  void addTemplateOccurrences(
      OccurrencesCollector collector, Template template) {
    final elementsOffsets = <AngularElement, List<int>>{};
    for (final resolvedRange in template.ranges) {
      final element = resolvedRange.element;
      var offsets = elementsOffsets[element];
      if (offsets == null) {
        offsets = <int>[element.nameOffset];
        elementsOffsets[element] = offsets;
      }
      offsets.add(resolvedRange.range.offset);
    }
    // convert map into Occurrences
    elementsOffsets.forEach((angularElement, offsets) {
      final length = angularElement.nameLength;
      final protocolElement = _newProtocolElement(angularElement);
      final occurrences =
          new protocol.Occurrences(protocolElement, offsets, length);
      collector.addOccurrences(occurrences);
    });
  }

  engine.Element _canonicalizeElement(engine.Element element) {
    var canonical = element;
    if (canonical is engine.PropertyAccessorElement) {
      canonical = (canonical as engine.PropertyAccessorElement).variable;
    }
    if (canonical is Member) {
      canonical = (canonical as Member).baseElement;
    }
    return canonical;
  }

  protocol.Element _newProtocolElement(AngularElement angularElement) {
    final name = angularElement.name;
    final length = name.length;
    if (angularElement is DartElement) {
      final dartElement = angularElement.element;
      return _newProtocolElementForEngine(dartElement);
    }
    return new protocol.Element(protocol.ElementKind.UNKNOWN, name, 0,
        location: new protocol.Location(angularElement.source.fullName,
            angularElement.nameOffset, length, -1, -1));
  }

  protocol.Element _newProtocolElementForEngine(engine.Element dartElement) {
    final cannonical = _canonicalizeElement(dartElement);
    return protocol.convertElement(cannonical);
  }
}

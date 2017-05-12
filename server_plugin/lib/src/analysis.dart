import 'package:analysis_server/plugin/analysis/navigation/navigation_core.dart';
import 'package:analysis_server/plugin/analysis/occurrences/occurrences_core.dart';
import 'package:analysis_server/protocol/protocol_generated.dart' as protocol;
import 'package:analysis_server/plugin/protocol/protocol_dart.dart' as protocol;
import 'package:analyzer/dart/element/element.dart' as engine;
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';

class AngularNavigationContributor implements NavigationContributor {
  @override
  void computeNavigation(NavigationCollector collector, AnalysisContext context,
      Source source, int offset, int length) {
    //LineInfo lineInfo = context.computeResult(source, LINE_INFO);
    //// in Dart
    //{
    //  List<Source> librarySources = context.getLibrariesContaining(source);
    //  for (Source librarySource in librarySources) {
    //    // directives
    //    {
    //      List<AbstractDirective> directives =
    //          context.getResult(target, DIRECTIVES_IN_UNIT);
    //      for (AbstractDirective template in directives) {
    //        _addDirectiveRegions(collector, lineInfo, template);
    //      }
    //    }
    //    // templates
    //    {
    //      List<Template> templates = context.getResult(target, DART_TEMPLATES);
    //      for (Template template in templates) {
    //        _addTemplateRegions(collector, lineInfo, template);
    //      }
    //    }
    //    // views
    //    {
    //      List<View> views = context.getResult(target, VIEWS2);
    //      for (View view in views) {
    //        _addViewRegions(collector, lineInfo, view);
    //      }
    //    }
    //  }
    //}
    // in HTML
    {
      //List<HtmlTemplate> templates = context.getResult(source, HTML_TEMPLATES);
      //if (templates.isNotEmpty) {
      //  HtmlTemplate template = templates.first;
      //  _addTemplateRegions(collector, lineInfo, template);
      //}
    }
  }

  void addDirectiveRegions(NavigationCollector collector, LineInfo lineInfo,
      AbstractDirective directive) {
    for (final input in directive.inputs) {
      final setter = input.setter;
      if (setter == null) {
        continue;
      }
      final offsetLineLocation = lineInfo.getLocation(setter.nameOffset);
      if (setter != null) {
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
  }

  void addTemplateRegions(
      NavigationCollector collector, LineInfo lineInfo, Template template) {
    for (final resolvedRange in template.ranges) {
      final offset = resolvedRange.range.offset;
      final element = resolvedRange.element;
      final offsetLineLocation = lineInfo.getLocation(offset);
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

  void addViewRegions(
      NavigationCollector collector, LineInfo lineInfo, View view) {
    if (view.templateUriSource != null) {
      collector.addRegion(
          view.templateUrlRange.offset,
          view.templateUrlRange.length,
          protocol.ElementKind.UNKNOWN,
          new protocol.Location(view.templateUriSource.fullName, 0, 0, 1, 1));
    }
  }
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

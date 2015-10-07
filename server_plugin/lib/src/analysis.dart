library angular2.src.analysis.server_plugin.analysis;

import 'package:analysis_server/analysis/analysis_domain.dart';
import 'package:analysis_server/analysis/navigation_core.dart';
import 'package:analysis_server/analysis/occurrences_core.dart';
import 'package:analysis_server/src/protocol.dart' as protocol;
import 'package:analysis_server/src/protocol_server.dart' as protocol;
import 'package:analyzer/src/generated/element.dart' as engine;
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/general.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/tasks.dart';

class AnalysisDomainContributor {
  AnalysisDomain analysisDomain;

  void onResult(ComputedResult result) {
    AnalysisContext context = result.context;
    Source source = result.target.source;
    analysisDomain.scheduleNotification(
        context, source, protocol.AnalysisService.NAVIGATION);
    analysisDomain.scheduleNotification(
        context, source, protocol.AnalysisService.OCCURRENCES);
  }

  void setAnalysisDomain(AnalysisDomain analysisDomain) {
    this.analysisDomain = analysisDomain;
    analysisDomain.onResultComputed(DART_TEMPLATES).listen(onResult);
    analysisDomain.onResultComputed(HTML_TEMPLATES).listen(onResult);
  }
}

class AngularNavigationContributor implements NavigationContributor {
  @override
  void computeNavigation(NavigationCollector collector, AnalysisContext context,
      Source source, int offset, int length) {
    LineInfo lineInfo = context.getResult(source, LINE_INFO);
    // in Dart
    {
      List<Source> librarySources = context.getLibrariesContaining(source);
      for (Source librarySource in librarySources) {
        // directives
        {
          List<AbstractDirective> directives = context.getResult(
              new LibrarySpecificUnit(librarySource, source), DIRECTIVES);
          for (AbstractDirective template in directives) {
            _addDirectiveRegions(collector, lineInfo, template);
          }
        }
        // templates
        {
          List<Template> templates = context.getResult(
              new LibrarySpecificUnit(librarySource, source), DART_TEMPLATES);
          for (Template template in templates) {
            _addTemplateRegions(collector, lineInfo, template);
          }
        }
      }
    }
    // in HTML
    {
      List<HtmlTemplate> templates = context.getResult(source, HTML_TEMPLATES);
      if (templates.isNotEmpty) {
        HtmlTemplate template = templates.first;
        _addTemplateRegions(collector, lineInfo, template);
      }
    }
  }

  void _addDirectiveRegions(NavigationCollector collector, LineInfo lineInfo,
      AbstractDirective directive) {
    for (PropertyElement property in directive.properties) {
      engine.PropertyAccessorElement setter = property.setter;
      if (setter == null) {
        continue;
      }
      LineInfo_Location offsetLineLocation =
          lineInfo.getLocation(setter.nameOffset);
      if (setter != null) {
        collector.addRegion(
            property.setterRange.offset,
            property.setterRange.length,
            protocol.newElementKind_fromEngine(setter.kind),
            new protocol.Location(
                setter.source.fullName,
                setter.nameOffset,
                setter.nameLength,
                offsetLineLocation.lineNumber,
                offsetLineLocation.columnNumber));
      }
    }
  }

  void _addTemplateRegions(
      NavigationCollector collector, LineInfo lineInfo, Template template) {
    for (ResolvedRange resolvedRange in template.ranges) {
      int offset = resolvedRange.range.offset;
      AngularElement element = resolvedRange.element;
      LineInfo_Location offsetLineLocation = lineInfo.getLocation(offset);
      collector.addRegion(
          offset,
          resolvedRange.range.length,
          protocol.ElementKind.UNKNOWN,
          new protocol.Location(
              element.source.fullName,
              element.nameOffset,
              element.name.length,
              offsetLineLocation.lineNumber,
              offsetLineLocation.columnNumber));
    }
  }
}

class AngularOccurrencesContributor implements OccurrencesContributor {
  @override
  void computeOccurrences(
      OccurrencesCollector collector, AnalysisContext context, Source source) {
    List<Source> librarySources = context.getLibrariesContaining(source);
    for (Source librarySource in librarySources) {
      // directives
      {
        List<AbstractDirective> directives = context.getResult(
            new LibrarySpecificUnit(librarySource, source), DIRECTIVES);
        for (AbstractDirective directive in directives) {
          _addDirectiveOccurrences(collector, directive);
        }
      }
      // templates
      {
        List<Template> templates = context.getResult(
            new LibrarySpecificUnit(librarySource, source), DART_TEMPLATES);
        for (Template template in templates) {
          _addTemplateOccurrences(collector, template);
        }
      }
    }
  }

  void _addDirectiveOccurrences(
      OccurrencesCollector collector, AbstractDirective directive) {
    Map<engine.PropertyAccessorElement, List<int>> elementsOffsets =
        <engine.PropertyAccessorElement, List<int>>{};
    for (PropertyElement property in directive.properties) {
      engine.PropertyAccessorElement setter = property.setter;
      if (setter == null) {
        continue;
      }
      List<int> offsets = elementsOffsets[setter];
      if (offsets == null) {
        offsets = <int>[setter.nameOffset];
        elementsOffsets[setter] = offsets;
      }
      offsets.add(property.setterRange.offset);
    }
    // convert map into Occurrences
    elementsOffsets.forEach((setter, offsets) {
      protocol.Element protocolElement = _newProtocolElement_forEngine(setter);
      int length = protocolElement.location.length;
      protocol.Occurrences occurrences =
          new protocol.Occurrences(protocolElement, offsets, length);
      collector.addOccurrences(occurrences);
    });
  }

  void _addTemplateOccurrences(
      OccurrencesCollector collector, Template template) {
    Map<AngularElement, List<int>> elementsOffsets =
        <AngularElement, List<int>>{};
    for (ResolvedRange resolvedRange in template.ranges) {
      AngularElement element = resolvedRange.element;
      List<int> offsets = elementsOffsets[element];
      if (offsets == null) {
        offsets = <int>[element.nameOffset];
        elementsOffsets[element] = offsets;
      }
      offsets.add(resolvedRange.range.offset);
    }
    // convert map into Occurrences
    elementsOffsets.forEach((angularElement, offsets) {
      int length = angularElement.name.length;
      protocol.Element protocolElement = _newProtocolElement(angularElement);
      protocol.Occurrences occurrences =
          new protocol.Occurrences(protocolElement, offsets, length);
      collector.addOccurrences(occurrences);
    });
  }

  engine.Element _canonicalizeElement(engine.Element element) {
    if (element is engine.FieldFormalParameterElement) {
      element = (element as engine.FieldFormalParameterElement).field;
    }
    if (element is engine.PropertyAccessorElement) {
      element = (element as engine.PropertyAccessorElement).variable;
    }
    if (element is engine.Member) {
      element = (element as engine.Member).baseElement;
    }
    return element;
  }

  protocol.Element _newProtocolElement(AngularElement angularElement) {
    String name = angularElement.name;
    int length = name.length;
    if (angularElement is DartElement) {
      engine.Element dartElement = angularElement.element;
      return _newProtocolElement_forEngine(dartElement);
    }
    return new protocol.Element(protocol.ElementKind.UNKNOWN, name, 0,
        location: new protocol.Location(angularElement.source.fullName,
            angularElement.nameOffset, length, -1, -1));
  }

  protocol.Element _newProtocolElement_forEngine(engine.Element dartElement) {
    dartElement = _canonicalizeElement(dartElement);
    return protocol.newElement_fromEngine(dartElement);
  }
}

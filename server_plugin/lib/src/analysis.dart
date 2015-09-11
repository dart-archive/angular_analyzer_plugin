library angular2.src.analysis.server_plugin.index;

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

  void setAnalysisDomain(AnalysisDomain analysisDomain) {
    this.analysisDomain = analysisDomain;
    analysisDomain.onResultComputed(DART_TEMPLATES).listen((result) {
      AnalysisContext context = result.context;
      Source source = result.target.source;
      analysisDomain.scheduleNotification(
          context, source, protocol.AnalysisService.NAVIGATION);
      analysisDomain.scheduleNotification(
          context, source, protocol.AnalysisService.OCCURRENCES);
    });
  }
}

class AngularNavigationContributor implements NavigationContributor {
  @override
  void computeNavigation(NavigationCollector collector, AnalysisContext context,
      Source source, int offset, int length) {
    LineInfo lineInfo = context.getResult(source, LINE_INFO);
    List<Source> librarySources = context.getLibrariesContaining(source);
    for (Source librarySource in librarySources) {
      List<Template> templates = context.getResult(
          new LibrarySpecificUnit(librarySource, source), DART_TEMPLATES);
      for (Template template in templates) {
        _addTemplateRegions(collector, lineInfo, template);
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
      List<Template> templates = context.getResult(
          new LibrarySpecificUnit(librarySource, source), DART_TEMPLATES);
      for (Template template in templates) {
        _addTemplateOccurrences(collector, template);
      }
    }
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
      dartElement = _canonicalizeElement(dartElement);
      return protocol.newElement_fromEngine(dartElement);
    }
    return new protocol.Element(protocol.ElementKind.UNKNOWN, name, 0,
        location: new protocol.Location(angularElement.source.fullName,
            angularElement.nameOffset, length, -1, -1));
  }
}

library angular2.src.analysis.server_plugin.analysis;

import 'package:analysis_server/plugin/analysis/analysis_domain.dart';
import 'package:analysis_server/plugin/analysis/navigation/navigation_core.dart';
import 'package:analysis_server/plugin/analysis/occurrences/occurrences_core.dart';
import 'package:analysis_server/plugin/protocol/protocol.dart' as protocol;
import 'package:analysis_server/plugin/protocol/protocol_dart.dart' as protocol;
import 'package:analyzer/dart/element/element.dart' as engine;
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/general.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/tasks.dart';

class AnalysisDomainContributor {
  AnalysisDomain analysisDomain;

  void onResult(ResultChangedEvent event) {
    if (event.wasComputed) {
      AnalysisContext context = event.context;
      Source source = event.target.source;
      analysisDomain.scheduleNotification(
          context, source, protocol.AnalysisService.NAVIGATION);
      analysisDomain.scheduleNotification(
          context, source, protocol.AnalysisService.OCCURRENCES);
    }
  }

  void setAnalysisDomain(AnalysisDomain analysisDomain) {
    this.analysisDomain = analysisDomain;
    analysisDomain.onResultChanged(DART_TEMPLATES).listen(onResult);
    analysisDomain.onResultChanged(HTML_TEMPLATES).listen(onResult);
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
        LibrarySpecificUnit target =
            new LibrarySpecificUnit(librarySource, source);
        // directives
        {
          List<AbstractDirective> directives =
              context.getResult(target, DIRECTIVES_IN_UNIT);
          for (AbstractDirective template in directives) {
            _addDirectiveRegions(collector, lineInfo, template);
          }
        }
        // templates
        {
          List<Template> templates = context.getResult(target, DART_TEMPLATES);
          for (Template template in templates) {
            _addTemplateRegions(collector, lineInfo, template);
          }
        }
        // views
        {
          List<View> views = context.getResult(target, VIEWS);
          for (View view in views) {
            _addViewRegions(collector, lineInfo, view);
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
    for (InputElement input in directive.inputs) {
      engine.PropertyAccessorElement setter = input.setter;
      if (setter == null) {
        continue;
      }
      LineInfo_Location offsetLineLocation =
          lineInfo.getLocation(setter.nameOffset);
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
              element.nameLength,
              offsetLineLocation.lineNumber,
              offsetLineLocation.columnNumber));
    }
  }

  void _addViewRegions(
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
    List<Source> librarySources = context.getLibrariesContaining(source);
    for (Source librarySource in librarySources) {
      // directives
      {
        List<AbstractDirective> directives = context.getResult(
            new LibrarySpecificUnit(librarySource, source), DIRECTIVES_IN_UNIT);
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
    for (InputElement input in directive.inputs) {
      engine.PropertyAccessorElement setter = input.setter;
      if (setter == null) {
        continue;
      }
      List<int> offsets = elementsOffsets[setter];
      if (offsets == null) {
        offsets = <int>[setter.nameOffset];
        elementsOffsets[setter] = offsets;
      }
      offsets.add(input.setterRange.offset);
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
      int length = angularElement.nameLength;
      protocol.Element protocolElement = _newProtocolElement(angularElement);
      protocol.Occurrences occurrences =
          new protocol.Occurrences(protocolElement, offsets, length);
      collector.addOccurrences(occurrences);
    });
  }

  engine.Element _canonicalizeElement(engine.Element element) {
    if (element is engine.PropertyAccessorElement) {
      element = (element as engine.PropertyAccessorElement).variable;
    }
    if (element is Member) {
      element = (element as Member).baseElement;
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
    return protocol.convertElement(dartElement);
  }
}

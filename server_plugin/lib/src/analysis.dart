library angular2.src.analysis.server_plugin.index;

import 'package:analysis_server/analysis/analysis_domain.dart';
import 'package:analysis_server/analysis/navigation_core.dart';
import 'package:analysis_server/src/protocol.dart';
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
      analysisDomain.scheduleNotification(
          result.context, result.target.source, AnalysisService.NAVIGATION);
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
          ElementKind.UNKNOWN,
          new Location(
              element.source.fullName,
              element.nameOffset,
              element.name.length,
              offsetLineLocation.lineNumber,
              offsetLineLocation.columnNumber));
    }
  }
}

import 'dart:async';
import 'dart:collection';
import 'package:analyzer/src/summary/idl.dart';
import 'package:analyzer/src/summary/format.dart';
import 'package:analysis_server/src/analysis_server.dart';
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analysis_server/plugin/protocol/protocol.dart' as protocol;
import 'package:analysis_server/src/protocol_server.dart' as protocol;
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:angular_analyzer_plugin/src/directive_extraction.dart';
import 'package:angular_analyzer_plugin/src/view_extraction.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/resolver.dart';
import 'package:angular_analyzer_plugin/src/converter.dart';
import 'package:angular_analyzer_plugin/src/directive_linking.dart';
import 'package:angular_analyzer_plugin/src/summary/idl.dart';
import 'package:angular_analyzer_plugin/src/summary/format.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:tuple/tuple.dart';

class AngularDriver
    implements
        AnalysisDriverGeneric,
        FileDirectiveProvider,
        DirectiveLinkerEnablement {
  final AnalysisServer server;
  final AnalysisDriverScheduler _scheduler;
  final AnalysisDriver dartDriver;
  SourceFactory _sourceFactory;
  final LinkedHashSet<String> _addedFiles = new LinkedHashSet<String>();
  final LinkedHashSet<String> _dartFiles = new LinkedHashSet<String>();
  final LinkedHashSet<String> _changedFiles = new LinkedHashSet<String>();
  final Set<String> _requestedFiles = new HashSet<String>();
  final Set<String> _filesToAnalyze = new HashSet<String>();
  final Set<Tuple2<String, String>> _htmlViewsToAnalyze =
      new HashSet<Tuple2<String, String>>();
  final ByteStore byteStore;

  AngularDriver(
    this.server,
    this.dartDriver,
    this._scheduler,
    this.byteStore,
    SourceFactory sourceFactory,
  ) {
    _sourceFactory = sourceFactory.clone();
    _scheduler.add(this);
  }

  bool get hasFilesToAnalyze =>
      _filesToAnalyze.isNotEmpty || _htmlViewsToAnalyze.isNotEmpty;

  bool _ownsFile(String path) {
    return path.endsWith('.dart') || path.endsWith('.html');
  }

  void addFile(String path) {
    if (_ownsFile(path)) {
      _addedFiles.add(path);
      if (path.endsWith('.dart')) {
        _dartFiles.add(path);
      }
      fileChanged(path);
    }
  }

  void fileChanged(String path) {
    if (_ownsFile(path)) {
      _changedFiles.add(path);
    }
    //_statusSupport.transitionToAnalyzing(); ??
    _scheduler.notify(this);
  }

  AnalysisDriverPriority get workPriority {
    if (_requestedFiles.isNotEmpty) {
      return AnalysisDriverPriority.interactive;
    }
    // tasks here?
    if (_filesToAnalyze.isNotEmpty) {
      return AnalysisDriverPriority.general;
    }
    if (_htmlViewsToAnalyze.isNotEmpty) {
      return AnalysisDriverPriority.general;
    }
    if (_changedFiles.isNotEmpty) {
      return AnalysisDriverPriority.general;
    }
    //_statusSupport.transitionToIdle(); ??
    return AnalysisDriverPriority.nothing;
  }

  Future<Null> performWork() async {
    if (_changedFiles.isNotEmpty) {
      _changedFiles.clear();
      _filesToAnalyze.addAll(_dartFiles);
      return;
    }

    if (_requestedFiles.isNotEmpty) {
      final path = _requestedFiles.first;
      try {
        pushDartErrors(path);
        _requestedFiles.remove(path);
      } catch (e) {
        e;
      }
      return;
    }

    if (_filesToAnalyze.isNotEmpty) {
      final path = _filesToAnalyze.first;
      pushDartErrors(path);
      _filesToAnalyze.remove(path);
      return;
    }

    if (_htmlViewsToAnalyze.isNotEmpty) {
      final info = _htmlViewsToAnalyze.first;
      pushHtmlErrors(info.item1, info.item2);
      _htmlViewsToAnalyze.remove(info);
      return;
    }

    return;
  }

  Future<StandardHtml> getStandardHtml() async {
    final source = _sourceFactory.resolveUri(null, DartSdk.DART_HTML);
    final result = await dartDriver.getResult(source.fullName);
    final components = <String, Component>{};
    final events = <String, OutputElement>{};
    final attributes = <String, InputElement>{};
    result.unit.accept(new BuildStandardHtmlComponentsVisitor(
        components, events, attributes, source));

    return new StandardHtml(components, events, attributes);
  }

  List<AnalysisError> deserializeErrors(
      Source source, List<AnalysisDriverUnitError> errors) {
    return errors
        .map((error) {
          final errorName = error.uniqueName;
          final errorCode = angularWarningCodeByUniqueName(errorName) ??
              errorCodeByUniqueName(errorName);
          if (errorCode == null) {
            return null;
          }
          return new AnalysisError.forValues(source, error.offset, error.length,
              errorCode, error.message, error.correction);
        })
        .where((e) => e != null)
        .toList();
  }

  String getHtmlKey(String htmlPath, String dartPath) {
    final dartKey = dartDriver.getResolvedUnitKeyByPath(dartPath);
    final htmlKey = dartDriver.getContentHash(htmlPath);
    htmlKey.addBytes(dartKey.toByteList());
    return htmlKey.toHex() + '.ngresolved';
  }

  Future<Tuple2<LinkedHtmlSummary, ParseResult>> resolveHtml(
      String htmlPath, String dartPath) async {
    final key = getHtmlKey(htmlPath, dartPath);
    final List<int> bytes = byteStore.get(key);
    if (bytes != null) {
      final sum = new LinkedHtmlSummary.fromBuffer(bytes);
      return new Tuple2(sum, null);
    }

    final unlinked = await getDirectives(dartPath);
    final directives = await resynthesizeDirectives(unlinked, dartPath);
    final unit = (await dartDriver.getUnitElement(dartPath)).element;

    if (unit == null) return null;
    final context = unit.context;
    final dartSource = _sourceFactory.forUri("file:" + dartPath);
    final htmlSource = _sourceFactory.forUri("file:" + htmlPath);
    final parsed = await dartDriver.parseFile(htmlPath);
    final htmlContent = parsed.content;
    final standardHtml = await getStandardHtml();

    final tplErrorListener = new RecordingErrorListener();
    final errorReporter = new ErrorReporter(tplErrorListener, dartSource);

    final linker = new ChildDirectiveLinker(this);
    await linker.linkDirectives(directives, unit.library);

    for (final directive in directives) {
      if (directive is Component) {
        final view = directive.view;
        if (view.templateUriSource?.fullName == htmlPath) {
          final template = new Template(view);
          view.template = template;
          final tplParser = new TemplateParser();

          tplParser.parse(htmlContent, htmlSource, offset: view.templateOffset);
          final document = tplParser.document;
          final EmbeddedDartParser parser = new EmbeddedDartParser(htmlSource,
              tplErrorListener, context.typeProvider, errorReporter);

          template.ast =
              new HtmlTreeConverter(parser, htmlSource, tplErrorListener)
                  .convert(firstElement(tplParser.document));
          template.ast.accept(new NgContentRecorder(template, errorReporter));
          setIgnoredErrors(template, document);
          final resolver = new TemplateResolver(
              context.typeProvider,
              standardHtml.components.values,
              standardHtml.events,
              standardHtml.attributes,
              tplErrorListener);
          resolver.resolve(template);
        }
      }
    }

    final sum = new LinkedHtmlSummaryBuilder()
      ..errors = summarizeErrors(tplErrorListener.errors);
    final List<int> newBytes = sum.toBuffer();
    byteStore.put(key, newBytes);
    return new Tuple2(sum, parsed);
  }

  Future pushHtmlErrors(String htmlPath, String dartPath) async {
    final tuple = await resolveHtml(htmlPath, dartPath);
    final parsed = tuple.item2 ?? await dartDriver.parseFile(htmlPath);
    final sum = tuple.item1;
    final source = _sourceFactory.resolveUri(null, 'file:' + htmlPath);
    final errors =
        new List<AnalysisError>.from(deserializeErrors(source, sum.errors));
    final lineInfo = parsed.lineInfo;
    final serverErrors = protocol.doAnalysisError_listFromEngine(
        dartDriver.analysisOptions, lineInfo, errors);
    final params = new protocol.AnalysisErrorsParams(htmlPath, serverErrors);
    server.sendNotification(params.toNotification());
  }

  Future<List<AnalysisError>> getHtmlErrors(
      String htmlPath, String dartPath) async {
    final tuple = await resolveHtml(htmlPath, dartPath);
    final source = _sourceFactory.resolveUri(null, 'file:' + htmlPath);
    return deserializeErrors(source, tuple.item1.errors);
  }

  Future pushDartErrors(String path) async {
    final sum = await resolveDart(path);
    final parsed = await dartDriver.parseFile(path);
    final source = _sourceFactory.resolveUri(null, 'file:' + path);
    final errors =
        new List<AnalysisError>.from(deserializeErrors(source, sum.errors));
    final lineInfo = parsed.lineInfo;
    final serverErrors = protocol.doAnalysisError_listFromEngine(
        dartDriver.analysisOptions, lineInfo, errors);
    final params = new protocol.AnalysisErrorsParams(path, serverErrors);
    server.sendNotification(params.toNotification());
  }

  Future<List<AnalysisError>> getDartErrors(String path) async {
    final result = await resolveDart(path);
    final source = _sourceFactory.resolveUri(null, 'file:' + path);
    return deserializeErrors(source, result.errors);
  }

  Future<LinkedDartSummary> resolveDart(String path) async {
    final key =
        dartDriver.getResolvedUnitKeyByPath(path).toHex() + '.ngresolved';
    final List<int> bytes = byteStore.get(key);
    if (bytes != null) {
      final sum = new LinkedDartSummary.fromBuffer(bytes);

      for (final htmlView in sum.referencedHtmlFiles) {
        _htmlViewsToAnalyze.add(new Tuple2(htmlView, path));
      }

      return sum;
    }

    final unlinked = await getDirectives(path);
    final directives = await resynthesizeDirectives(unlinked, path);
    final unit = (await dartDriver.getUnitElement(path)).element;
    if (unit == null) return null;
    final context = unit.context;
    final source = unit.source;

    final errors = new List<AnalysisError>.from(
        deserializeErrors(source, unlinked.errors));
    final tplErrorListener = new RecordingErrorListener();
    final errorReporter = new ErrorReporter(tplErrorListener, source);
    final standardHtml = await getStandardHtml();

    final linker = new ChildDirectiveLinker(this);
    await linker.linkDirectives(directives, unit.library);
    final List<String> htmlViews = [];

    for (final directive in directives) {
      if (directive is Component) {
        final view = directive.view;
        if (view.templateText != '') {
          final template = new Template(view);
          view.template = template;
          final tplParser = new TemplateParser();

          tplParser.parse(view.templateText, source,
              offset: view.templateOffset);
          final document = tplParser.document;
          final EmbeddedDartParser parser = new EmbeddedDartParser(
              source, tplErrorListener, context.typeProvider, errorReporter);

          template.ast = new HtmlTreeConverter(parser, source, tplErrorListener)
              .convert(firstElement(tplParser.document));
          template.ast.accept(new NgContentRecorder(template, errorReporter));
          setIgnoredErrors(template, document);
          final resolver = new TemplateResolver(
              context.typeProvider,
              standardHtml.components.values,
              standardHtml.events,
              standardHtml.attributes,
              tplErrorListener);
          resolver.resolve(template);
        } else if (view.templateUriSource != null) {
          _htmlViewsToAnalyze
              .add(new Tuple2(view.templateUriSource.fullName, path));
          htmlViews.add(view.templateUriSource.fullName);
        }
      }
    }

    errors.addAll(tplErrorListener.errors);
    final lineInfo = context.getLineInfo(source);
    final serverErrors = protocol.doAnalysisError_listFromEngine(
        context.analysisOptions, lineInfo, errors);
    final params = new protocol.AnalysisErrorsParams(path, serverErrors);
    server.sendNotification(params.toNotification());

    final sum = new LinkedDartSummaryBuilder()
      ..errors = summarizeErrors(errors)
      ..referencedHtmlFiles = htmlViews;
    final List<int> newBytes = sum.toBuffer();
    byteStore.put(key, newBytes);
    return new Tuple2(sum, null);
  }

  List<AnalysisDriverUnitError> summarizeErrors(List<AnalysisError> errors) {
    return errors
        .map((error) => new AnalysisDriverUnitErrorBuilder(
            offset: error.offset,
            length: error.length,
            uniqueName: error.errorCode.uniqueName,
            message: error.message,
            correction: error.correction))
        .toList();
  }

  Source getSource(String path) {
    return _sourceFactory.resolveUri(null, 'file:' + path);
  }

  Future<CompilationUnitElement> getUnit(String path) async {
    return (await dartDriver.getUnitElement(path)).element;
  }

  Future<List<AbstractDirective>> resynthesizeDirectives(
      UnlinkedDartSummary unlinked, String path) async {
    return new DirectiveLinker(this).resynthesizeDirectives(unlinked, path);
  }

  Future<List<AbstractDirective>> getUnlinkedDirectives(path) async {
    return getDirectives(path)
        .then((summary) => resynthesizeDirectives(summary, path));
  }

  Future<UnlinkedDartSummary> getDirectives(path) async {
    final key = dartDriver.getContentHash(path).toHex() + '.ngunlinked';
    final List<int> bytes = byteStore.get(key);
    if (bytes != null) {
      return new UnlinkedDartSummary.fromBuffer(bytes);
    }

    final result = await dartDriver.getResult(path);
    if (result == null) {
      return null;
    }

    final context = result.unit.element.context;
    final ast = result.unit;
    final source = result.unit.element.source;
    final extractor =
        new DirectiveExtractor(ast, context.typeProvider, source, context);
    final directives =
        new List<AbstractDirective>.from(extractor.getDirectives());

    final viewExtractor = new ViewExtractor(ast, directives, context, source);
    viewExtractor.getViews();

    final dirSums = <SummarizedDirectiveBuilder>[];
    for (final directive in directives) {
      final className = directive.classElement.name;
      final selector = directive.selector.originalString;
      final selectorOffset = directive.selector.offset;
      final exportAs = directive?.exportAs?.name;
      final exportAsOffset = directive?.exportAs?.nameOffset;
      final inputs = <SummarizedBindableBuilder>[];
      final outputs = <SummarizedBindableBuilder>[];
      for (final input in directive.inputs) {
        final name = input.name;
        final nameOffset = input.nameOffset;
        final propName = input.setter.name;
        final propNameOffset = input.setter.nameOffset;
        inputs.add(new SummarizedBindableBuilder()
          ..name = name
          ..nameOffset = nameOffset
          ..propName = propName
          ..propNameOffset = propNameOffset);
      }
      for (final output in directive.outputs) {
        final name = output.name;
        final nameOffset = output.nameOffset;
        final propName = output.getter.name;
        final propNameOffset = output.getterRange.offset;
        inputs.add(new SummarizedBindableBuilder()
          ..name = name
          ..nameOffset = nameOffset
          ..propName = propName
          ..propNameOffset = propNameOffset);
      }
      final dirUseSums = <SummarizedDirectiveUseBuilder>[];
      var templateUrl;
      var templateText;
      var templateTextOffset;
      if (directive is Component) {
        templateUrl = directive.view?.templateUriSource?.fullName;
        templateText = directive.view?.templateText;
        templateTextOffset = directive.view.templateOffset;
        for (final directiveName in directive.view.directiveNames) {
          final prefix = null; // TODO track this
          dirUseSums.add(new SummarizedDirectiveUseBuilder()
            ..name = directiveName
            ..prefix = prefix);
        }
      }

      dirSums.add(new SummarizedDirectiveBuilder()
        ..isComponent = directive is Component
        ..selectorStr = selector
        ..selectorOffset = selectorOffset
        ..decoratedClassName = className
        ..exportAs = exportAs
        ..exportAsOffset = exportAsOffset
        ..templateText = templateText
        ..templateOffset = templateTextOffset
        ..templateUrl = templateUrl
        ..ngContents = [] // TODO ngContents
        ..inputs = inputs
        ..outputs = outputs
        ..subdirectives = dirUseSums);
    }

    final errors = new List<AnalysisError>.from(extractor.errorListener.errors);
    errors.addAll(viewExtractor.errorListener.errors);
    final sum = new UnlinkedDartSummaryBuilder()
      ..directiveSummaries = dirSums
      ..errors = summarizeErrors(errors);
    final List<int> newBytes = sum.toBuffer();
    byteStore.put(key, newBytes);
    return sum;
  }
}

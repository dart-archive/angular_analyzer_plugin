import 'dart:convert';
import 'dart:async';
import 'dart:collection';
import 'package:analysis_server/src/analysis_server.dart';
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analysis_server/plugin/protocol/protocol_dart.dart' as protocol;
import 'package:analysis_server/src/protocol_server.dart' as protocol;
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/summary/api_signature.dart';
import 'package:analyzer/src/generated/resolver.dart' show TypeProvider;
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:angular_analyzer_plugin/src/file_tracker.dart';
import 'package:angular_analyzer_plugin/src/from_file_prefixed_error.dart';
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
import 'package:analyzer/src/dart/analysis/file_state.dart';
import 'package:crypto/crypto.dart';

class AngularDriver
    implements
        AnalysisDriverGeneric,
        FileDirectiveProvider,
        DirectiveLinkerEnablement,
        FileHasher {
  final AnalysisServer server;
  final AnalysisDriverScheduler _scheduler;
  final AnalysisDriver dartDriver;
  final FileContentOverlay _contentOverlay;
  StandardHtml standardHtml = null;
  StandardAngular standardAngular = null;
  SourceFactory _sourceFactory;
  final _addedFiles = new LinkedHashSet<String>();
  final _dartFiles = new LinkedHashSet<String>();
  final _changedFiles = new LinkedHashSet<String>();
  final _requestedDartFiles = new Map<String, List<Completer>>();
  final _requestedHtmlFiles = new Map<String, List<Completer>>();
  final _filesToAnalyze = new HashSet<String>();
  final _htmlFilesToAnalyze = new HashSet<String>();
  final ByteStore byteStore;
  FileTracker _fileTracker;
  final lastSignatures = <String, String>{};
  bool _hasAngularImported = false;

  AngularDriver(this.server, this.dartDriver, this._scheduler, this.byteStore,
      SourceFactory sourceFactory, this._contentOverlay) {
    _sourceFactory = sourceFactory.clone();
    _scheduler.add(this);
    _fileTracker = new FileTracker(this);
    _hasAngularImported =
        _sourceFactory.resolveUri(null, "package:angular2/angular2.dart") !=
            null;
  }

  ApiSignature getUnitElementHash(String path) {
    return dartDriver.getUnitKeyByPath(path);
  }

  bool get hasFilesToAnalyze =>
      _filesToAnalyze.isNotEmpty ||
      _htmlFilesToAnalyze.isNotEmpty ||
      _requestedDartFiles.isNotEmpty ||
      _requestedHtmlFiles.isNotEmpty;

  bool _ownsFile(String path) {
    return path.endsWith('.dart') || path.endsWith('.html');
  }

  /**
   * This is implemented in order to satisfy the [AnalysisDriverGeneric]
   * interface. Ideally, we analyze these files first. For the moment, this lets
   * the analysis server team add this method to the interface without breaking
   * any code.
   */
  void set priorityFiles(List<String> priorityPaths) {
    // TODO analyze these files first
  }

  /**
    * Notify the driver that the client is going to stop using it.
    */
  void dispose() {
    // TODO anything we need to do here?
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
      if (path.endsWith('.html')) {
        _fileTracker.rehashHtmlContents(path);

        _htmlFilesToAnalyze.add(path);
        for (final path in _fileTracker.getHtmlPathsReferencingHtml(path)) {
          _htmlFilesToAnalyze.add(path);
        }
        for (final path in _fileTracker.getDartPathsAffectedByHtml(path)) {
          _filesToAnalyze.add(path);
        }
      } else {
        _changedFiles.add(path);
      }
    }
    _scheduler.notify(this);
  }

  Future<List<AnalysisError>> requestDartErrors(String path) {
    var completer = new Completer<List<AnalysisError>>();
    _requestedDartFiles
        .putIfAbsent(path, () => <Completer<List<AnalysisError>>>[])
        .add(completer);
    _scheduler.notify(this);
    return completer.future;
  }

  Future<List<AnalysisError>> requestHtmlErrors(String path) {
    var completer = new Completer<List<AnalysisError>>();
    _requestedHtmlFiles
        .putIfAbsent(path, () => <Completer<List<AnalysisError>>>[])
        .add(completer);
    _scheduler.notify(this);
    return completer.future;
  }

  AnalysisDriverPriority get workPriority {
    if (standardHtml == null) {
      return AnalysisDriverPriority.interactive;
    }
    if (_requestedDartFiles.isNotEmpty) {
      return AnalysisDriverPriority.interactive;
    }
    if (_requestedHtmlFiles.isNotEmpty) {
      return AnalysisDriverPriority.interactive;
    }
    if (_filesToAnalyze.isNotEmpty) {
      return AnalysisDriverPriority.general;
    }
    if (_htmlFilesToAnalyze.isNotEmpty) {
      return AnalysisDriverPriority.general;
    }
    if (_changedFiles.isNotEmpty) {
      return AnalysisDriverPriority.general;
    }
    return AnalysisDriverPriority.nothing;
  }

  Future<Null> performWork() async {
    if (standardHtml == null) {
      getStandardHtml();
      return;
    }

    if (_hasAngularImported && standardAngular == null) {
      getStandardAngular();
      return;
    }

    if (_changedFiles.isNotEmpty) {
      _changedFiles.clear();
      _filesToAnalyze.addAll(_dartFiles);
      return;
    }

    if (_requestedDartFiles.isNotEmpty) {
      final path = _requestedDartFiles.keys.first;
      final completers = _requestedDartFiles.remove(path);
      // Note: We can't use await here, or the dart analysis becomes a future in
      // a queue that won't be completed until the scheduler schedules the dart
      // driver, which doesn't happen because its waiting for us.
      resolveDart(path, onlyIfChangedSignature: false).then((result) {
        completers
            .forEach((completer) => completer.complete(result?.errors ?? []));
      }, onError: (e) {
        completers.forEach((completer) => completer.completeError(e));
      });

      return;
    }

    if (_requestedHtmlFiles.isNotEmpty) {
      final path = _requestedHtmlFiles.keys.first;
      final completers = _requestedHtmlFiles.remove(path);
      // Note: We can't use await here, or the dart analysis becomes a future in
      // a queue that won't be completed until the scheduler schedules the dart
      // driver, which doesn't happen because its waiting for us.
      // ALSO assume .dart and .html paths correlate, otherwise we'd have to
      // wait for all dart analysis to complete.
      Future resolvedHtml;

      // Try resolving HTML using the existing dart/html relationships which may
      // be already known. However, if we don't see any relationships, try using
      // the .dart equivalent. Better than no result -- the real one WILL come.
      if (_fileTracker.getDartPathsReferencingHtml(path).isEmpty) {
        resolvedHtml = resolveHtmlFrom(path, path.replaceAll(".html", ".dart"));
      } else {
        resolvedHtml = resolveHtml(path);
      }

      // After whichever resolution is complete, push errors.
      resolvedHtml.then((result) {
        completers
            .forEach((completer) => completer.complete(result?.errors ?? []));
      }, onError: (e) {
        completers.forEach((completer) => completer.completeError(e));
      });

      return;
    }

    if (_filesToAnalyze.isNotEmpty) {
      final path = _filesToAnalyze.first;
      pushDartErrors(path);
      _filesToAnalyze.remove(path);
      return;
    }

    if (_htmlFilesToAnalyze.isNotEmpty) {
      final path = _htmlFilesToAnalyze.first;
      pushHtmlErrors(path);
      _htmlFilesToAnalyze.remove(path);
      return;
    }

    return;
  }

  Future<StandardHtml> getStandardHtml() async {
    if (standardHtml == null) {
      final source = _sourceFactory.resolveUri(null, DartSdk.DART_HTML);

      final result = await dartDriver.getResult(source.fullName);

      final components = <String, Component>{};
      final events = <String, OutputElement>{};
      final attributes = <String, InputElement>{};
      result.unit.accept(new BuildStandardHtmlComponentsVisitor(
          components, events, attributes, source));

      standardHtml = new StandardHtml(components, events, attributes);
    }

    return standardHtml;
  }

  Future<StandardAngular> getStandardAngular() async {
    if (standardAngular == null) {
      final source =
          _sourceFactory.resolveUri(null, "package:angular2/angular2.dart");

      if (source == null) {
        return standardAngular;
      }

      final result = await dartDriver.getResult(source.fullName);

      final namespace = result.unit.element.library.exportNamespace;

      standardAngular = new StandardAngular(
          queryList: namespace.get("QueryList"),
          elementRef: namespace.get("ElementRef"),
          templateRef: namespace.get("TemplateRef"));
    }

    return standardAngular;
  }

  List<AnalysisError> deserializeFromPathErrors(
      Source source, List<SummarizedAnalysisErrorFromPath> errors) {
    return errors
        .map((error) {
          final originalError = deserializeError(source, error.originalError);
          if (originalError == null) {
            return null;
          }
          return new FromFilePrefixedError.fromPath(error.path, originalError);
        })
        .where((e) => e != null)
        .toList();
  }

  List<AnalysisError> deserializeErrors(
      Source source, List<SummarizedAnalysisError> errors) {
    return errors
        .map((error) {
          return deserializeError(source, error);
        })
        .where((e) => e != null)
        .toList();
  }

  AnalysisError deserializeError(Source source, SummarizedAnalysisError error) {
    final errorName = error.errorCode;
    final errorCode = angularWarningCodeByUniqueName(errorName) ??
        errorCodeByUniqueName(errorName);
    if (errorCode == null) {
      return null;
    }
    return new AnalysisError.forValues(source, error.offset, error.length,
        errorCode, error.message, error.correction);
  }

  String getHtmlKey(String htmlPath) {
    final key = _fileTracker.getHtmlSignature(htmlPath);
    return key.toHex() + '.ngresolved';
  }

  ApiSignature getContentHash(String path) {
    final key = new ApiSignature();
    List<int> contentBytes = UTF8.encode(getFileContent(path));
    key.addBytes(md5.convert(contentBytes).bytes);
    return key;
  }

  String getFileContent(String path) {
    return _contentOverlay[path] ??
        ((source) =>
            source.exists() ? source.contents.data : "")(getSource(path));
  }

  Future<DirectivesResult> resolveHtml(
    String htmlPath, {
    bool ignoreCache: false,
  }) async {
    final key = getHtmlKey(htmlPath);
    final htmlSource = _sourceFactory.forUri("file:" + htmlPath);
    final List<int> bytes = byteStore.get(key);
    if (!ignoreCache && bytes != null) {
      final summary = new LinkedHtmlSummary.fromBuffer(bytes);
      final errors = new List<AnalysisError>.from(
          deserializeErrors(htmlSource, summary.errors))
        ..addAll(deserializeFromPathErrors(htmlSource, summary.errorsFromPath));
      return new DirectivesResult([], errors);
    }

    final result = new DirectivesResult([], []);

    for (final dartContext
        in _fileTracker.getDartPathsReferencingHtml(htmlPath)) {
      final pairResult = await resolveHtmlFrom(htmlPath, dartContext);
      result.directives.addAll(pairResult.directives);
      result.errors.addAll(pairResult.errors);
    }

    final summary = new LinkedHtmlSummaryBuilder()
      ..errors = summarizeErrors(result.errors
          .where((error) => error is! FromFilePrefixedError)
          .toList())
      ..errorsFromPath = result.errors
          .where((error) => error is FromFilePrefixedError)
          .map((error) => new SummarizedAnalysisErrorFromPathBuilder()
            ..path = (error as FromFilePrefixedError).fromSourcePath
            ..originalError =
                summarizeError((error as FromFilePrefixedError).originalError))
          .toList();
    final List<int> newBytes = summary.toBuffer();
    byteStore.put(key, newBytes);

    return result;
  }

  Future<List<Template>> getTemplatesForFile(String filePath) async {
    var templates = <Template>[];
    var isDartFile = filePath.endsWith('.dart');
    if (!isDartFile && !filePath.endsWith('.html')) {
      return templates;
    }
    var directiveResults = isDartFile
        ? await resolveDart(
            filePath,
            withDirectives: true,
            onlyIfChangedSignature: false,
          )
        : await resolveHtml(filePath, ignoreCache: true);
    var directives = directiveResults.directives;
    if (directives == null) {
      return templates;
    }
    for (var directive in directives) {
      if (directive is Component) {
        var view = directive.view;
        var match = isDartFile
            ? view.source.toString() == filePath
            : view.templateUriSource?.fullName == filePath;
        if (match) {
          templates.add(view.template);
        }
      }
    }
    return templates;
  }

  Future<DirectivesResult> resolveHtmlFrom(
      String htmlPath, String dartPath) async {
    final result = await getDirectives(dartPath);
    final directives = result.directives;
    final unit = (await dartDriver.getUnitElement(dartPath)).element;
    final htmlSource = _sourceFactory.forUri("file:" + htmlPath);

    if (unit == null) return null;
    final context = unit.context;
    final dartSource = _sourceFactory.forUri("file:" + dartPath);
    final htmlContent = getFileContent(htmlPath);
    final standardHtml = await getStandardHtml();

    final errors = <AnalysisError>[];
    // ignore link errors, they are exposed when resolving dart
    final linkErrorListener = new IgnoringErrorListener();
    final linkErrorReporter = new ErrorReporter(linkErrorListener, dartSource);

    final linker = new ChildDirectiveLinker(
        this, await getStandardAngular(), linkErrorReporter);
    await linker.linkDirectives(directives, unit.library);
    final attrValidator = new AttributeAnnotationValidator(linkErrorReporter);
    directives.forEach(attrValidator.validate);

    for (final directive in directives) {
      if (directive is Component) {
        final view = directive.view;
        if (view.templateUriSource?.fullName == htmlPath) {
          final tplErrorListener = new RecordingErrorListener();
          final errorReporter = new ErrorReporter(tplErrorListener, dartSource);
          final template = new Template(view);
          view.template = template;
          final tplParser = new TemplateParser();

          tplParser.parse(htmlContent, htmlSource);
          final document = tplParser.document;
          final EmbeddedDartParser parser = new EmbeddedDartParser(
              htmlSource, tplErrorListener, errorReporter);

          template.ast =
              new HtmlTreeConverter(parser, htmlSource, tplErrorListener)
                  .convert(firstElement(tplParser.document));
          template.ast.accept(new NgContentRecorder(directive, errorReporter));
          setIgnoredErrors(template, document);
          final resolver = new TemplateResolver(
              context.typeProvider,
              standardHtml.components.values.toList(),
              standardHtml.events,
              standardHtml.attributes,
              await getStandardAngular(),
              tplErrorListener);
          resolver.resolve(template);

          bool rightErrorType(AnalysisError e) =>
              !view.template.ignoredErrors.contains(e.errorCode.name);
          String shorten(String filename) {
            final index = filename.lastIndexOf('.');
            return index == -1 ? filename : filename.substring(0, index);
          }

          errors.addAll(tplParser.parseErrors.where(rightErrorType));

          if (shorten(view.source.fullName) !=
              shorten(view.templateSource.fullName)) {
            errors.addAll(tplErrorListener.errors
                .where(rightErrorType)
                .map((e) => new FromFilePrefixedError(view.source, e)));
          } else {
            errors.addAll(tplErrorListener.errors.where(rightErrorType));
          }
        }
      }
    }

    return new DirectivesResult(directives, errors);
  }

  Future<List<NgContent>> getHtmlNgContent(String path) async {
    final key = getContentHash(path).toHex() + '.ngunlinked';
    final List<int> bytes = byteStore.get(key);
    final source = getSource(path);
    if (bytes != null) {
      return new DirectiveLinker(this).deserializeNgContents(
          new UnlinkedHtmlSummary.fromBuffer(bytes).ngContents, source);
    }

    final htmlContent = getFileContent(path);
    final tplErrorListener = new RecordingErrorListener();
    final errorReporter = new ErrorReporter(tplErrorListener, source);

    final tplParser = new TemplateParser();

    tplParser.parse(htmlContent, source);
    final EmbeddedDartParser parser =
        new EmbeddedDartParser(source, tplErrorListener, errorReporter);

    final ast = new HtmlTreeConverter(parser, source, tplErrorListener)
        .convert(firstElement(tplParser.document));
    final contents = <NgContent>[];
    ast.accept(new NgContentRecorder.forFile(contents, source, errorReporter));

    final summary = new UnlinkedHtmlSummaryBuilder()
      ..ngContents = serializeNgContents(contents);
    final List<int> newBytes = summary.toBuffer();
    byteStore.put(key, newBytes);

    return contents;
  }

  Future pushHtmlErrors(String htmlPath) async {
    final errors = (await resolveHtml(htmlPath)).errors;
    final lineInfo = new LineInfo.fromContent(getFileContent(htmlPath));
    final serverErrors = protocol.doAnalysisError_listFromEngine(
        dartDriver.analysisOptions, lineInfo, errors);
    server.notificationManager
        .recordAnalysisErrors("angularPlugin", htmlPath, serverErrors);
  }

  Future pushDartNavigation(String path) async {}

  Future pushDartOccurrences(String path) async {}

  Future pushDartErrors(String path) async {
    final result = await resolveDart(path);
    if (result == null) return;
    final errors = result.errors;
    final lineInfo = new LineInfo.fromContent(getFileContent(path));
    final serverErrors = protocol.doAnalysisError_listFromEngine(
        dartDriver.analysisOptions, lineInfo, errors);
    server.notificationManager
        .recordAnalysisErrors("angularPlugin", path, serverErrors);
  }

  Future<DirectivesResult> resolveDart(String path,
      {bool withDirectives: false, bool onlyIfChangedSignature: true}) async {
    final baseKey = await dartDriver.getUnitElementSignature(path);

    // This happens when the path is..."hidden by a generated file"..whch I
    // don't understand, but, can protect against. Should not be analyzed.
    // TODO detect this on file add rather than on file analyze.
    if (baseKey == null) {
      _dartFiles.remove(path);
      return null;
    }

    final key = baseKey + '.ngresolved';

    if (lastSignatures[path] == key && onlyIfChangedSignature) {
      return null;
    }

    lastSignatures[path] = key;

    if (!withDirectives) {
      final List<int> bytes = byteStore.get(key);
      if (bytes != null) {
        final summary = new LinkedDartSummary.fromBuffer(bytes);

        for (final htmlPath in summary.referencedHtmlFiles) {
          _htmlFilesToAnalyze.add(htmlPath);
        }

        _fileTracker.setDartHasTemplate(path, summary.hasDartTemplates);
        _fileTracker.setDartHtmlTemplates(path, summary.referencedHtmlFiles);
        _fileTracker.setDartImports(path, summary.referencedDartFiles);

        return new DirectivesResult(
            [], deserializeErrors(getSource(path), summary.errors));
      }
    }

    final result = await getDirectives(path);
    final directives = result.directives;
    final unit = (await dartDriver.getUnitElement(path)).element;
    if (unit == null) return null;
    final context = unit.context;
    final source = unit.source;

    final errors = new List<AnalysisError>.from(result.errors);
    final standardHtml = await getStandardHtml();

    final linkErrorListener = new RecordingErrorListener();
    final linkErrorReporter = new ErrorReporter(linkErrorListener, source);

    final linker = new ChildDirectiveLinker(
        this, await getStandardAngular(), linkErrorReporter);
    await linker.linkDirectives(directives, unit.library);
    final attrValidator = new AttributeAnnotationValidator(linkErrorReporter);
    directives.forEach(attrValidator.validate);
    errors.addAll(linkErrorListener.errors);

    final List<String> htmlViews = [];
    final List<String> usesDart = [];

    bool hasDartTemplate = false;
    for (final directive in directives) {
      if (directive is Component) {
        final view = directive.view;
        if ((view?.templateText ?? '') != '') {
          hasDartTemplate = true;
          final tplErrorListener = new RecordingErrorListener();
          final errorReporter = new ErrorReporter(tplErrorListener, source);
          final template = new Template(view);
          view.template = template;
          final tplParser = new TemplateParser();

          tplParser.parse(view.templateText, source,
              offset: view.templateOffset);
          final document = tplParser.document;
          final EmbeddedDartParser parser =
              new EmbeddedDartParser(source, tplErrorListener, errorReporter);

          template.ast = new HtmlTreeConverter(parser, source, tplErrorListener)
              .convert(firstElement(tplParser.document));
          template.ast.accept(new NgContentRecorder(directive, errorReporter));
          setIgnoredErrors(template, document);
          final resolver = new TemplateResolver(
              context.typeProvider,
              standardHtml.components.values,
              standardHtml.events,
              standardHtml.attributes,
              await getStandardAngular(),
              tplErrorListener);
          resolver.resolve(template);
          errors.addAll(tplParser.parseErrors.where(
              (e) => !view.template.ignoredErrors.contains(e.errorCode.name)));
          errors.addAll(tplErrorListener.errors.where(
              (e) => !view.template.ignoredErrors.contains(e.errorCode.name)));
        } else if (view?.templateUriSource != null) {
          _htmlFilesToAnalyze.add(view.templateUriSource.fullName);
          htmlViews.add(view.templateUriSource.fullName);
        }

        for (AbstractDirective subDirective in (view?.directives ?? [])) {
          usesDart.add(subDirective.classElement.source.fullName);
        }
      }
    }

    _fileTracker.setDartHasTemplate(path, hasDartTemplate);
    _fileTracker.setDartHtmlTemplates(path, htmlViews);
    _fileTracker.setDartImports(path, usesDart);

    final summary = new LinkedDartSummaryBuilder()
      ..errors = summarizeErrors(errors)
      ..referencedHtmlFiles = htmlViews
      ..referencedDartFiles = usesDart
      ..hasDartTemplates = hasDartTemplate;
    final List<int> newBytes = summary.toBuffer();
    byteStore.put(key, newBytes);
    return new DirectivesResult(directives, errors);
  }

  List<SummarizedAnalysisError> summarizeErrors(List<AnalysisError> errors) {
    return errors.map((error) => summarizeError(error)).toList();
  }

  SummarizedAnalysisError summarizeError(AnalysisError error) {
    return new SummarizedAnalysisErrorBuilder(
        offset: error.offset,
        length: error.length,
        errorCode: error.errorCode.uniqueName,
        message: error.message,
        correction: error.correction);
  }

  Source getSource(String path) =>
      _sourceFactory.resolveUri(null, 'file:' + path);

  Future<CompilationUnitElement> getUnit(String path) async {
    return (await dartDriver.getUnitElement(path)).element;
  }

  Future<List<AbstractDirective>> resynthesizeDirectives(
      UnlinkedDartSummary unlinked, String path) async {
    return new DirectiveLinker(this).resynthesizeDirectives(unlinked, path);
  }

  Future<List<AbstractDirective>> getUnlinkedDirectives(path) async {
    return (await getDirectives(path)).directives;
  }

  Future<DirectivesResult> getDirectives(path) async {
    final key = getContentHash(path).toHex() + '.ngunlinked';
    final List<int> bytes = byteStore.get(key);
    if (bytes != null) {
      final summary = new UnlinkedDartSummary.fromBuffer(bytes);
      return new DirectivesResult(await resynthesizeDirectives(summary, path),
          deserializeErrors(getSource(path), summary.errors));
    }

    final dartResult = await dartDriver.getResult(path);
    if (dartResult == null) {
      return null;
    }

    final context = dartResult.unit.element.context;
    final ast = dartResult.unit;
    final source = dartResult.unit.element.source;
    final extractor =
        new DirectiveExtractor(ast, context.typeProvider, source, context);
    final directives =
        new List<AbstractDirective>.from(extractor.getDirectives());

    final viewExtractor = new ViewExtractor(ast, directives, context, source);
    viewExtractor.getViews();

    final tplErrorListener = new RecordingErrorListener();
    final errorReporter = new ErrorReporter(tplErrorListener, source);

    // collect inline ng-content tags
    for (final directive in directives) {
      if (directive is Component && directive?.view != null) {
        final view = directive.view;
        if ((view.templateText ?? "") != "") {
          final template = new Template(view);
          view.template = template;
          final tplParser = new TemplateParser();

          tplParser.parse(view.templateText, source,
              offset: view.templateOffset);
          final EmbeddedDartParser parser =
              new EmbeddedDartParser(source, tplErrorListener, errorReporter);

          template.ast = new HtmlTreeConverter(parser, source, tplErrorListener)
              .convert(firstElement(tplParser.document));
          template.ast.accept(new NgContentRecorder(directive, errorReporter));
        }
      }
    }

    final errors = new List<AnalysisError>.from(extractor.errorListener.errors);
    errors.addAll(viewExtractor.errorListener.errors);
    final result = new DirectivesResult(directives, errors);
    final summary = serializeDartResult(result);
    final List<int> newBytes = summary.toBuffer();
    byteStore.put(key, newBytes);
    return result;
  }

  UnlinkedDartSummaryBuilder serializeDartResult(DirectivesResult result) {
    final dirSums = serializeDirectives(result.directives);
    final summary = new UnlinkedDartSummaryBuilder()
      ..directiveSummaries = dirSums
      ..errors = summarizeErrors(result.errors);
    return summary;
  }

  List<SummarizedDirectiveBuilder> serializeDirectives(
      List<AbstractDirective> directives) {
    final dirSums = <SummarizedDirectiveBuilder>[];
    for (final directive in directives) {
      final className = directive.classElement.name;
      final selector = directive.selector.originalString;
      final selectorOffset = directive.selector.offset;
      final exportAs = directive?.exportAs?.name;
      final exportAsOffset = directive?.exportAs?.nameOffset;
      final inputs = <SummarizedBindableBuilder>[];
      final outputs = <SummarizedBindableBuilder>[];
      final contentChildFields = <SummarizedContentChildFieldBuilder>[];
      final contentChildrenFields = <SummarizedContentChildFieldBuilder>[];
      for (final input in directive.inputs) {
        final name = input.name;
        final nameOffset = input.nameOffset;
        final propName = input.setter.name.replaceAll('=', '');
        final propNameOffset = input.setterRange.offset;
        inputs.add(new SummarizedBindableBuilder()
          ..name = name
          ..nameOffset = nameOffset
          ..propName = propName
          ..propNameOffset = propNameOffset);
      }
      for (final output in directive.outputs) {
        final name = output.name;
        final nameOffset = output.nameOffset;
        final propName = output.getter.name.replaceAll('=', '');
        final propNameOffset = output.getterRange.offset;
        outputs.add(new SummarizedBindableBuilder()
          ..name = name
          ..nameOffset = nameOffset
          ..propName = propName
          ..propNameOffset = propNameOffset);
      }
      for (final childField in directive.contentChildFields) {
        contentChildFields.add(new SummarizedContentChildFieldBuilder()
          ..fieldName = childField.fieldName
          ..nameOffset = childField.nameRange.offset
          ..nameLength = childField.nameRange.length
          ..typeOffset = childField.typeRange.offset
          ..typeLength = childField.typeRange.length);
      }
      for (final childrenField in directive.contentChildrenFields) {
        contentChildrenFields.add(new SummarizedContentChildFieldBuilder()
          ..fieldName = childrenField.fieldName
          ..nameOffset = childrenField.nameRange.offset
          ..nameLength = childrenField.nameRange.length
          ..typeOffset = childrenField.typeRange.offset
          ..typeLength = childrenField.typeRange.length);
      }
      final dirUseSums = <SummarizedDirectiveUseBuilder>[];
      final ngContents = <SummarizedNgContentBuilder>[];
      String templateUrl;
      int templateUrlOffset;
      int templateUrlLength;
      String templateText;
      int templateTextOffset;
      if (directive is Component && directive.view != null) {
        templateUrl = directive.view?.templateUriSource?.fullName;
        templateUrlOffset = directive.view?.templateUrlRange?.offset;
        templateUrlLength = directive.view?.templateUrlRange?.length;
        templateText = directive.view.templateText;
        templateTextOffset = directive.view.templateOffset;
        for (final reference in directive.view.directiveReferences) {
          dirUseSums.add(new SummarizedDirectiveUseBuilder()
            ..name = reference.name
            ..prefix = reference.prefix
            ..offset = reference.range.offset
            ..length = reference.range.length);
        }
        if (directive.ngContents != null) {
          ngContents.addAll(serializeNgContents(directive.ngContents));
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
        ..templateUrlOffset = templateUrlOffset
        ..templateUrlLength = templateUrlLength
        ..ngContents = ngContents
        ..inputs = inputs
        ..outputs = outputs
        ..subdirectives = dirUseSums
        ..contentChildFields = contentChildFields
        ..contentChildrenFields = contentChildrenFields);
    }

    return dirSums;
  }

  List<SummarizedNgContentBuilder> serializeNgContents(
      List<NgContent> ngContents) {
    return ngContents
        .map((ngContent) => new SummarizedNgContentBuilder()
          ..selectorStr = ngContent.selector?.originalString
          ..selectorOffset = ngContent.selector?.offset
          ..offset = ngContent.offset
          ..length = ngContent.length)
        .toList();
  }
}

class DirectivesResult {
  List<AbstractDirective> directives;
  List<AnalysisError> errors;
  DirectivesResult(this.directives, this.errors);
}

library angular2.src.analysis.analyzer_plugin.src.tasks;

import 'dart:collection';

import 'package:analyzer/src/context/cache.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/src/dart/ast/utilities.dart' as utils;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/exception/exception.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_engine.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/resolver.dart' show TypeProvider;
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/task/dart.dart';
import 'package:analyzer/src/task/general.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/model.dart';
import 'package:analyzer/task/general.dart';
import 'package:angular_analyzer_plugin/src/from_file_prefixed_error.dart';
import 'package:angular_analyzer_plugin/src/converter.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/resolver.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/directive_extraction.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';
import 'package:angular_analyzer_plugin/src/view_extraction.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/angular_html_parser.dart';
import 'package:front_end/src/scanner/errors.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;
import 'package:source_span/source_span.dart';

/**
 * The [html.Document] of an HTML file.
 */
final ResultDescriptor<html.Document> ANGULAR_HTML_DOCUMENT =
    new ResultDescriptor<html.Document>('ANGULAR_HTML_DOCUMENT', null);

/**
 * The analysis errors associated with a [Source] representing an HTML file.
 */
final ListResultDescriptor<AnalysisError> ANGULAR_HTML_DOCUMENT_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_HTML_DOCUMENT_ERRORS', AnalysisError.NO_ERRORS);

/**
 * The [Template]s of a [LibrarySpecificUnit].
 * This result is produced for templates specified directly in Dart files.
 */
final ListResultDescriptor<Template> DART_TEMPLATES =
    new ListResultDescriptor<Template>(
        'ANGULAR_DART_TEMPLATES', Template.EMPTY_LIST);

/**
 * The errors produced while building [DART_TEMPLATES].
 * This result is produced for templates specified directly in Dart files.
 */
final ListResultDescriptor<AnalysisError> DART_TEMPLATES_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_DART_TEMPLATES_ERRORS', AnalysisError.NO_ERRORS);

/**
 * The errors produced while building [DIRECTIVES_IN_UNIT].
 *
 * The list will be empty if there were no errors, but will not be `null`.
 *
 * The result is only available for [LibrarySpecificUnit]s.
 */
final ListResultDescriptor<AnalysisError> DIRECTIVES_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_DIRECTIVES_ERRORS', AnalysisError.NO_ERRORS);

/**
 * The Angular [AbstractDirective]s available for a library.
 *
 * The list will be empty if there were no directives, but will not be `null`.
 *
 * The result is only available for [Source]s representing a library.
 */
final ListResultDescriptor<AbstractDirective> DIRECTIVES_IN_LIBRARY =
    new ListResultDescriptor<AbstractDirective>(
        'ANGULAR_DIRECTIVES_IN_LIBRARY', AbstractDirective.EMPTY_LIST);

/**
 * The Angular [AbstractDirective]s of a [LibrarySpecificUnit].
 *
 * The list will be empty if there were no directives, but will not be `null`.
 *
 * The result is only available for [LibrarySpecificUnit]s.
 */
final ListResultDescriptor<AbstractDirective> DIRECTIVES_IN_UNIT =
    new ListResultDescriptor<AbstractDirective>(
        'ANGULAR_DIRECTIVES_IN_UNIT', AbstractDirective.EMPTY_LIST);

/**
 * The [HtmlTemplate] of a HTML [Source].
 *
 * This result is produced for [View]s.
 */
final ResultDescriptor<HtmlTemplate> HTML_TEMPLATE =
    new ResultDescriptor('ANGULAR_HTML_TEMPLATE', null);

/**
 * The errors produced while building a [HTML_TEMPLATE].
 *
 * This result is produced for [View]s.
 */
final ListResultDescriptor<AnalysisError> HTML_TEMPLATE_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_HTML_TEMPLATE_ERRORS', AnalysisError.NO_ERRORS);

/**
 * The [HtmlTemplate]s of a HTML [Source].
 * Each [HtmlTemplate] corresponds to a single [View] that uses this template.
 *
 * This result is produced for HTML [Source]s.
 */
final ListResultDescriptor<HtmlTemplate> HTML_TEMPLATES =
    new ListResultDescriptor('ANGULAR_HTML_TEMPLATES', HtmlTemplate.EMPTY_LIST);

/**
 * The errors produced while building a [HTML_TEMPLATE]s.
 *
 * This result is produced for HTML [Source]s.
 */
final ListResultDescriptor<AnalysisError> HTML_TEMPLATES_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_HTML_TEMPLATES_ERRORS', AnalysisError.NO_ERRORS);

/**
 * The standard HTML [Component]s.
 *
 * This result is produced for the [AnalysisContext].
 */
final ListResultDescriptor<Component> STANDARD_HTML_COMPONENTS =
    new ListResultDescriptor(
        'ANGULAR_STANDARD_HTML_COMPONENTS', const <Component>[]);

/**
 * The standard HtmlElement [OutputElement]s.
 *
 * This result is produced for the [AnalysisContext].
 */
final ResultDescriptor<Map<String, OutputElement>>
    STANDARD_HTML_ELEMENT_EVENTS =
    new ResultDescriptor<Map<String, OutputElement>>(
        'ANGULAR_STANDARD_HTML_ELEMENT_EVENTS',
        const <String, OutputElement>{});

/**
 * The standard HtmlElement [InputElement]s.
 *
 * This result is produced for the [AnalysisContext].
 */
final ResultDescriptor<Map<String, InputElement>>
    STANDARD_HTML_ELEMENT_ATTRIBUTES =
    new ResultDescriptor<Map<String, InputElement>>(
        'ANGULAR_STANDARD_HTML_ELEMENT_ATTRIBUTES',
        const <String, InputElement>{});

/**
 * The [View]s with this HTML template file.
 *
 * The result is only available for HTML [Source]s.
 */
final ListResultDescriptor<View> TEMPLATE_VIEWS =
    new ListResultDescriptor<View>('ANGULAR_TEMPLATE_VIEWS', View.EMPTY_LIST);

/**
 * The [View]s of a [LibrarySpecificUnit], without looking at what directives
 * they use.
 */
final ListResultDescriptor<View> VIEWS1 =
    new ListResultDescriptor<View>('ANGULAR_VIEWS1', View.EMPTY_LIST);

/**
 * The [View]s of a [LibrarySpecificUnit], including what directives they use.
 */
final ListResultDescriptor<View> VIEWS2 =
    new ListResultDescriptor<View>('ANGULAR_VIEWS2', View.EMPTY_LIST);

/**
 * The errors produced while building [VIEWS1]. Included in [VIEWS_ERRORS2].
 *
 * The list will be empty if there were no errors, but will not be `null`.
 *
 * The result is only available for [LibrarySpecificUnit]s.
 */
final ListResultDescriptor<AnalysisError> VIEWS_ERRORS1 =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_VIEWS_ERRORS1', AnalysisError.NO_ERRORS);

/**
 * The errors produced while building [VIEWS2]. Includes [VIEWS_ERRORS2].
 *
 * The list will be empty if there were no errors, but will not be `null`.
 *
 * The result is only available for [LibrarySpecificUnit]s.
 */
final ListResultDescriptor<AnalysisError> VIEWS_ERRORS2 =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_VIEWS_ERRORS2', AnalysisError.NO_ERRORS);

/**
 * The [View]s with templates in separate HTML files, without including what
 * directives they use.
 *
 * The result is only available for [LibrarySpecificUnit]s.
 */
final ListResultDescriptor<View> VIEWS_WITH_HTML_TEMPLATES1 =
    new ListResultDescriptor<View>(
        'ANGULAR_VIEWS_WITH_TEMPLATES1', View.EMPTY_LIST);

/**
 * The [View]s with templates in separate HTML files, including what directives
 * they use.
 *
 * The result is only available for [LibrarySpecificUnit]s.
 */
final ListResultDescriptor<View> VIEWS_WITH_HTML_TEMPLATES2 =
    new ListResultDescriptor<View>(
        'ANGULAR_VIEWS_WITH_TEMPLATES2', View.EMPTY_LIST);

/**
 * The asts on the [VIEWS] in a [LibrarySpecificUnit]. Usually you will depend
 * on this and [VIEWS] and use the asts that will therefore be guaranteed to be
 * set on the [View] objects you get.
 */
final ListResultDescriptor<ElementInfo> ANGULAR_ASTS =
    new ListResultDescriptor<ElementInfo>('ANGULAR_ASTS', const []);

/**
 * The errors produced while creating [ANGULAR_ASTS]. Use a Map<Source, ...>
 * because the ast is usually in a different file from the view, and there may
 * be multiple views (and therefore multiple different sources) in a unit.
 *
 * The result is only available for [LibrarySpecificUnit]s.
 */
final ResultDescriptor<Map<Source, List<AnalysisError>>> ANGULAR_ASTS_ERRORS =
    new ResultDescriptor<Map<Source, List<AnalysisError>>>(
        'ANGULAR_ASTS_ERRORS', const <Source, List<AnalysisError>>{});

/**
 * A task that scans contents of a HTML file,
 * producing a set of html.Node as a html.Document.
 * Modification of [ParseHtmlTask] : produces TextInfo nodes for
 * 'eof-found-in-tag-name' parser errors.
 * Builds [ANGULAR_HTML_DOCUMENT],[ANGULAR_HTML_DOCUMENT_ERRORS], and
 * [ANGULAR_HTML_DOCUMENT_EXTRA_NODES].
 */
class AngularParseHtmlTask extends SourceBasedAnalysisTask {
  static const String CONTENT_INPUT_NAME = 'CONTENT_INPUT_NAME';
  static const String MODIFICATION_TIME_INPUT = 'MODIFICATION_TIME_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'AngularParseHtmlTask', createTask, buildInputs, <ResultDescriptor>[
    ANGULAR_HTML_DOCUMENT,
    ANGULAR_HTML_DOCUMENT_ERRORS,
  ]);

  AngularParseHtmlTask(InternalAnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    String content = getRequiredInput(CONTENT_INPUT_NAME);
    int modificationTime = getRequiredInput(MODIFICATION_TIME_INPUT);

    if (modificationTime < 0) {
      String message = 'Content could not be read';
      if (context is InternalAnalysisContext) {
        CacheEntry entry =
            (context as InternalAnalysisContext).getCacheEntry(target);
        CaughtException exception = entry.exception;
        if (exception != null) {
          message = exception.toString();
        }
      }

      outputs[ANGULAR_HTML_DOCUMENT] = new html.Document();
      outputs[ANGULAR_HTML_DOCUMENT_ERRORS] = <AnalysisError>[
        new AnalysisError(
            target.source, 0, 0, ScannerErrorCode.UNABLE_GET_CONTENT, [message])
      ];
    } else {
      final parser = new TemplateParser();
      parser.parse(content, target.source);
      outputs[ANGULAR_HTML_DOCUMENT] = parser.document;
      outputs[ANGULAR_HTML_DOCUMENT_ERRORS] = parser.parseErrors;
    }
  }

  static Map<String, TaskInput> buildInputs(AnalysisTarget source) {
    return <String, TaskInput>{
      CONTENT_INPUT_NAME: CONTENT.of(source),
      MODIFICATION_TIME_INPUT: MODIFICATION_TIME.of(source)
    };
  }

  static AngularParseHtmlTask createTask(
      AnalysisContext context, AnalysisTarget target) {
    return new AngularParseHtmlTask(context, target);
  }
}

/**
 * A task that builds [STANDARD_HTML_COMPONENTS] and
 * [STANDARD_HTML_ELEMENT_EVENTS].
 */
class BuildStandardHtmlComponentsTask extends AnalysisTask {
  static const String UNITS = 'UNITS';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'BuildStandardHtmlComponentsTask',
      createTask,
      buildInputs, <ResultDescriptor>[
    STANDARD_HTML_COMPONENTS,
    STANDARD_HTML_ELEMENT_EVENTS,
    STANDARD_HTML_ELEMENT_ATTRIBUTES
  ]);

  BuildStandardHtmlComponentsTask(
      AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  String get description {
    return '${descriptor.name} for $target';
  }

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    //
    // Prepare inputs.
    //
    List<ast.CompilationUnit> units = getRequiredInput(UNITS);
    //
    // Build components in each unit.
    //
    Map<String, Component> components = <String, Component>{};
    Map<String, OutputElement> events = <String, OutputElement>{};
    Map<String, InputElement> attributes = <String, InputElement>{};
    for (ast.CompilationUnit unit in units) {
      Source source = unit.element.source;
      unit.accept(new BuildStandardHtmlComponentsVisitor(
          components, events, attributes, source));
    }
    //
    // Record outputs.
    //
    outputs[STANDARD_HTML_COMPONENTS] = components.values.toList();
    outputs[STANDARD_HTML_ELEMENT_EVENTS] = events;
    outputs[STANDARD_HTML_ELEMENT_ATTRIBUTES] = attributes;
  }

  /**
   * Return a map from the names of the inputs of this kind of task to the
   * task input descriptors describing those inputs for a task with the
   * given [target].
   */
  static Map<String, TaskInput> buildInputs(AnalysisTarget target) {
    AnalysisContextTarget contextTarget = target;
    SourceFactory sourceFactory = contextTarget.context.sourceFactory;
    Source htmlSource = sourceFactory.forUri(DartSdk.DART_HTML);
    return <String, TaskInput>{
      UNITS: LIBRARY_SPECIFIC_UNITS.of(htmlSource).toListOf(RESOLVED_UNIT5),
    };
  }

  /**
   * Create a task based on the given [target] in the given [context].
   */
  static BuildStandardHtmlComponentsTask createTask(
      AnalysisContext context, AnalysisTarget target) {
    return new BuildStandardHtmlComponentsTask(context, target);
  }
}

/**
 * A task that builds [AbstractDirective]s of a [CompilationUnit].
 */
class BuildUnitDirectivesTask extends SourceBasedAnalysisTask {
  static const String UNIT_INPUT = 'UNIT_INPUT';
  static const String TYPE_PROVIDER_INPUT = 'TYPE_PROVIDER_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'BuildUnitDirectivesTask', createTask, buildInputs, <ResultDescriptor>[
    DIRECTIVES_IN_UNIT,
    DIRECTIVES_ERRORS,
  ]);

  BuildUnitDirectivesTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    TypeProvider typeProvider = getRequiredInput(TYPE_PROVIDER_INPUT);
    //
    // Prepare inputs.
    //
    ast.CompilationUnit unit = getRequiredInput(UNIT_INPUT);
    //
    // Process all classes.
    //
    DirectiveExtractor directiveExtractor =
        new DirectiveExtractor(unit, typeProvider, target.source, context);
    List<AbstractDirective> directives = directiveExtractor.getDirectives();
    //
    // Record outputs.
    //
    outputs[DIRECTIVES_IN_UNIT] = directives;
    outputs[DIRECTIVES_ERRORS] = directiveExtractor.errorListener.errors;
  }

  /**
   * Return a map from the names of the inputs of this kind of task to the
   * task input descriptors describing those inputs for a task with the
   * given [target].
   */
  static Map<String, TaskInput> buildInputs(AnalysisTarget target) {
    return <String, TaskInput>{
      UNIT_INPUT: RESOLVED_UNIT.of(target),
      TYPE_PROVIDER_INPUT: TYPE_PROVIDER.of(AnalysisContextTarget.request)
    };
  }

  /**
   * Create a task based on the given [target] in the given [context].
   */
  static BuildUnitDirectivesTask createTask(
      AnalysisContext context, AnalysisTarget target) {
    return new BuildUnitDirectivesTask(context, target);
  }
}

/**
 * A task that builds [View]s of a [CompilationUnit].
 */
class BuildUnitViewsTask extends SourceBasedAnalysisTask {
  static const String TYPE_PROVIDER_INPUT = 'TYPE_PROVIDER_INPUT';
  static const String UNIT_INPUT = 'UNIT_INPUT';
  static const String DIRECTIVES_INPUT = 'DIRECTIVES_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'BuildUnitViewsTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[VIEWS1, VIEWS_ERRORS1, VIEWS_WITH_HTML_TEMPLATES1]);

  BuildUnitViewsTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  List<AbstractDirective> directivesDefinedInFile;

  @override
  void internalPerform() {
    //
    // Prepare inputs.
    //
    ast.CompilationUnit unit = getRequiredInput(UNIT_INPUT);
    directivesDefinedInFile = getRequiredInput(DIRECTIVES_INPUT);

    //
    // Process all classes.
    //
    ViewExtractor extractor = new ViewExtractor(
        unit, directivesDefinedInFile, context, target.source);
    List<View> views = extractor.getViews();
    List<View> viewsWithTemplates =
        views.where((v) => v.templateUriSource != null).toList();
    //
    // Record outputs.
    //
    outputs[VIEWS1] = views;
    outputs[VIEWS_ERRORS1] = extractor.errorListener.errors;
    outputs[VIEWS_WITH_HTML_TEMPLATES1] = viewsWithTemplates;
  }

  /**
   * Return a map from the names of the inputs of this kind of task to the
   * task input descriptors describing those inputs for a task with the
   * given [target].
   */
  static Map<String, TaskInput> buildInputs(AnalysisTarget target) {
    return <String, TaskInput>{
      DIRECTIVES_INPUT: DIRECTIVES_IN_UNIT.of(target),
      UNIT_INPUT: RESOLVED_UNIT.of(target),
      TYPE_PROVIDER_INPUT: TYPE_PROVIDER.of(AnalysisContextTarget.request),
    };
  }

  /**
   * Create a task based on the given [target] in the given [context].
   */
  static BuildUnitViewsTask createTask(
      AnalysisContext context, AnalysisTarget target) {
    return new BuildUnitViewsTask(context, target);
  }
}

class BuildUnitViewsTask2 extends SourceBasedAnalysisTask {
  static const String VIEWS1_INPUT = 'VIEWS1_INPUT';
  static const String VIEWS_ERRORS1_INPUT = 'VIEWS_ERRORS1_INPUT';
  static const String DIRECTIVES_INPUT = 'DIRECTIVES_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'BuildUnitViewsTask2',
      createTask,
      buildInputs,
      <ResultDescriptor>[VIEWS2, VIEWS_ERRORS2, VIEWS_WITH_HTML_TEMPLATES2]);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  BuildUnitViewsTask2(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  void internalPerform() {
    List<View> views = getRequiredInput(VIEWS1_INPUT);
    List<AbstractDirective> allDirectives = getRequiredInput(DIRECTIVES_INPUT);

    ViewDirectiveLinker linker =
        new ViewDirectiveLinker(views, allDirectives, target.source);
    linker.linkDirectives();
    outputs[VIEWS2] = views;

    outputs[VIEWS_WITH_HTML_TEMPLATES2] =
        views.where((d) => d.templateUriSource != null).toList();

    outputs[VIEWS_ERRORS2] =
        new List<AnalysisError>.from(linker.errorListener.errors)
          ..addAll(getRequiredInput(VIEWS_ERRORS1_INPUT));
  }

  /**
   * Return a map from the names of the inputs of this kind of task to the
   * task input descriptors describing those inputs for a task with the
   * given [target].
   */
  static Map<String, TaskInput> buildInputs(AnalysisTarget target) {
    return <String, TaskInput>{
      DIRECTIVES_INPUT:
          DIRECTIVES_IN_LIBRARY.of((target as LibrarySpecificUnit).library),
      VIEWS1_INPUT: VIEWS1.of(target),
      VIEWS_ERRORS1_INPUT: VIEWS_ERRORS1.of(target),
    };
  }

  /**
   * Create a task based on the given [target] in the given [context].
   */
  static BuildUnitViewsTask2 createTask(
      AnalysisContext context, AnalysisTarget target) {
    return new BuildUnitViewsTask2(context, target);
  }
}

/**
 * A task that computes [DIRECTIVES_IN_LIBRARY] for a library.
 */
class ComputeDirectivesInLibraryTask extends SourceBasedAnalysisTask {
  static const String DIRECTIVES_INPUT = 'DIRECTIVES_INPUT';
  static const String IMPORTED_INPUT = 'IMPORTED_LIBRARIES';
  static const String EXPORTED_INPUT = 'EXPORTED_LIBRARIES';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'ReadyDirectivesInLibraryTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[DIRECTIVES_IN_LIBRARY]);

  ComputeDirectivesInLibraryTask(
      InternalAnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  bool get handlesDependencyCycles => true;

  @override
  void internalPerform() {
    Set<AbstractDirective> directives = new Set<AbstractDirective>();
    // Add directives defined in the units of this library.
    {
      List<List<AbstractDirective>> thisListList =
          getRequiredInput(DIRECTIVES_INPUT);
      for (List<AbstractDirective> unitDirectives in thisListList) {
        directives.addAll(unitDirectives);
      }
    }
    // Ask every imported and exported library.
    List<LibraryElement> importedLibraries = getRequiredInput(IMPORTED_INPUT);
    List<LibraryElement> exportedLibraries = getRequiredInput(EXPORTED_INPUT);
    Set<LibraryElement> visitedLibraries = new Set<LibraryElement>();
    AnalysisCache cache = (context as InternalAnalysisContext).analysisCache;
    void addDirectivesOfLibrary(LibraryElement library) {
      if (visitedLibraries.add(library)) {
        Source librarySource = library.source;
        // Usually DIRECTIVES_IN_LIBRARY is already computed.
        if (cache.getState(librarySource, DIRECTIVES_IN_LIBRARY) ==
            CacheState.VALID) {
          List<AbstractDirective> libraryDirectives =
              cache.getValue(librarySource, DIRECTIVES_IN_LIBRARY);
          directives.addAll(libraryDirectives);
        } else {
          // If there is a dependency cycle, we need to get directives
          // directly from cache for each unit of imported / exported library.
          for (CompilationUnitElement unit in library.units) {
            LibrarySpecificUnit unitTarget =
                new LibrarySpecificUnit(librarySource, unit.source);
            List<AbstractDirective> unitDirectives =
                cache.getValue(unitTarget, DIRECTIVES_IN_UNIT);
            directives.addAll(unitDirectives);
          }
          library.importedLibraries.forEach(addDirectivesOfLibrary);
          library.exportedLibraries.forEach(addDirectivesOfLibrary);
        }
      }
    }

    importedLibraries.forEach(addDirectivesOfLibrary);
    exportedLibraries.forEach(addDirectivesOfLibrary);
    //
    // Record outputs.
    //
    outputs[DIRECTIVES_IN_LIBRARY] = directives.toList();
  }

  static Map<String, TaskInput> buildInputs(AnalysisTarget librarySource) {
    return <String, TaskInput>{
      DIRECTIVES_INPUT:
          LIBRARY_SPECIFIC_UNITS.of(librarySource).toListOf(DIRECTIVES_IN_UNIT),
      IMPORTED_INPUT:
          IMPORTED_LIBRARIES.of(librarySource).toListOf(LIBRARY_ELEMENT),
      EXPORTED_INPUT:
          EXPORTED_LIBRARIES.of(librarySource).toListOf(LIBRARY_ELEMENT),
      // These inputs are used only to express dependency.
      // They can cause dependency cycles, and are not computed.
      // So, we cannot use their values directly.
      'directlyImportedLibrariesReady':
          IMPORTED_LIBRARIES.of(librarySource).toListOf(DIRECTIVES_IN_LIBRARY),
      'directlyExportedLibrariesReady':
          EXPORTED_LIBRARIES.of(librarySource).toListOf(DIRECTIVES_IN_LIBRARY),
    };
  }

  static ComputeDirectivesInLibraryTask createTask(
      AnalysisContext context, AnalysisTarget target) {
    return new ComputeDirectivesInLibraryTask(context, target);
  }
}

/**
 * A task that builds [Template]s of a [LibrarySpecificUnit].
 */
class ResolveDartTemplatesTask extends SourceBasedAnalysisTask {
  static const String TYPE_PROVIDER_INPUT = 'TYPE_PROVIDER_INPUT';
  static const String HTML_COMPONENTS_INPUT = 'HTML_COMPONENTS_INPUT';
  static const String HTML_EVENTS_INPUT = 'HTML_EVENTS_INPUT';
  static const String HTML_ATTRIBUTES_INPUT = 'HTML_ATTRIBUTES_INPUT';
  static const String VIEWS_INPUT = 'VIEWS_INPUT';
  static const String ANGULAR_ASTS_ERRORS_INPUT = 'ANGULAR_ASTS_ERRORS_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'ResolveDartTemplatesTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[DART_TEMPLATES, DART_TEMPLATES_ERRORS]);

  RecordingErrorListener errorListener;

  ResolveDartTemplatesTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    //
    // Prepare inputs.
    //
    TypeProvider typeProvider = getRequiredInput(TYPE_PROVIDER_INPUT);
    List<Component> htmlComponents = getRequiredInput(HTML_COMPONENTS_INPUT);
    Map<String, OutputElement> htmlEvents = getRequiredInput(HTML_EVENTS_INPUT);
    Map<String, InputElement> htmlAttributes =
        getRequiredInput(HTML_ATTRIBUTES_INPUT);
    List<View> views = getRequiredInput(VIEWS_INPUT);
    //
    // Resolve inline view templates.
    //
    List<Template> templates = <Template>[];
    List<AnalysisError> errors = <AnalysisError>[];
    for (View view in views) {
      if (view.template != null && view.templateText != null) {
        errorListener = new RecordingErrorListener();
        new TemplateResolver(typeProvider, htmlComponents, htmlEvents,
                htmlAttributes, errorListener)
            .resolve(view.template);
        if (view.template != null) {
          templates.add(view.template);
        }
        errors.addAll(errorListener.errors.where(
            (e) => !view.template.ignoredErrors.contains(e.errorCode.name)));
      }
    }
    //
    // Record outputs.
    //
    outputs[DART_TEMPLATES] = templates;
    outputs[DART_TEMPLATES_ERRORS] = errors
      ..addAll(inputs[ANGULAR_ASTS_ERRORS_INPUT] ?? []);
  }

  /**
   * Return a map from the names of the inputs of this kind of task to the
   * task input descriptors describing those inputs for a task with the
   * given [target].
   */
  static Map<String, TaskInput> buildInputs(AnalysisTarget target) {
    return <String, TaskInput>{
      TYPE_PROVIDER_INPUT: TYPE_PROVIDER.of(AnalysisContextTarget.request),
      HTML_COMPONENTS_INPUT:
          STANDARD_HTML_COMPONENTS.of(AnalysisContextTarget.request),
      HTML_EVENTS_INPUT:
          STANDARD_HTML_ELEMENT_EVENTS.of(AnalysisContextTarget.request),
      HTML_ATTRIBUTES_INPUT:
          STANDARD_HTML_ELEMENT_ATTRIBUTES.of(AnalysisContextTarget.request),
      VIEWS_INPUT: VIEWS2.of(target),
      // Not only is it important we calculate these errors, its important that
      // the AST conversion which creates those errors is performed
      ANGULAR_ASTS_ERRORS_INPUT: ANGULAR_ASTS_ERRORS
          .of(target)
          .mappedToList((map) => map[(target as LibrarySpecificUnit).source]),
      // only express the dependency that dependent directives have ngContentSelectors
      'childDirectivesAsts': DIRECTIVES_IN_LIBRARY
          .of((target as LibrarySpecificUnit).library)
          .mappedToList((directives) => directives
              .map((d) => new LibrarySpecificUnit(d.source, d.source))
              // TODO we should get LIBRARY_SPECIFIC_UNITS, not make one.
              // But for some reason this fails. Only affects files with parts.
              //.map((d) => d.source)
              .toList())
          //.toListOf(LIBRARY_SPECIFIC_UNITS)
          .toListOf(ANGULAR_ASTS),
    };
  }

  /**
   * Create a task based on the given [target] in the given [context].
   */
  static ResolveDartTemplatesTask createTask(
      AnalysisContext context, AnalysisTarget target) {
    return new ResolveDartTemplatesTask(context, target);
  }
}

class GetAstsForTemplatesInUnitTask extends SourceBasedAnalysisTask {
  static const String DIRECTIVES_IN_UNIT1_INPUT = 'DIRECTIVES_IN_UNIT1_INPUT';
  static const String HTML_DOCUMENTS_INPUT = 'HTML_DOCUMENTS_INPUT';
  static const String HTML_DOCUMENTS_ERRORS_INPUT =
      'HTML_DOCUMENTS_ERRORS_INPUT';
  static const String TYPE_PROVIDER_INPUT = 'TYPE_PROVIDER_INPUT';
  static const String EXTRA_NODES_INPUT = 'EXTRA_NODES_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'GetAstsForTemplatesInUnitTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[ANGULAR_ASTS, ANGULAR_ASTS_ERRORS]);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  GetAstsForTemplatesInUnitTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  void internalPerform() {
    List<AbstractDirective> directives =
        getRequiredInput(DIRECTIVES_IN_UNIT1_INPUT);
    Map<Source, html.Document> documentsMap =
        getRequiredInput(HTML_DOCUMENTS_INPUT);
    Map<Source, List<AnalysisError>> documentsErrorsMap =
        getRequiredInput(HTML_DOCUMENTS_ERRORS_INPUT);
    List<ElementInfo> asts = <ElementInfo>[];
    Map<Source, List<AnalysisError>> errorsByFile =
        <Source, List<AnalysisError>>{};
    directives.forEach((d) {
      if (d is Component) {
        View view = d.view;
        if (view == null || view.templateSource == null) {
          return; // go to next forEach
        }

        RecordingErrorListener errorListener = new RecordingErrorListener();
        ErrorReporter errorReporter =
            new ErrorReporter(errorListener, view.templateSource);

        Source source = view.templateSource;
        if (view.templateUriSource != null) {
          if (documentsMap[source].nodes.length == 0) {
            return;
          }

          documentsErrorsMap[source].forEach(errorListener.onError);
          _processView(new Template(d.view), documentsMap[source],
              errorListener, errorReporter, asts, errorsByFile);
        } else {
          if (view.templateText == null) {
            return;
          }

          final parser = new TemplateParser();
          parser.parse(view.templateText, source, offset: view.templateOffset);
          parser.parseErrors.forEach(errorListener.onError);
          parser.parseErrors.clear();

          _processView(new Template(view), parser.document, errorListener,
              errorReporter, asts, errorsByFile);
        }
      }
    });
    outputs[ANGULAR_ASTS] = asts;
    outputs[ANGULAR_ASTS_ERRORS] = errorsByFile;
  }

  _processView(
      Template template,
      html.Document document,
      RecordingErrorListener errorListener,
      ErrorReporter errorReporter,
      List<ElementInfo> asts,
      Map<Source, List<AnalysisError>> errorsByFile) {
    Source source = template.view.templateSource;
    EmbeddedDartParser parser =
        new EmbeddedDartParser(source, errorListener, errorReporter);
    template.view.template = template;

    template.ast = new HtmlTreeConverter(parser, source, errorListener)
        .convert(firstElement(document));
    setIgnoredErrors(template, document);

    template.ast
        .accept(new NgContentRecorder(template.view.component, errorReporter));

    asts.add(template.ast);

    if (errorsByFile[source] == null) {
      errorsByFile[source] = <AnalysisError>[];
    }
    errorsByFile[source].addAll(errorListener.errors);
  }

  /**
   * Return a map from the names of the inputs of this kind of task to the
   * task input descriptors describing those inputs for a task with the
   * given [target].
   */
  static Map<String, TaskInput> buildInputs(AnalysisTarget target) {
    return <String, TaskInput>{
      DIRECTIVES_IN_UNIT1_INPUT: DIRECTIVES_IN_UNIT.of(target),
      HTML_DOCUMENTS_INPUT: VIEWS_WITH_HTML_TEMPLATES1
          .of(target)
          // mapped to html source of the view
          .mappedToList((views) => views
              .map((v) => v.templateUriSource)
              .where((v) => v != null)
              .toList())
          // to map<source, html document of source>
          .toMapOf(ANGULAR_HTML_DOCUMENT),
      HTML_DOCUMENTS_ERRORS_INPUT: VIEWS_WITH_HTML_TEMPLATES1
          .of(target)
          // mapped to html source of the view
          .mappedToList((views) => views
              .map((v) => v.templateUriSource)
              .where((v) => v != null)
              .toList())
          // to map<source, html document of source>
          .toMapOf(ANGULAR_HTML_DOCUMENT_ERRORS),
    };
  }

  /**
   * Create a task based on the given [target] in the given [context].
   */
  static GetAstsForTemplatesInUnitTask createTask(
      AnalysisContext context, AnalysisTarget target) {
    return new GetAstsForTemplatesInUnitTask(context, target);
  }
}

/**
 * A task that resolves a [HtmlTemplate]s of an HTML [Source].
 */
class ResolveHtmlTemplatesTask extends SourceBasedAnalysisTask {
  static const String TEMPLATES_INPUT = 'TEMPLATES_INPUT';
  static const String ERRORS_INPUT = 'ERRORS_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'ResolveHtmlTemplatesTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[HTML_TEMPLATES, HTML_TEMPLATES_ERRORS]);

  RecordingErrorListener errorListener = new RecordingErrorListener();

  ResolveHtmlTemplatesTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    //
    // Prepare inputs.
    //
    List<HtmlTemplate> templates = getRequiredInput(TEMPLATES_INPUT);
    List<List<AnalysisError>> errorLists = getRequiredInput(ERRORS_INPUT);
    //
    // Record outputs.
    //
    outputs[HTML_TEMPLATES] = templates;
    outputs[HTML_TEMPLATES_ERRORS] = AnalysisError.mergeLists(errorLists);
  }

  /**
   * Return a map from the names of the inputs of this kind of task to the
   * task input descriptors describing those inputs for a task with the
   * given [target].
   */
  static Map<String, TaskInput> buildInputs(AnalysisTarget target) {
    return <String, TaskInput>{
      TEMPLATES_INPUT: TEMPLATE_VIEWS.of(target).toListOf(HTML_TEMPLATE),
      ERRORS_INPUT: TEMPLATE_VIEWS.of(target).toListOf(HTML_TEMPLATE_ERRORS),
    };
  }

  /**
   * Create a task based on the given [target] in the given [context].
   */
  static ResolveHtmlTemplatesTask createTask(
      AnalysisContext context, AnalysisTarget target) {
    return new ResolveHtmlTemplatesTask(context, target);
  }
}

/**
 * A task that resolves an [HtmlTemplate] of a [View].
 */
class ResolveHtmlTemplateTask extends AnalysisTask {
  static const String TYPE_PROVIDER_INPUT = 'TYPE_PROVIDER_INPUT';
  static const String HTML_COMPONENTS_INPUT = 'HTML_COMPONENTS_INPUT';
  static const String HTML_EVENTS_INPUT = 'HTML_EVENTS_INPUT';
  static const String HTML_ATTRIBUTES_INPUT = 'HTML_ATTRIBUTES_INPUT';
  static const String HTML_DOCUMENT_INPUT = 'HTML_DOCUMENT_INPUT';
  static const String HTML_DOCUMENT_ERROR_INPUT = 'HTML_DOCUMENT_ERROR_INPUT';
  static const String HTML_DOCUMENT_EXTRA_NODES_INPUT =
      'HTML_DOCUMENT_EXTRA_NODES_INPUT';
  static const String ANGULAR_ASTS_ERRORS_INPUT = 'ANGULAR_ASTS_ERRORS_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'ResolveHtmlTemplateTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[HTML_TEMPLATE, HTML_TEMPLATE_ERRORS]);

  RecordingErrorListener errorListener = new RecordingErrorListener();

  ResolveHtmlTemplateTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  String get description {
    View view = this.target;
    Source templateSource = view.templateUriSource;
    String templateSourceName =
        templateSource == null ? '<unknown source>' : templateSource.fullName;
    return '${descriptor.name} for template $templateSourceName of $view';
  }

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    //
    // Prepare inputs.
    //
    TypeProvider typeProvider = getRequiredInput(TYPE_PROVIDER_INPUT);
    List<Component> htmlComponents = getRequiredInput(HTML_COMPONENTS_INPUT);
    Map<String, OutputElement> htmlEvents = getRequiredInput(HTML_EVENTS_INPUT);
    Map<String, InputElement> htmlAttributes =
        getRequiredInput(HTML_ATTRIBUTES_INPUT);
    //
    // Resolve.
    //
    View view = target;
    if (view.template != null) {
      new TemplateResolver(typeProvider, htmlComponents, htmlEvents,
              htmlAttributes, errorListener)
          .resolve(view.template);
    }
    //
    // Record outputs.
    //
    List<AnalysisError> errorList = (<AnalysisError>[]
          ..addAll(errorListener.errors)
          ..addAll(inputs[ANGULAR_ASTS_ERRORS_INPUT] ?? []))
        .where((e) => !view.template.ignoredErrors.contains(e.errorCode.name))
        .toList();

    String shorten(String filename) =>
        filename.substring(0, filename.lastIndexOf('.'));

    if (shorten(view.source.fullName) !=
        shorten(view.templateSource.fullName)) {
      errorList = errorList
          .map((e) => new FromFilePrefixedError(view.source, e))
          .toList();
    }

    outputs[HTML_TEMPLATE] = view.template;
    outputs[HTML_TEMPLATE_ERRORS] = errorList;
  }

  /**
   * Return a map from the names of the inputs of this kind of task to the
   * task input descriptors describing those inputs for a task with the
   * given [target].
   */
  static Map<String, TaskInput> buildInputs(AnalysisTarget target) {
    return <String, TaskInput>{
      TYPE_PROVIDER_INPUT: TYPE_PROVIDER.of(AnalysisContextTarget.request),
      HTML_COMPONENTS_INPUT:
          STANDARD_HTML_COMPONENTS.of(AnalysisContextTarget.request),
      HTML_EVENTS_INPUT:
          STANDARD_HTML_ELEMENT_EVENTS.of(AnalysisContextTarget.request),
      HTML_ATTRIBUTES_INPUT:
          STANDARD_HTML_ELEMENT_ATTRIBUTES.of(AnalysisContextTarget.request),
      // Not only is it important we calculate these errors, its important that
      // the AST conversion which creates those errors is performed
      ANGULAR_ASTS_ERRORS_INPUT: LIBRARY_SPECIFIC_UNITS
          .of((target as View).component.source)
          .toListOf(ANGULAR_ASTS_ERRORS)
          .mappedToList((maps) {
        Map<Source, List<AnalysisError>> deduped =
            <Source, List<AnalysisError>>{};
        maps.forEach(deduped.addAll);
        return deduped[(target as View).templateSource];
      }),
      // only express the dependency that dependent directives have ngContentSelectors
      'childDirectivesAsts': DIRECTIVES_IN_LIBRARY
          .of((target as View).component.source)
          .mappedToList((directives) => directives
              .map((d) => new LibrarySpecificUnit(d.source, d.source))
              // TODO we should get LIBRARY_SPECIFIC_UNITS, not make one.
              // But for some reason this fails. Only affects files with parts.
              //.map((d) => d.source)
              .toList())
          //.toListOf(LIBRARY_SPECIFIC_UNITS)
          .toListOf(ANGULAR_ASTS),
    };
  }

  /**
   * Create a task based on the given [target] in the given [context].
   */
  static ResolveHtmlTemplateTask createTask(
      AnalysisContext context, AnalysisTarget target) {
    return new ResolveHtmlTemplateTask(context, target);
  }
}

class OffsettingConstantEvaluator extends utils.ConstantEvaluator {
  bool offsetsAreValid = true;
  Object value;
  ast.AstNode lastUnoffsettableNode;

  @override
  Object visitAdjacentStrings(ast.AdjacentStrings node) {
    StringBuffer buffer = new StringBuffer();
    int lastEndingOffset = null;
    for (ast.StringLiteral string in node.strings) {
      Object value = string.accept(this);
      if (identical(value, utils.ConstantEvaluator.NOT_A_CONSTANT)) {
        return value;
      }
      // preserve offsets across the split by padding
      if (lastEndingOffset != null) {
        buffer.write(' ' * (string.offset - lastEndingOffset));
      }
      lastEndingOffset = string.offset + string.length;
      buffer.write(value);
    }
    return buffer.toString();
  }

  @override
  Object visitBinaryExpression(ast.BinaryExpression node) {
    if (node.operator.type == TokenType.PLUS) {
      Object leftOperand = node.leftOperand.accept(this);
      if (identical(leftOperand, utils.ConstantEvaluator.NOT_A_CONSTANT)) {
        return leftOperand;
      }
      Object rightOperand = node.rightOperand.accept(this);
      if (identical(rightOperand, utils.ConstantEvaluator.NOT_A_CONSTANT)) {
        return rightOperand;
      }
      // numeric or {@code null}
      if (leftOperand is String && rightOperand is String) {
        int gap = node.rightOperand.offset -
            node.leftOperand.offset -
            node.leftOperand.length;
        return leftOperand + (' ' * gap) + rightOperand;
      }
    }

    return super.visitBinaryExpression(node);
  }

  @override
  Object visitStringInterpolation(ast.StringInterpolation node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    return super.visitStringInterpolation(node);
  }

  @override
  Object visitMethodInvocation(ast.MethodInvocation node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    return super.visitMethodInvocation(node);
  }

  @override
  Object visitParenthesizedExpression(ast.ParenthesizedExpression node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    int preGap = node.expression.offset - node.offset;
    int postGap = node.offset +
        node.length -
        node.expression.offset -
        node.expression.length;
    Object value = super.visitParenthesizedExpression(node);
    if (value is String) {
      return ' ' * preGap + value + ' ' * postGap;
    }

    return value;
  }

  @override
  Object visitSimpleStringLiteral(ast.SimpleStringLiteral node) {
    int gap = node.contentsOffset - node.offset;
    lastUnoffsettableNode = node;
    return ' ' * gap + node.value + ' ';
  }

  @override
  Object visitPrefixedIdentifier(ast.PrefixedIdentifier node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    return super.visitPrefixedIdentifier(node);
  }

  @override
  Object visitPropertyAccess(ast.PropertyAccess node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    return super.visitPropertyAccess(node);
  }

  @override
  Object visitSimpleIdentifier(ast.SimpleIdentifier node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    return super.visitSimpleIdentifier(node);
  }
}

/**
 * Helper for processing Angular annotations.
 */
class AnnotationProcessorMixin {
  RecordingErrorListener errorListener = new RecordingErrorListener();
  ErrorReporter errorReporter;

  /**
   * The evaluator of constant values, such as annotation arguments.
   */
  final utils.ConstantEvaluator _constantEvaluator =
      new utils.ConstantEvaluator();

  /**
   * Initialize the processor working in the given [target].
   */
  void initAnnotationProcessor(Source source) {
    assert(errorReporter == null);
    errorReporter = new ErrorReporter(errorListener, source);
  }

  /**
   * Returns the [String] value of the given [expression].
   * If [expression] does not have a [String] value, reports an error
   * and returns `null`.
   */
  String getExpressionString(ast.Expression expression) {
    if (expression != null) {
      Object value = expression.accept(_constantEvaluator);
      if (value is String) {
        return value;
      }
      errorReporter.reportErrorForNode(
          AngularWarningCode.STRING_VALUE_EXPECTED, expression);
    }
    return null;
  }

  /**
   * Returns the [String] value of the given [expression].
   * If [expression] does not have a [String] value, reports an error
   * and returns `null`.
   */
  OffsettingConstantEvaluator calculateStringWithOffsets(
      ast.Expression expression) {
    if (expression != null) {
      OffsettingConstantEvaluator evaluator = new OffsettingConstantEvaluator();
      evaluator.value = expression.accept(evaluator);

      if (evaluator.value is String) {
        if (!evaluator.offsetsAreValid) {
          errorReporter.reportErrorForNode(
              AngularWarningCode.OFFSETS_CANNOT_BE_CREATED,
              evaluator.lastUnoffsettableNode);
        }
        return evaluator;
      }
      errorReporter.reportErrorForNode(
          AngularWarningCode.STRING_VALUE_EXPECTED, expression);
    }
    return null;
  }

  /**
   * Returns the value of the argument with the given [name].
   * Returns `null` if not found.
   */
  ast.Expression getNamedArgument(ast.Annotation node, String name) {
    if (node.arguments != null) {
      List<ast.Expression> arguments = node.arguments.arguments;
      for (ast.Expression argument in arguments) {
        if (argument is ast.NamedExpression &&
            argument.name != null &&
            argument.name.label != null &&
            argument.name.label.name == name) {
          return argument.expression;
        }
      }
    }
    return null;
  }

  /**
   * Returns `true` is the given [node] is resolved to a creation of an Angular
   * annotation class with the given [name].
   */
  bool isAngularAnnotation(ast.Annotation node, String name) {
    if (node.element is ConstructorElement) {
      ClassElement clazz = node.element.enclosingElement;
      return clazz.library.source.uri.path
              .endsWith('angular2/src/core/metadata.dart') &&
          clazz.name == name;
    }
    return false;
  }
}

List<AnalysisError> filterParserErrors(
    AngularHtmlParser parser, String content, Source source) {
  List<AnalysisError> errors = <AnalysisError>[];
  List<html.ParseError> parseErrors = parser.errors;

  for (html.ParseError parseError in parseErrors) {
    //Append error codes that are useful to this analyzer
    if (parseError.errorCode == 'eof-in-tag-name') {
      SourceSpan span = parseError.span;
      errors.add(new AnalysisError(
          source,
          span.start.offset,
          span.length,
          HtmlErrorCode.PARSE_ERROR,
          [parseError.errorCode, content.substring(span.start.offset)]));
    }
  }
  return errors;
}

typedef void CaptureAspectFn<T>(
    Map<String, T> aspectMap, PropertyAccessorElement accessor);

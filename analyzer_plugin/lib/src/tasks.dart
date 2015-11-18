library angular2.src.analysis.analyzer_plugin.src.tasks;

import 'package:analyzer/src/context/cache.dart';
import 'package:analyzer/src/generated/ast.dart' as ast;
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart' hide AnalysisCache;
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/resolver.dart' show TypeProvider;
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/task/dart.dart';
import 'package:analyzer/src/task/general.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/html.dart';
import 'package:analyzer/task/model.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/resolver.dart';
import 'package:angular2_analyzer_plugin/src/selector.dart';
import 'package:angular2_analyzer_plugin/src/strings.dart';
import 'package:angular2_analyzer_plugin/tasks.dart';
import 'package:html/dom.dart' as html;

/// The [Template]s of a [LibrarySpecificUnit].
/// This result is produced for templates specified directly in Dart files.
final ListResultDescriptor<Template> DART_TEMPLATES =
    new ListResultDescriptor<Template>(
        'ANGULAR_DART_TEMPLATES', Template.EMPTY_LIST);

/// The errors produced while building [DART_TEMPLATES].
/// This result is produced for templates specified directly in Dart files.
final ListResultDescriptor<AnalysisError> DART_TEMPLATES_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_DART_TEMPLATES_ERRORS', AnalysisError.NO_ERRORS);

/// The errors produced while building [DIRECTIVES_IN_UNIT].
///
/// The list will be empty if there were no errors, but will not be `null`.
///
/// The result is only available for [LibrarySpecificUnit]s.
final ListResultDescriptor<AnalysisError> DIRECTIVES_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_DIRECTIVES_ERRORS', AnalysisError.NO_ERRORS);

/// The Angular [AbstractDirective]s available for a library.
///
/// The list will be empty if there were no directives, but will not be `null`.
///
/// The result is only available for [Source]s representing a library.
final ListResultDescriptor<AbstractDirective> DIRECTIVES_IN_LIBRARY =
    new ListResultDescriptor<AbstractDirective>(
        'ANGULAR_DIRECTIVES_IN_LIBRARY', AbstractDirective.EMPTY_LIST);

/// The Angular [AbstractDirective]s of a [LibrarySpecificUnit].
///
/// The list will be empty if there were no directives, but will not be `null`.
///
/// The result is only available for [LibrarySpecificUnit]s.
final ListResultDescriptor<AbstractDirective> DIRECTIVES_IN_UNIT =
    new ListResultDescriptor<AbstractDirective>(
        'ANGULAR_DIRECTIVES_IN_UNIT', AbstractDirective.EMPTY_LIST);

/// The [HtmlTemplate] of a HTML [Source].
///
/// This result is produced for [View]s.
final ResultDescriptor<HtmlTemplate> HTML_TEMPLATE =
    new ResultDescriptor('ANGULAR_HTML_TEMPLATE', null);

/// The errors produced while building a [HTML_TEMPLATE].
///
/// This result is produced for [View]s.
final ListResultDescriptor<AnalysisError> HTML_TEMPLATE_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_HTML_TEMPLATE_ERRORS', AnalysisError.NO_ERRORS);

/// The [HtmlTemplate]s of a HTML [Source].
/// Each [HtmlTemplate] corresponds to a single [View] that uses this template.
///
/// This result is produced for HTML [Source]s.
final ListResultDescriptor<HtmlTemplate> HTML_TEMPLATES =
    new ListResultDescriptor('ANGULAR_HTML_TEMPLATES', HtmlTemplate.EMPTY_LIST);

/// The errors produced while building a [HTML_TEMPLATE]s.
///
/// This result is produced for HTML [Source]s.
final ListResultDescriptor<AnalysisError> HTML_TEMPLATES_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_HTML_TEMPLATES_ERRORS', AnalysisError.NO_ERRORS);

/// The [View]s with this HTML template file.
///
/// The result is only available for HTML [Source]s.
final ListResultDescriptor<View> TEMPLATE_VIEWS =
    new ListResultDescriptor<View>('ANGULAR_TEMPLATE_VIEWS', View.EMPTY_LIST);

/// The [View]s of a [LibrarySpecificUnit].
final ListResultDescriptor<View> VIEWS =
    new ListResultDescriptor<View>('ANGULAR_VIEWS', View.EMPTY_LIST);

/// The errors produced while building [VIEWS].
///
/// The list will be empty if there were no errors, but will not be `null`.
///
/// The result is only available for [LibrarySpecificUnit]s.
final ListResultDescriptor<AnalysisError> VIEWS_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_VIEWS_ERRORS', AnalysisError.NO_ERRORS);

/// The [View]s with templates in separate HTML files.
///
/// The result is only available for [LibrarySpecificUnit]s.
final ListResultDescriptor<View> VIEWS_WITH_HTML_TEMPLATES =
    new ListResultDescriptor<View>(
        'ANGULAR_VIEWS_WITH_TEMPLATES', View.EMPTY_LIST);

/// A task that builds [AbstractDirective]s of a [CompilationUnit].
class BuildUnitDirectivesTask extends SourceBasedAnalysisTask
    with _AnnotationProcessorMixin {
  static const String UNIT_INPUT = 'UNIT_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'BuildUnitDirectivesTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[DIRECTIVES_IN_UNIT, DIRECTIVES_ERRORS]);

  BuildUnitDirectivesTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    initAnnotationProcessor(target);
    //
    // Prepare inputs.
    //
    ast.CompilationUnit unit = getRequiredInput(UNIT_INPUT);
    //
    // Process all classes.
    //
    List<AbstractDirective> directives = <AbstractDirective>[];
    for (ast.CompilationUnitMember unitMember in unit.declarations) {
      if (unitMember is ast.ClassDeclaration) {
        ClassElement classElement = unitMember.element;
        for (ast.Annotation annotationNode in unitMember.metadata) {
          AbstractDirective directive =
              _createDirective(classElement, annotationNode);
          if (directive != null) {
            directives.add(directive);
          }
        }
      }
    }
    //
    // Record outputs.
    //
    outputs[DIRECTIVES_IN_UNIT] = directives;
    outputs[DIRECTIVES_ERRORS] = errorListener.errors;
  }

  /// Returns an Angular [AbstractDirective] for to the given [node].
  /// Returns `null` if not an Angular annotation.
  AbstractDirective _createDirective(
      ClassElement classElement, ast.Annotation node) {
    // TODO(scheglov) add support for all the arguments
    if (_isAngularAnnotation(node, 'Component')) {
      Selector selector = _parseSelector(node);
      if (selector == null) {
        return null;
      }
      AngularElement exportAs = _parseExportAs(node);
      List<InputElement> inputs = _parseInputs(classElement, node);
      return new Component(classElement,
          exportAs: exportAs, inputs: inputs, selector: selector);
    }
    if (_isAngularAnnotation(node, 'Directive')) {
      Selector selector = _parseSelector(node);
      if (selector == null) {
        return null;
      }
      AngularElement exportAs = _parseExportAs(node);
      List<InputElement> inputs = _parseInputs(classElement, node);
      return new Directive(classElement,
          exportAs: exportAs, inputs: inputs, selector: selector);
    }
    return null;
  }

  /**
   * Return the first named argument with one of the given names, or
   * `null` if this argument is not [ast.ListLiteral] or no such arguments.
   */
  ast.ListLiteral _getListLiteralNamedArgument(
      ast.Annotation node, List<String> names) {
    for (var name in names) {
      ast.Expression expression = _getNamedArgument(node, name);
      if (expression != null) {
        return expression is ast.ListLiteral ? expression : null;
      }
    }
    return null;
  }

  AngularElement _parseExportAs(ast.Annotation node) {
    // Find the "exportAs" argument.
    ast.Expression expression = _getNamedArgument(node, 'exportAs');
    if (expression == null) {
      return null;
    }
    // Extract its content.
    String name;
    int offset;
    if (expression is ast.SimpleStringLiteral) {
      name = expression.value;
      offset = expression.contentsOffset;
    } else {
      errorReporter.reportErrorForNode(
          AngularWarningCode.STRING_VALUE_EXPECTED, expression);
      return null;
    }
    // Create a new element.
    return new AngularElementImpl(name, offset, name.length, target.source);
  }

  InputElement _parseInput(
      ClassElement classElement, ast.Expression expression) {
    if (expression is ast.SimpleStringLiteral) {
      int offset = expression.contentsOffset;
      String value = expression.value;
      // TODO(scheglov) support for pipes
      int colonIndex = value.indexOf(':');
      if (colonIndex == -1) {
        String setterName = value;
        String inputName = getCamelWords(setterName)
            .map((word) => word.toLowerCase())
            .join('-');
        PropertyAccessorElement setter =
            _resolveSetter(classElement, expression, setterName);
        SourceRange setterRange = new SourceRange(offset, setterName.length);
        return new InputElement(inputName, offset, setterName.length,
            target.source, setter, setterRange);
      } else {
        // Resolve the setter.
        String setterName = value.substring(0, colonIndex).trimRight();
        PropertyAccessorElement setter =
            _resolveSetter(classElement, expression, setterName);
        // Find the input name.
        int inputOffset = colonIndex;
        while (true) {
          inputOffset++;
          if (inputOffset >= value.length) {
            // TODO(scheglov) report a warning
            return null;
          }
          if (value.substring(inputOffset, inputOffset + 1) != ' ') {
            break;
          }
        }
        String inputName = value.substring(inputOffset);
        // TODO(scheglov) test that a valid input name
        // Create the input.
        return new InputElement(
            inputName,
            offset + inputOffset,
            inputName.length,
            target.source,
            setter,
            new SourceRange(offset, setterName.length));
      }
    } else {
      // TODO(scheglov) report a warning
      return null;
    }
  }

  List<InputElement> _parseInputs(
      ClassElement classElement, ast.Annotation node) {
    ast.ListLiteral descList = _getListLiteralNamedArgument(
        node, const <String>['inputs', 'properties']);
    if (descList == null) {
      return InputElement.EMPTY_LIST;
    }
    // Create an input for each element.
    List<InputElement> inputs = <InputElement>[];
    for (ast.Expression element in descList.elements) {
      InputElement input = _parseInput(classElement, element);
      if (input != null) {
        inputs.add(input);
      }
    }
    return inputs;
  }

  Selector _parseSelector(ast.Annotation node) {
    // Find the "selector" argument.
    ast.Expression expression = _getNamedArgument(node, 'selector');
    if (expression == null) {
      errorReporter.reportErrorForNode(
          AngularWarningCode.ARGUMENT_SELECTOR_MISSING, node);
      return null;
    }
    // Compute the selector text.
    String selectorStr;
    int selectorOffset;
    if (expression is ast.SimpleStringLiteral) {
      selectorStr = expression.value;
      selectorOffset = expression.contentsOffset;
    } else {
      errorReporter.reportErrorForNode(
          AngularWarningCode.STRING_VALUE_EXPECTED, expression);
      return null;
    }
    // Parse the selector text.
    Selector selector =
        Selector.parse(target.source, selectorOffset, selectorStr);
    if (selector == null) {
      errorReporter.reportErrorForNode(
          AngularWarningCode.CANNOT_PARSE_SELECTOR, expression);
      return null;
    }
    return selector;
  }

  /// Resolve the input setter with the given [name] in [classElement].
  /// If undefined, report a warning and return `null`.
  PropertyAccessorElement _resolveSetter(
      ClassElement classElement, ast.SimpleStringLiteral literal, String name) {
    PropertyAccessorElement setter =
        classElement.lookUpSetter(name, classElement.library);
    if (setter == null) {
      errorReporter.reportErrorForNode(StaticTypeWarningCode.UNDEFINED_SETTER,
          literal, [name, classElement.displayName]);
    }
    return setter;
  }

  /// Return a map from the names of the inputs of this kind of task to the
  /// task input descriptors describing those inputs for a task with the
  /// given [target].
  static Map<String, TaskInput> buildInputs(LibrarySpecificUnit target) {
    return <String, TaskInput>{UNIT_INPUT: RESOLVED_UNIT.of(target)};
  }

  /// Create a task based on the given [target] in the given [context].
  static BuildUnitDirectivesTask createTask(
      AnalysisContext context, LibrarySpecificUnit target) {
    return new BuildUnitDirectivesTask(context, target);
  }
}

/// A task that builds [View]s of a [CompilationUnit].
class BuildUnitViewsTask extends SourceBasedAnalysisTask
    with _AnnotationProcessorMixin {
  static const String DIRECTIVES_INPUT = 'DIRECTIVES_INPUT';
  static const String UNIT_INPUT = 'UNIT_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'BuildUnitViewsTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[VIEWS, VIEWS_ERRORS, VIEWS_WITH_HTML_TEMPLATES]);

  List<AbstractDirective> _allDirectives;

  BuildUnitViewsTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    initAnnotationProcessor(target);
    //
    // Prepare inputs.
    //
    ast.CompilationUnit unit = getRequiredInput(UNIT_INPUT);
    _allDirectives = getRequiredInput(DIRECTIVES_INPUT);
    //
    // Process all classes.
    //
    List<View> views = <View>[];
    List<View> viewsWithTemplates = <View>[];
    for (ast.CompilationUnitMember unitMember in unit.declarations) {
      if (unitMember is ast.ClassDeclaration) {
        ClassElement classElement = unitMember.element;
        for (ast.Annotation annotation in unitMember.metadata) {
          if (_isAngularAnnotation(annotation, 'View')) {
            View view = _createView(classElement, annotation);
            if (view != null) {
              views.add(view);
              if (view.templateUriSource != null) {
                viewsWithTemplates.add(view);
              }
            }
          }
        }
      }
    }
    //
    // Record outputs.
    //
    outputs[VIEWS] = views;
    outputs[VIEWS_ERRORS] = errorListener.errors;
    outputs[VIEWS_WITH_HTML_TEMPLATES] = viewsWithTemplates;
  }

  /// Attempt to find and add the [AbstractDirective] that corresponds to
  /// the [classElement]. Return `true` if success.
  bool _addDirective(
      List<AbstractDirective> directives, ClassElement classElement) {
    for (AbstractDirective directive in _allDirectives) {
      if (directive.classElement == classElement) {
        directives.add(directive);
        return true;
      }
    }
    return false;
  }

  /// Attempt to find and add the [AbstractDirective] that corresponds to
  /// the [classElement]. Return an error if the directive not found.
  void _addDirectiveOrReportError(List<AbstractDirective> directives,
      ast.Expression expression, ClassElement classElement) {
    bool success = _addDirective(directives, classElement);
    if (!success) {
      errorReporter.reportErrorForNode(
          AngularWarningCode.DIRECTIVE_TYPE_LITERAL_EXPECTED, expression);
    }
  }

  /**
   * Walk the given [value] and add directives into [directives].
   * Return `true` if success, or `false` the [value] has items that don't
   * correspond to a directive.
   */
  bool _addDirectivesForDartObject(
      List<AbstractDirective> directives, DartObject value) {
    List<DartObject> listValue = value.toListValue();
    if (listValue != null) {
      for (DartObject listItem in listValue) {
        Object typeValue = listItem.toTypeValue();
        if (typeValue is InterfaceType) {
          bool success = _addDirective(directives, typeValue.element);
          if (!success) {
            return false;
          }
        }
      }
      return true;
    }
    return false;
  }

  /// Create a new [View] for the given [annotation], may return `null`
  /// if [annotation] or [classElement] don't provide enough information.
  View _createView(ClassElement classElement, ast.Annotation annotation) {
    // Template in a separate HTML file.
    Source templateUriSource = null;
    SourceRange templateUrlRange = null;
    {
      ast.Expression templateUrlExpression =
          _getNamedArgument(annotation, 'templateUrl');
      String templateUrl = _getExpressionString(templateUrlExpression);
      if (templateUrl != null) {
        SourceFactory sourceFactory = context.sourceFactory;
        templateUriSource =
            sourceFactory.resolveUri(target.source, templateUrl);
        // TODO: report a warning if it cannot be resolved.
        templateUrlRange = new SourceRange(
            templateUrlExpression.offset, templateUrlExpression.length);
      }
    }
    // Try to find inline "template".
    String templateText;
    int templateOffset = 0;
    {
      ast.Expression expression = _getNamedArgument(annotation, 'template');
      if (expression != null) {
        if (expression is ast.SimpleStringLiteral) {
          templateText = expression.value;
          templateOffset = expression.contentsOffset;
        } else {
          errorReporter.reportErrorForNode(
              AngularWarningCode.STRING_VALUE_EXPECTED, expression);
        }
      }
    }
    // Find the corresponding Component.
    Component component = _findComponentAnnotationOrReportError(classElement);
    if (component == null) {
      return null;
    }
    // Prepare directives.
    List<AbstractDirective> directives = <AbstractDirective>[];
    {
      ast.Expression listExpression =
          _getNamedArgument(annotation, 'directives');
      if (listExpression is ast.ListLiteral) {
        for (ast.Expression item in listExpression.elements) {
          if (item is ast.Identifier) {
            Element element = item.staticElement;
            // TypeLiteral
            if (element is ClassElement) {
              _addDirectiveOrReportError(directives, item, element);
              continue;
            }
            // LIST_OF_DIRECTIVES
            if (element is PropertyAccessorElement &&
                element.variable.constantValue != null) {
              DartObject value = element.variable.constantValue;
              bool success = _addDirectivesForDartObject(directives, value);
              if (!success) {
                errorReporter.reportErrorForNode(
                    AngularWarningCode.TYPE_LITERAL_EXPECTED, item);
                return null;
              }
              continue;
            }
          }
          // unknown
          errorReporter.reportErrorForNode(
              AngularWarningCode.TYPE_LITERAL_EXPECTED, item);
        }
      }
    }
    // Create View.
    return new View(classElement, component, directives,
        templateText: templateText,
        templateOffset: templateOffset,
        templateUriSource: templateUriSource,
        templateUrlRange: templateUrlRange);
  }

  Component _findComponentAnnotationOrReportError(ClassElement classElement) {
    for (AbstractDirective directive in _allDirectives) {
      if (directive is Component && directive.classElement == classElement) {
        return directive;
      }
    }
    errorReporter.reportErrorForElement(
        AngularWarningCode.COMPONENT_ANNOTATION_MISSING, classElement, []);
    return null;
  }

  /// Return a map from the names of the inputs of this kind of task to the
  /// task input descriptors describing those inputs for a task with the
  /// given [target].
  static Map<String, TaskInput> buildInputs(LibrarySpecificUnit target) {
    return <String, TaskInput>{
      DIRECTIVES_INPUT: DIRECTIVES_IN_LIBRARY.of(target.library),
      UNIT_INPUT: RESOLVED_UNIT.of(target)
    };
  }

  /// Create a task based on the given [target] in the given [context].
  static BuildUnitViewsTask createTask(
      AnalysisContext context, LibrarySpecificUnit target) {
    return new BuildUnitViewsTask(context, target);
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

  static Map<String, TaskInput> buildInputs(Source librarySource) {
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

/// A task that builds [Template]s of a [LibrarySpecificUnit].
class ResolveDartTemplatesTask extends SourceBasedAnalysisTask {
  static const String TYPE_PROVIDER_INPUT = 'TYPE_PROVIDER_INPUT';
  static const String VIEWS_INPUT = 'VIEWS_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'ResolveDartTemplatesTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[DART_TEMPLATES, DART_TEMPLATES_ERRORS]);

  RecordingErrorListener errorListener = new RecordingErrorListener();

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
    List<View> views = getRequiredInput(VIEWS_INPUT);
    //
    // Resolve inline view templates.
    //
    List<Template> templates = <Template>[];
    for (View view in views) {
      if (view.templateText != null) {
        Template template = new DartTemplateResolver(
            typeProvider, errorListener, view).resolve();
        if (template != null) {
          templates.add(template);
        }
      }
    }
    //
    // Record outputs.
    //
    outputs[DART_TEMPLATES] = templates;
    outputs[DART_TEMPLATES_ERRORS] = errorListener.errors;
  }

  /// Return a map from the names of the inputs of this kind of task to the
  /// task input descriptors describing those inputs for a task with the
  /// given [target].
  static Map<String, TaskInput> buildInputs(LibrarySpecificUnit target) {
    return <String, TaskInput>{
      TYPE_PROVIDER_INPUT: TYPE_PROVIDER.of(AnalysisContextTarget.request),
      VIEWS_INPUT: VIEWS.of(target),
    };
  }

  /// Create a task based on the given [target] in the given [context].
  static ResolveDartTemplatesTask createTask(
      AnalysisContext context, LibrarySpecificUnit target) {
    return new ResolveDartTemplatesTask(context, target);
  }
}

/// A task that resolves a [HtmlTemplate]s of an HTML [Source].
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

  /// Return a map from the names of the inputs of this kind of task to the
  /// task input descriptors describing those inputs for a task with the
  /// given [target].
  static Map<String, TaskInput> buildInputs(Source target) {
    return <String, TaskInput>{
      TEMPLATES_INPUT: TEMPLATE_VIEWS.of(target).toListOf(HTML_TEMPLATE),
      ERRORS_INPUT: TEMPLATE_VIEWS.of(target).toListOf(HTML_TEMPLATE_ERRORS),
    };
  }

  /// Create a task based on the given [target] in the given [context].
  static ResolveHtmlTemplatesTask createTask(
      AnalysisContext context, AnalysisTarget target) {
    return new ResolveHtmlTemplatesTask(context, target);
  }
}

/// A task that resolves an [HtmlTemplate] of a [View].
class ResolveHtmlTemplateTask extends SourceBasedAnalysisTask {
  static const String TYPE_PROVIDER_INPUT = 'TYPE_PROVIDER_INPUT';
  static const String HTML_DOCUMENT_INPUT = 'HTML_DOCUMENT_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'ResolveHtmlTemplateTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[HTML_TEMPLATE, HTML_TEMPLATE_ERRORS]);

  RecordingErrorListener errorListener = new RecordingErrorListener();

  ResolveHtmlTemplateTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  @override
  void internalPerform() {
    //
    // Prepare inputs.
    //
    TypeProvider typeProvider = getRequiredInput(TYPE_PROVIDER_INPUT);
    html.Document document = getRequiredInput(HTML_DOCUMENT_INPUT);
    //
    // Resolve.
    //
    View view = target;
    Template template = new HtmlTemplateResolver(
        typeProvider, errorListener, view, document).resolve();
    //
    // Record outputs.
    //
    outputs[HTML_TEMPLATE] = template;
    outputs[HTML_TEMPLATE_ERRORS] = errorListener.errors;
  }

  /// Return a map from the names of the inputs of this kind of task to the
  /// task input descriptors describing those inputs for a task with the
  /// given [target].
  static Map<String, TaskInput> buildInputs(View target) {
    return <String, TaskInput>{
      TYPE_PROVIDER_INPUT: TYPE_PROVIDER.of(AnalysisContextTarget.request),
      HTML_DOCUMENT_INPUT: HTML_DOCUMENT.of(target.templateUriSource),
    };
  }

  /// Create a task based on the given [target] in the given [context].
  static ResolveHtmlTemplateTask createTask(
      AnalysisContext context, View target) {
    return new ResolveHtmlTemplateTask(context, target);
  }
}

/// Helper for processing Angular annotations.
class _AnnotationProcessorMixin {
  RecordingErrorListener errorListener = new RecordingErrorListener();
  ErrorReporter errorReporter;

  /// The evaluator of constant values, such as annotation arguments.
  final ast.ConstantEvaluator _constantEvaluator = new ast.ConstantEvaluator();

  /// Initialize the processor working in the given [target].
  void initAnnotationProcessor(AnalysisTarget target) {
    assert(errorReporter == null);
    errorReporter = new ErrorReporter(errorListener, target.source);
  }

  /// Returns the [String] value of the given [expression].
  /// If [expression] does not have a [String] value, reports an error
  /// and returns `null`.
  String _getExpressionString(ast.Expression expression) {
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

  /// Returns the value of the argument with the given [name].
  /// Returns `null` if not found.
  ast.Expression _getNamedArgument(ast.Annotation node, String name) {
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

  /// Returns `true` is the given [node] is resolved to a creation of an Angular
  /// annotation class with the given [name].
  bool _isAngularAnnotation(ast.Annotation node, String name) {
    if (node.element is ConstructorElement) {
      ClassElement clazz = node.element.enclosingElement;
      return clazz.library.name == 'angular2.src.core.metadata' &&
          clazz.name == name;
    }
    return false;
  }
}

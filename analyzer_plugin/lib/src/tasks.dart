library angular2.src.analysis.analyzer_plugin.src.tasks;

import 'package:analyzer/src/context/cache.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/src/dart/ast/utilities.dart' as utils;
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/resolver.dart' show TypeProvider;
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/task/dart.dart';
import 'package:analyzer/src/task/general.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/html.dart';
import 'package:analyzer/task/model.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/resolver.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:html/dom.dart' as html;
import 'package:tuple/tuple.dart';

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
 * The [View]s with this HTML template file.
 *
 * The result is only available for HTML [Source]s.
 */
final ListResultDescriptor<View> TEMPLATE_VIEWS =
    new ListResultDescriptor<View>('ANGULAR_TEMPLATE_VIEWS', View.EMPTY_LIST);

/**
 * The [View]s of a [LibrarySpecificUnit].
 */
final ListResultDescriptor<View> VIEWS =
    new ListResultDescriptor<View>('ANGULAR_VIEWS', View.EMPTY_LIST);

/**
 * The errors produced while building [VIEWS].
 *
 * The list will be empty if there were no errors, but will not be `null`.
 *
 * The result is only available for [LibrarySpecificUnit]s.
 */
final ListResultDescriptor<AnalysisError> VIEWS_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_VIEWS_ERRORS', AnalysisError.NO_ERRORS);

/**
 * The [View]s with templates in separate HTML files.
 *
 * The result is only available for [LibrarySpecificUnit]s.
 */
final ListResultDescriptor<View> VIEWS_WITH_HTML_TEMPLATES =
    new ListResultDescriptor<View>(
        'ANGULAR_VIEWS_WITH_TEMPLATES', View.EMPTY_LIST);

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
    STANDARD_HTML_ELEMENT_EVENTS
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
    for (ast.CompilationUnit unit in units) {
      Source source = unit.element.source;
      unit.accept(
          new _BuildStandardHtmlComponentsVisitor(components, events, source));
    }
    //
    // Record outputs.
    //
    outputs[STANDARD_HTML_COMPONENTS] = components.values.toList();
    outputs[STANDARD_HTML_ELEMENT_EVENTS] = events;
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
class BuildUnitDirectivesTask extends SourceBasedAnalysisTask
    with _AnnotationProcessorMixin {
  static const String UNIT_INPUT = 'UNIT_INPUT';
  static const String TYPE_PROVIDER_INPUT = 'TYPE_PROVIDER_INPUT';

  static final TaskDescriptor DESCRIPTOR = new TaskDescriptor(
      'BuildUnitDirectivesTask',
      createTask,
      buildInputs,
      <ResultDescriptor>[DIRECTIVES_IN_UNIT, DIRECTIVES_ERRORS]);

  BuildUnitDirectivesTask(AnalysisContext context, AnalysisTarget target)
      : super(context, target);

  @override
  TaskDescriptor get descriptor => DESCRIPTOR;

  TypeProvider typeProvider;

  /**
   * Since <my-comp></my-comp> represents an instantiation of MyComp,
   * especially when MyComp is generic or its superclasses are, we need
   * this. Cache instead of passing around everywhere.
   */
  InterfaceType _instantiatedClassType;

  /**
   * The [ClassElement] being used to create the current component,
   * stored here instead of passing around everywhere.
   */
  ClassElement _currentClassElement;

  @override
  void internalPerform() {
    typeProvider = getRequiredInput(TYPE_PROVIDER_INPUT);
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
        for (ast.Annotation annotationNode in unitMember.metadata) {
          AbstractDirective directive =
              _createDirective(unitMember, annotationNode);
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

  /**
   * Returns an Angular [AbstractDirective] for to the given [node].
   * Returns `null` if not an Angular annotation.
   */
  AbstractDirective _createDirective(
      ast.ClassDeclaration classDeclaration, ast.Annotation node) {
    _currentClassElement = classDeclaration.element;
    _instantiatedClassType = _instantiateClass(_currentClassElement);
    // TODO(scheglov) add support for all the arguments
    bool isComponent = _isAngularAnnotation(node, 'Component');
    bool isDirective = _isAngularAnnotation(node, 'Directive');
    if (isComponent || isDirective) {
      Selector selector = _parseSelector(node);
      if (selector == null) {
        return null;
      }
      AngularElement exportAs = _parseExportAs(node);
      List<InputElement> inputElements = <InputElement>[];
      List<OutputElement> outputElements = <OutputElement>[];
      {
        inputElements.addAll(_parseHeaderInputs(node));
        outputElements.addAll(_parseHeaderOutputs(node));
        _parseMemberInputsAndOutputs(
            classDeclaration, inputElements, outputElements);
      }
      if (isComponent) {
        return new Component(_currentClassElement,
            exportAs: exportAs,
            inputs: inputElements,
            outputs: outputElements,
            selector: selector);
      }
      if (isDirective) {
        return new Directive(_currentClassElement,
            exportAs: exportAs,
            inputs: inputElements,
            outputs: outputElements,
            selector: selector);
      }
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
    String name = _getExpressionString(expression);
    if (name == null) {
      return null;
    }

    int offset;
    if (expression is ast.SimpleStringLiteral) {
      offset = expression.contentsOffset;
    } else {
      offset = expression.offset;
    }
    // Create a new element.
    return new AngularElementImpl(name, offset, name.length, target.source);
  }

  Tuple4<String, SourceRange, String, SourceRange>
      _parseHeaderNameValueSourceRanges(ast.Expression expression) {
    if (expression is ast.SimpleStringLiteral) {
      int offset = expression.contentsOffset;
      String value = expression.value;
      // TODO(mfairhurst) support for pipes
      int colonIndex = value.indexOf(':');
      if (colonIndex == -1) {
        String name = value;
        SourceRange nameRange = new SourceRange(offset, name.length);
        return new Tuple4<String, SourceRange, String, SourceRange>(
            name, nameRange, name, nameRange);
      } else {
        // Resolve the setter.
        String setterName = value.substring(0, colonIndex).trimRight();
        // Find the name.
        int boundOffset = colonIndex;
        while (true) {
          boundOffset++;
          if (boundOffset >= value.length) {
            // TODO(mfairhurst) report a warning
            return null;
          }
          if (value.substring(boundOffset, boundOffset + 1) != ' ') {
            break;
          }
        }
        String boundName = value.substring(boundOffset);
        // TODO(mfairhurst) test that a valid bound name
        return new Tuple4<String, SourceRange, String, SourceRange>(
            boundName,
            new SourceRange(offset + boundOffset, boundName.length),
            setterName,
            new SourceRange(offset, setterName.length));
      }
    } else {
      // TODO(mfairhurst) report a warning
      return null;
    }
  }

  InputElement _parseHeaderInput(ast.Expression expression) {
    Tuple4<String, SourceRange, String, SourceRange> nameValueAndRanges =
        _parseHeaderNameValueSourceRanges(expression);
    if (nameValueAndRanges != null) {
      var boundName = nameValueAndRanges.item1;
      var boundRange = nameValueAndRanges.item2;
      var name = nameValueAndRanges.item3;
      var nameRange = nameValueAndRanges.item4;

      PropertyAccessorElement setter = _resolveSetter(expression, name);
      if (setter == null) {
        return null;
      }

      return new InputElement(boundName, boundRange.offset, boundRange.length,
          target.source, setter, nameRange, _getSetterType(setter));
    } else {
      // TODO(mfairhurst) report a warning
      return null;
    }
  }

  OutputElement _parseHeaderOutput(ast.Expression expression) {
    Tuple4<String, SourceRange, String, SourceRange> nameValueAndRanges =
        _parseHeaderNameValueSourceRanges(expression);
    if (nameValueAndRanges != null) {
      var boundName = nameValueAndRanges.item1;
      var boundRange = nameValueAndRanges.item2;
      var name = nameValueAndRanges.item3;
      var nameRange = nameValueAndRanges.item4;

      PropertyAccessorElement getter = _resolveGetter(expression, name);
      if (getter == null) {
        return null;
      }

      var eventType = getEventType(getter, name);

      return new OutputElement(boundName, boundRange.offset, boundRange.length,
          target.source, getter, nameRange, eventType);
    } else {
      // TODO(mfairhurst) report a warning
      return null;
    }
  }

  DartType _getSetterType(PropertyAccessorElement setter) {
    if (setter != null) {
      setter = _instantiatedClassType.lookUpInheritedSetter(setter.name,
          thisType: true);
    }

    if (setter != null && setter.variable != null) {
      var type = setter.variable.type;
      return type;
    }

    return null;
  }

  DartType getEventType(PropertyAccessorElement getter, String name) {
    if (getter != null) {
      getter = _instantiatedClassType.lookUpInheritedGetter(getter.name,
          thisType: true);
    }

    if (getter != null && getter.type != null) {
      var returnType = getter.type.returnType;
      if (returnType != null && returnType is InterfaceType) {
        DartType streamType = typeProvider.streamType;
        DartType streamedType =
            context.typeSystem.mostSpecificTypeArgument(returnType, streamType);
        if (streamedType != null) {
          return streamedType;
        } else {
          errorReporter.reportErrorForOffset(
              AngularWarningCode.OUTPUT_MUST_BE_EVENTEMITTER,
              getter.nameOffset,
              getter.name.length,
              [name]);
        }
      } else {
        errorReporter.reportErrorForOffset(
            AngularWarningCode.OUTPUT_MUST_BE_EVENTEMITTER,
            getter.nameOffset,
            getter.name.length,
            [name]);
      }
    }

    return typeProvider.dynamicType;
  }

  DartType _instantiateClass(ClassElement classElement) {
    // TODO use `insantiateToBounds` for better all around support
    // See #91 for discussion about bugs related to bounds
    var getBound = (TypeParameterElement p) {
      return p.bound == null
          ? typeProvider.dynamicType
          : p.bound.resolveToBound(typeProvider.dynamicType);
    };

    var bounds = classElement.typeParameters.map(getBound).toList();
    return classElement.type.instantiate(bounds);
  }

  List<InputElement> _parseHeaderInputs(ast.Annotation node) {
    ast.ListLiteral descList = _getListLiteralNamedArgument(
        node, const <String>['inputs', 'properties']);
    if (descList == null) {
      return InputElement.EMPTY_LIST;
    }
    // Create an input for each element.
    List<InputElement> inputElements = <InputElement>[];
    for (ast.Expression element in descList.elements) {
      InputElement inputElement = _parseHeaderInput(element);
      if (inputElement != null) {
        inputElements.add(inputElement);
      }
    }
    return inputElements;
  }

  List<OutputElement> _parseHeaderOutputs(ast.Annotation node) {
    ast.ListLiteral descList =
        _getListLiteralNamedArgument(node, const <String>['outputs']);
    if (descList == null) {
      return OutputElement.EMPTY_LIST;
    }
    // Create an output for each element.
    List<OutputElement> outputs = <OutputElement>[];
    for (ast.Expression element in descList.elements) {
      OutputElement outputElement = _parseHeaderOutput(element);
      if (outputElement != null) {
        outputs.add(outputElement);
      }
    }
    return outputs;
  }

  /**
   * Create a new input or output for the given class member [node] with
   * the given `@Input` or `@Output` [annotation], and add it to the
   * [inputElements] or [outputElements] array.
   */
  _parseMemberInputOrOutput(ast.ClassMember node, ast.Annotation annotation,
      List<InputElement> inputElements, List<OutputElement> outputElements) {
    // analyze the annotation
    final isInput = _isAngularAnnotation(annotation, 'Input');
    final isOutput = _isAngularAnnotation(annotation, 'Output');
    if ((!isInput && !isOutput) || annotation.arguments == null) {
      return null;
    }

    // analyze the class member
    PropertyAccessorElement property;
    if (node is ast.FieldDeclaration && node.fields.variables.length == 1) {
      ast.VariableDeclaration variable = node.fields.variables.first;
      FieldElement fieldElement = variable.element;
      property = isInput ? fieldElement.setter : fieldElement.getter;
    } else if (node is ast.MethodDeclaration) {
      if (isInput && node.isSetter) {
        property = node.element;
      } else if (isOutput && node.isGetter) {
        property = node.element;
      }
    }

    if (property == null) {
      errorReporter.reportErrorForOffset(
          isInput
              ? AngularWarningCode.INPUT_ANNOTATION_PLACEMENT_INVALID
              : AngularWarningCode.OUTPUT_ANNOTATION_PLACEMENT_INVALID,
          annotation.offset,
          annotation.length);
      return null;
    }

    // prepare the input name
    String name;
    int nameOffset;
    int nameLength;
    List<ast.Expression> arguments = annotation.arguments.arguments;
    if (arguments.isEmpty) {
      String propertyName = property.displayName;
      name = propertyName;
      nameOffset = property.nameOffset;
      nameLength = name.length;
    } else {
      ast.Expression nameArgument = arguments[0];
      if (nameArgument is ast.SimpleStringLiteral) {
        name = nameArgument.value;
        nameOffset = nameArgument.contentsOffset;
        nameLength = name.length;
      } else {
        errorReporter.reportErrorForNode(
            AngularWarningCode.STRING_VALUE_EXPECTED, nameArgument);
      }
      if (name == null) {
        return null;
      }
    }

    if (isInput) {
      inputElements.add(new InputElement(name, nameOffset, nameLength,
          target.source, property, null, _getSetterType(property)));
    } else {
      var eventType = getEventType(property, name);
      outputElements.add(new OutputElement(name, nameOffset, nameLength,
          target.source, property, null, eventType));
    }
  }

  /**
   * Collect inputs and outputs for all class members with `@Input`
   * or `@Output` annotations.
   */
  _parseMemberInputsAndOutputs(ast.ClassDeclaration node,
      List<InputElement> inputElements, List<OutputElement> outputElements) {
    for (ast.ClassMember member in node.members) {
      for (ast.Annotation annotation in member.metadata) {
        _parseMemberInputOrOutput(
            member, annotation, inputElements, outputElements);
      }
    }
  }

  Selector _parseSelector(ast.Annotation node) {
    // Find the "selector" argument.
    ast.Expression expression = _getNamedArgument(node, 'selector');
    if (expression == null) {
      errorReporter.reportErrorForNode(
          AngularWarningCode.ARGUMENT_SELECTOR_MISSING, node);
      return null;
    }
    // Compute the selector text. Careful! Offsets may not be valid after this,
    // however, at the moment we don't use them anyway.
    OffsettingConstantEvaluator constantEvaluation =
        _calculateStringWithOffsets(expression);
    if (constantEvaluation == null) {
      return null;
    }

    String selectorStr = constantEvaluation.value;
    int selectorOffset = expression.offset;
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

  /**
   * Resolve the input setter with the given [name] in [_currentClassElement].
   * If undefined, report a warning and return `null`.
   */
  PropertyAccessorElement _resolveSetter(
      ast.SimpleStringLiteral literal, String name) {
    PropertyAccessorElement setter =
        _currentClassElement.lookUpSetter(name, _currentClassElement.library);
    if (setter == null) {
      errorReporter.reportErrorForNode(StaticTypeWarningCode.UNDEFINED_SETTER,
          literal, [name, _currentClassElement.displayName]);
    }
    return setter;
  }

  /**
   * Resolve the output getter with the given [name] in [_currentClassElement].
   * If undefined, report a warning and return `null`.
   */
  PropertyAccessorElement _resolveGetter(
      ast.SimpleStringLiteral literal, String name) {
    PropertyAccessorElement getter =
        _currentClassElement.lookUpGetter(name, _currentClassElement.library);
    if (getter == null) {
      errorReporter.reportErrorForNode(StaticTypeWarningCode.UNDEFINED_GETTER,
          literal, [name, _currentClassElement.displayName]);
    }
    return getter;
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
        ast.Annotation viewAnnotation;
        ast.Annotation componentAnnotation;

        for (ast.Annotation annotation in unitMember.metadata) {
          if (_isAngularAnnotation(annotation, 'View')) {
            viewAnnotation = annotation;
          } else if (_isAngularAnnotation(annotation, 'Component')) {
            componentAnnotation = annotation;
          }
        }

        if (viewAnnotation == null && componentAnnotation == null) {
          continue;
        }

        //@TODO when there's both a @View and @Component, handle edge cases
        View view =
            _createView(classElement, viewAnnotation ?? componentAnnotation);

        if (view != null) {
          views.add(view);
          if (view.templateUriSource != null) {
            viewsWithTemplates.add(view);
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

  /**
   * Attempt to find and add the [AbstractDirective] that corresponds to
   * the [classElement]. Return `true` if success.
   */
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

  /**
   * Attempt to find and add the [AbstractDirective] that corresponds to
   * the [classElement]. Return an error if the directive not found.
   */
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

  /**
   * Create a new [View] for the given [annotation], may return `null`
   * if [annotation] or [classElement] don't provide enough information.
   */
  View _createView(ClassElement classElement, ast.Annotation annotation) {
    // Template in a separate HTML file.
    Source templateUriSource = null;
    bool definesTemplate = false;
    bool definesTemplateUrl = false;
    SourceRange templateUrlRange = null;
    {
      ast.Expression templateUrlExpression =
          _getNamedArgument(annotation, 'templateUrl');
      definesTemplateUrl = templateUrlExpression != null;
      String templateUrl = _getExpressionString(templateUrlExpression);
      if (templateUrl != null) {
        SourceFactory sourceFactory = context.sourceFactory;
        templateUriSource =
            sourceFactory.resolveUri(target.source, templateUrl);

        if (!templateUriSource.exists()) {
          errorReporter.reportErrorForNode(
              AngularWarningCode.REFERENCED_HTML_FILE_DOESNT_EXIST,
              templateUrlExpression);
        }

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
        templateOffset = expression.offset;
        definesTemplate = true;
        OffsettingConstantEvaluator constantEvaluation =
            _calculateStringWithOffsets(expression);

        // highly dynamically generated constant expressions can't be validated
        if (constantEvaluation == null || !constantEvaluation.offsetsAreValid) {
          templateText = '';
        } else {
          templateText = constantEvaluation.value;
        }
      }
    }

    if (definesTemplate && definesTemplateUrl) {
      errorReporter.reportErrorForNode(
          AngularWarningCode.TEMPLATE_URL_AND_TEMPLATE_DEFINED, annotation);

      return null;
    }

    if (!definesTemplate && !definesTemplateUrl) {
      errorReporter.reportErrorForNode(
          AngularWarningCode.NO_TEMPLATE_URL_OR_TEMPLATE_DEFINED, annotation);

      return null;
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

  /**
   * Return a map from the names of the inputs of this kind of task to the
   * task input descriptors describing those inputs for a task with the
   * given [target].
   */
  static Map<String, TaskInput> buildInputs(AnalysisTarget target) {
    return <String, TaskInput>{
      DIRECTIVES_INPUT:
          DIRECTIVES_IN_LIBRARY.of((target as LibrarySpecificUnit).library),
      UNIT_INPUT: RESOLVED_UNIT.of(target)
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
  static const String VIEWS_INPUT = 'VIEWS_INPUT';

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
    List<View> views = getRequiredInput(VIEWS_INPUT);
    //
    // Resolve inline view templates.
    //
    List<Template> templates = <Template>[];
    List<AnalysisError> errors = <AnalysisError>[];
    for (View view in views) {
      if (view.templateText != null) {
        errorListener = new RecordingErrorListener();
        Template template = new DartTemplateResolver(
                typeProvider, htmlComponents, htmlEvents, errorListener, view)
            .resolve();
        if (template != null) {
          templates.add(template);
        }
        errors.addAll(errorListener.errors
            .where((e) => !template.ignoredErrors.contains(e.errorCode.name)));
      }
    }
    //
    // Record outputs.
    //
    outputs[DART_TEMPLATES] = templates;
    outputs[DART_TEMPLATES_ERRORS] = errors;
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
      VIEWS_INPUT: VIEWS.of(target),
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
    html.Document document = getRequiredInput(HTML_DOCUMENT_INPUT);
    //
    // Resolve.
    //
    View view = target;
    Template template = new HtmlTemplateResolver(typeProvider, htmlComponents,
            htmlEvents, errorListener, view, document)
        .resolve();
    //
    // Record outputs.
    //
    outputs[HTML_TEMPLATE] = template;
    outputs[HTML_TEMPLATE_ERRORS] = errorListener.errors
        .where((e) => !template.ignoredErrors.contains(e.errorCode.name))
        .toList();
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
      HTML_DOCUMENT_INPUT: HTML_DOCUMENT.of((target as View).templateUriSource),
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
class _AnnotationProcessorMixin {
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
  void initAnnotationProcessor(AnalysisTarget target) {
    assert(errorReporter == null);
    errorReporter = new ErrorReporter(errorListener, target.source);
  }

  /**
   * Returns the [String] value of the given [expression].
   * If [expression] does not have a [String] value, reports an error
   * and returns `null`.
   */
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

  /**
   * Returns the [String] value of the given [expression].
   * If [expression] does not have a [String] value, reports an error
   * and returns `null`.
   */
  OffsettingConstantEvaluator _calculateStringWithOffsets(
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

  /**
   * Returns `true` is the given [node] is resolved to a creation of an Angular
   * annotation class with the given [name].
   */
  bool _isAngularAnnotation(ast.Annotation node, String name) {
    if (node.element is ConstructorElement) {
      ClassElement clazz = node.element.enclosingElement;
      return clazz.library.source.uri.path
              .endsWith('angular2/src/core/metadata.dart') &&
          clazz.name == name;
    }
    return false;
  }
}

class _BuildStandardHtmlComponentsVisitor extends RecursiveAstVisitor {
  final Map<String, Component> components;
  final Map<String, OutputElement> events;
  final Source source;

  ClassElement classElement;

  _BuildStandardHtmlComponentsVisitor(
      this.components, this.events, this.source);

  @override
  void visitClassDeclaration(ast.ClassDeclaration node) {
    classElement = node.element;
    super.visitClassDeclaration(node);
    if (classElement.name == 'HtmlElement') {
      List<OutputElement> outputElements = _buildOutputs(false);
      for (OutputElement outputElement in outputElements) {
        events[outputElement.name] = outputElement;
      }
    }
    classElement = null;
  }

  @override
  void visitConstructorDeclaration(ast.ConstructorDeclaration node) {
    if (node.factoryKeyword != null) {
      super.visitConstructorDeclaration(node);
    }
  }

  @override
  void visitMethodInvocation(ast.MethodInvocation node) {
    ast.Expression target = node.target;
    ast.ArgumentList argumentList = node.argumentList;
    if (target is ast.SimpleIdentifier &&
        target.name == 'document' &&
        node.methodName.name == 'createElement' &&
        argumentList != null &&
        argumentList.arguments.length == 1) {
      ast.Expression argument = argumentList.arguments.single;
      if (argument is ast.SimpleStringLiteral) {
        String tag = argument.value;
        int tagOffset = argument.contentsOffset;
        Component component = _buildComponent(tag, tagOffset);
        components[tag] = component;
      }
    }
  }

  /**
   * Return a new [Component] for the current [classElement].
   */
  Component _buildComponent(String tag, int tagOffset) {
    List<InputElement> inputElements = _buildInputs();
    List<OutputElement> outputElements = _buildOutputs(true);
    return new Component(classElement,
        inputs: inputElements,
        outputs: outputElements,
        selector: new ElementNameSelector(
            new SelectorName(tag, tagOffset, tag.length, source)));
  }

  List<InputElement> _buildInputs() {
    return _captureAspects(
        (Map<String, InputElement> inputMap, PropertyAccessorElement accessor) {
      String name = accessor.displayName;
      if (!inputMap.containsKey(name)) {
        if (accessor.isSetter) {
          inputMap[name] = new InputElement(
              name,
              accessor.nameOffset,
              accessor.nameLength,
              accessor.source,
              accessor,
              null,
              accessor.variable.type);
        }
      }
    }, false); // don't skip HtmlElement+ inputs, those belong to this component.
  }

  List<OutputElement> _buildOutputs(bool skipHtmlElement) {
    return _captureAspects((Map<String, OutputElement> outputMap,
        PropertyAccessorElement accessor) {
      String domName = _getDomName(accessor);
      if (domName == null) {
        return;
      }

      // Event domnames start with Element.on or Document.on
      int offset = domName.indexOf(".") + ".on".length;
      String name = domName.substring(offset);

      if (!outputMap.containsKey(name)) {
        if (accessor.isGetter) {
          var returnType =
              accessor.type == null ? null : accessor.type.returnType;
          DartType eventType = null;
          if (returnType != null && returnType is InterfaceType) {
            // TODO allow subtypes of ElementStream? This is a generated file
            // so might not be necessary.
            if (returnType.element.name == 'ElementStream') {
              eventType = returnType.typeArguments[0]; // may be null
            }
          }
          outputMap[name] = new OutputElement(name, accessor.nameOffset,
              accessor.nameLength, accessor.source, accessor, null, eventType);
        }
      }
    }, skipHtmlElement); // Either grabbing HtmlElement events or skipping them
  }

  String _getDomName(Element element) {
    for (ElementAnnotation annotation in element.metadata) {
      // this has caching built in, so we can compute every time
      var value = annotation.computeConstantValue();
      if (value != null && value.type is InterfaceType) {
        if (value.type.element.name == 'DomName') {
          return value.getField("name").toStringValue();
        }
      }
    }

    return null;
  }

  List<T> _captureAspects<T>(
      CaptureAspectFn<T> addAspect, bool skipHtmlElement) {
    Map<String, T> aspectMap = <String, T>{};
    Set<InterfaceType> visitedTypes = new Set<InterfaceType>();

    void addAspects(InterfaceType type) {
      if (type != null && visitedTypes.add(type)) {
        // The events defined here are handled specially because everything
        // (even directives) can use them. Note, this leaves only a few
        // special elements with outputs such as BodyElement, everything else
        // relies on standardHtmlEvents checked after the outputs.
        if (!skipHtmlElement || type.name != 'HtmlElement') {
          type.accessors
              .where((elem) => !elem.isPrivate)
              .forEach((elem) => addAspect(aspectMap, elem));
          type.mixins.forEach(addAspects);
          addAspects(type.superclass);
        }
      }
    }

    addAspects(classElement.type);
    return aspectMap.values.toList();
  }
}

typedef void CaptureAspectFn<T>(
    Map<String, T> aspectMap, PropertyAccessorElement accessor);

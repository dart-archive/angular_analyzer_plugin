import 'tasks.dart';
import 'model.dart';

import 'package:analyzer/error/listener.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/resolver.dart' show TypeProvider;
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:tuple/tuple.dart';

class DirectiveExtractor extends AnnotationProcessorMixin {
  final TypeProvider _typeProvider;
  final ast.CompilationUnit _unit;
  final Source _source;
  final AnalysisContext _context;

  /**
   * Since <my-comp></my-comp> represents an instantiation of MyComp,
   * especially when MyComp is generic or its superclasses are, we need
   * this. Cache instead of passing around everywhere.
   */
  BindingTypeSynthesizer _bindingTypeSynthesizer;

  /**
   * The [ClassElement] being used to create the current component,
   * stored here instead of passing around everywhere.
   */
  ClassElement _currentClassElement;

  DirectiveExtractor(
      this._unit, this._typeProvider, this._source, this._context) {
    initAnnotationProcessor(_source);
  }

  List<AbstractDirective> getDirectives() {
    List<AbstractDirective> directives = <AbstractDirective>[];
    for (ast.CompilationUnitMember unitMember in _unit.declarations) {
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

    return directives;
  }

  /**
   * Returns an Angular [AbstractDirective] for to the given [node].
   * Returns `null` if not an Angular annotation.
   */
  AbstractDirective _createDirective(
      ast.ClassDeclaration classDeclaration, ast.Annotation node) {
    _currentClassElement = classDeclaration.element;
    _bindingTypeSynthesizer = new BindingTypeSynthesizer(
        _currentClassElement, _typeProvider, _context, errorReporter);
    // TODO(scheglov) add support for all the arguments
    bool isComponent = isAngularAnnotation(node, 'Component');
    bool isDirective = isAngularAnnotation(node, 'Directive');
    if (isComponent || isDirective) {
      Selector selector = _parseSelector(node);
      if (selector == null) {
        // empty selector. Don't fail to create a Component just because of a
        // broken or missing selector, that results in cascading errors.
        selector = new AndSelector([]);
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
      final contentChilds = <ContentChildField>[];
      final contentChildrens = <ContentChildField>[];
      _parseContentChilds(classDeclaration, contentChilds, contentChildrens);
      List<ElementNameSelector> elementTags = <ElementNameSelector>[];
      selector.recordElementNameSelectors(elementTags);
      if (isComponent) {
        return new Component(_currentClassElement,
            exportAs: exportAs,
            inputs: inputElements,
            outputs: outputElements,
            selector: selector,
            elementTags: elementTags,
            isHtml: false,
            contentChildFields: contentChilds,
            contentChildrenFields: contentChildrens);
      }
      if (isDirective) {
        return new Directive(_currentClassElement,
            exportAs: exportAs,
            inputs: inputElements,
            outputs: outputElements,
            selector: selector,
            elementTags: elementTags,
            contentChildFields: contentChilds,
            contentChildrenFields: contentChildrens);
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
      ast.Expression expression = getNamedArgument(node, name);
      if (expression != null) {
        return expression is ast.ListLiteral ? expression : null;
      }
    }
    return null;
  }

  AngularElement _parseExportAs(ast.Annotation node) {
    // Find the "exportAs" argument.
    ast.Expression expression = getNamedArgument(node, 'exportAs');
    if (expression == null) {
      return null;
    }

    // Extract its content.
    String name = getExpressionString(expression);
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
    return new AngularElementImpl(name, offset, name.length, _source);
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

      return new InputElement(
          boundName,
          boundRange.offset,
          boundRange.length,
          _source,
          setter,
          nameRange,
          _bindingTypeSynthesizer.getSetterType(setter));
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

      var eventType = _bindingTypeSynthesizer.getEventType(getter, name);

      return new OutputElement(boundName, boundRange.offset, boundRange.length,
          _source, getter, nameRange, eventType);
    } else {
      // TODO(mfairhurst) report a warning
      return null;
    }
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
    final isInput = isAngularAnnotation(annotation, 'Input');
    final isOutput = isAngularAnnotation(annotation, 'Output');
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
    int setterOffset = property.nameOffset;
    int setterLength = property.nameLength;
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
      inputElements.add(new InputElement(
          name,
          nameOffset,
          nameLength,
          _source,
          property,
          new SourceRange(setterOffset, setterLength),
          _bindingTypeSynthesizer.getSetterType(property)));
    } else {
      var eventType = _bindingTypeSynthesizer.getEventType(property, name);
      outputElements.add(new OutputElement(
          name,
          nameOffset,
          nameLength,
          _source,
          property,
          new SourceRange(setterOffset, setterLength),
          eventType));
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

  /**
   * Find all fields labeled with @ContentChild and the ranges of the type
   * argument. We will use this to create an unlinked summary which can, at link
   * time, check for errors and highlight the correct range. This is all we need
   * from the AST itself, so all we should do here.
   */
  _parseContentChilds(
      ast.ClassDeclaration node,
      List<ContentChildField> contentChilds,
      List<ContentChildField> contentChildrens) {
    for (ast.ClassMember member in node.members) {
      for (ast.Annotation annotation in member.metadata) {
        List<ContentChildField> targetList;
        if (isAngularAnnotation(annotation, 'ContentChild')) {
          targetList = contentChilds;
        } else if (isAngularAnnotation(annotation, 'ContentChildren')) {
          targetList = contentChildrens;
        } else {
          continue;
        }

        final annotationArgs = annotation?.arguments?.arguments;
        if (annotationArgs == null) {
          // This happens for invalid dart code. Ignore
          continue;
        }

        if (annotationArgs.length == 0) {
          // No need to report an error, dart does that already.
          continue;
        }

        final offset = annotationArgs[0].offset;
        final length = annotationArgs[0].length;
        var setterTypeOffset = member.offset; // fallback option
        var setterTypeLength = member.length; // fallback option

        String name;
        if (member is ast.FieldDeclaration) {
          name = member.fields.variables[0].name.toString();

          if (member.fields.type != null) {
            setterTypeOffset = member.fields.type.offset;
            setterTypeLength = member.fields.type.length;
          }
        } else if (member is ast.MethodDeclaration) {
          name = member.name.toString();

          var parameters = member.parameters?.parameters;
          if (parameters != null && parameters.length > 0) {
            var parameter = parameters[0];
            if (parameter is ast.SimpleFormalParameter &&
                parameter.type != null) {
              setterTypeOffset = parameter.type.offset;
              setterTypeLength = parameter.type.length;
            }
          }
        }
        targetList.add(new ContentChildField(name,
            nameRange: new SourceRange(offset, length),
            typeRange: new SourceRange(setterTypeOffset, setterTypeLength)));
      }
    }
  }

  Selector _parseSelector(ast.Annotation node) {
    // Find the "selector" argument.
    ast.Expression expression = getNamedArgument(node, 'selector');
    if (expression == null) {
      errorReporter.reportErrorForNode(
          AngularWarningCode.ARGUMENT_SELECTOR_MISSING, node);
      return null;
    }
    // Compute the selector text. Careful! Offsets may not be valid after this,
    // however, at the moment we don't use them anyway.
    OffsettingConstantEvaluator constantEvaluation =
        calculateStringWithOffsets(expression);
    if (constantEvaluation == null) {
      return null;
    }

    String selectorStr = constantEvaluation.value;
    int selectorOffset = expression.offset;
    // Parse the selector text.
    try {
      Selector selector =
          new SelectorParser(_source, selectorOffset, selectorStr).parse();
      if (selector == null) {
        errorReporter.reportErrorForNode(
            AngularWarningCode.CANNOT_PARSE_SELECTOR,
            expression,
            [selectorStr]);
      }
      return selector;
    } on SelectorParseError catch (e) {
      errorReporter.reportErrorForOffset(
          AngularWarningCode.CANNOT_PARSE_SELECTOR,
          e.offset,
          e.length,
          [e.message]);
    }

    return null;
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
}

class AttributeAnnotationValidator {
  final ErrorReporter errorReporter;

  AttributeAnnotationValidator(this.errorReporter);

  void validate(AbstractDirective directive) {
    ClassElement classElement = directive.classElement;
    for (final constructor in classElement.constructors) {
      for (final parameter in constructor.parameters) {
        for (final annotation in parameter.metadata) {
          if (annotation.element?.enclosingElement?.name != "Attribute") {
            continue;
          }

          final attributeName = annotation
              .computeConstantValue()
              ?.getField("attributeName")
              ?.toStringValue();
          if (attributeName == null) {
            continue;
            // TODO do we ever need to report an error here, or will DAS?
          }

          if (parameter.type.name != "String") {
            errorReporter.reportErrorForOffset(
                AngularWarningCode.ATTRIBUTE_PARAMETER_MUST_BE_STRING,
                parameter.nameOffset,
                parameter.name.length);
          }

          directive.attributes.add(new AngularElementImpl(attributeName,
              parameter.nameOffset, parameter.nameLength, parameter.source));
        }
      }
    }
  }
}

class BindingTypeSynthesizer {
  final InterfaceType _instantiatedClassType;
  final TypeProvider _typeProvider;
  final AnalysisContext _context;
  final ErrorReporter _errorReporter;

  BindingTypeSynthesizer(ClassElement classElem, TypeProvider typeProvider,
      this._context, this._errorReporter)
      : _instantiatedClassType = _instantiateClass(classElem, typeProvider),
        _typeProvider = typeProvider;

  DartType getSetterType(PropertyAccessorElement setter) {
    if (setter != null) {
      setter = _instantiatedClassType.lookUpInheritedSetter(setter.name,
          thisType: true);
    }

    if (setter != null && setter.type.parameters.length == 1) {
      return setter.type.parameters[0].type;
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
        DartType streamType = _typeProvider.streamType;
        DartType streamedType = _context.typeSystem
            .mostSpecificTypeArgument(returnType, streamType);
        if (streamedType != null) {
          return streamedType;
        } else {
          _errorReporter.reportErrorForOffset(
              AngularWarningCode.OUTPUT_MUST_BE_STREAM,
              getter.nameOffset,
              getter.name.length,
              [name]);
        }
      } else {
        _errorReporter.reportErrorForOffset(
            AngularWarningCode.OUTPUT_MUST_BE_STREAM,
            getter.nameOffset,
            getter.name.length,
            [name]);
      }
    }

    return _typeProvider.dynamicType;
  }

  static DartType _instantiateClass(
      ClassElement classElement, TypeProvider typeProvider) {
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
}

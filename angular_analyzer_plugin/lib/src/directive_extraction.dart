import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/resolver.dart' show TypeProvider;
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/errors.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/tasks.dart';
import 'package:angular_analyzer_plugin/src/tuple.dart';

class AttributeAnnotationValidator {
  final ErrorReporter errorReporter;

  AttributeAnnotationValidator(this.errorReporter);

  void validate(AbstractClassDirective directive) {
    final classElement = directive.classElement;
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

  DartType getEventType(PropertyAccessorElement getter, String name) {
    if (getter != null) {
      // ignore: parameter_assignments
      getter = _instantiatedClassType.lookUpInheritedGetter(getter.name,
          thisType: true);
    }

    if (getter != null && getter.type != null) {
      final returnType = getter.type.returnType;
      if (returnType != null && returnType is InterfaceType) {
        final streamType = _typeProvider.streamType;
        final streamedType = _context.typeSystem
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

  DartType getSetterType(PropertyAccessorElement setter) {
    if (setter != null) {
      // ignore: parameter_assignments
      setter = _instantiatedClassType.lookUpInheritedSetter(setter.name,
          thisType: true);
    }

    if (setter != null && setter.type.parameters.length == 1) {
      return setter.type.parameters[0].type;
    }

    return null;
  }

  static InterfaceType _instantiateClass(
      ClassElement classElement, TypeProvider typeProvider) {
    // TODO use `insantiateToBounds` for better all around support
    // See #91 for discussion about bugs related to bounds
    DartType getBound(TypeParameterElement p) => p.bound == null
        ? typeProvider.dynamicType
        : p.bound.resolveToBound(typeProvider.dynamicType);

    final bounds = classElement.typeParameters.map(getBound).toList();
    return classElement.type.instantiate(bounds);
  }
}

class DirectiveExtractor extends AnnotationProcessorMixin {
  final TypeProvider _typeProvider;
  final ast.CompilationUnit _unit;
  final Source _source;
  final AnalysisContext _context;

  /// Since <my-comp></my-comp> represents an instantiation of MyComp,
  /// especially when MyComp is generic or its superclasses are, we need
  /// this. Cache instead of passing around everywhere.
  BindingTypeSynthesizer _bindingTypeSynthesizer;

  /// The [ClassElement] being used to create the current component,
  /// stored here instead of passing around everywhere.
  ClassElement _currentClassElement;

  DirectiveExtractor(
      this._unit, this._typeProvider, this._source, this._context) {
    initAnnotationProcessor(_source);
  }

  List<AngularTopLevel> getAngularTopLevels() {
    final declarations = <AngularTopLevel>[];
    for (final unitMember in _unit.declarations) {
      if (unitMember is ast.ClassDeclaration) {
        final directive = _getAngularAnnotatedClass(unitMember);
        if (directive != null) {
          declarations.add(directive);
        }
      } else if (unitMember is ast.FunctionDeclaration) {
        final directive = _getFunctionalDirective(unitMember);
        if (directive != null) {
          declarations.add(directive);
        }
      }
    }

    return declarations;
  }

  /// Returns an Angular [AbstractDirective] for to the given [node].
  /// Returns `null` if not an Angular annotation.
  AngularAnnotatedClass _getAngularAnnotatedClass(
      ast.ClassDeclaration classDeclaration) {
    _currentClassElement = classDeclaration.element;
    _bindingTypeSynthesizer = new BindingTypeSynthesizer(
        _currentClassElement, _typeProvider, _context, errorReporter);
    // TODO(scheglov) add support for all the arguments
    final componentNode = classDeclaration.metadata.firstWhere(
        (ann) => isAngularAnnotation(ann, 'Component'),
        orElse: () => null);
    final directiveNode = classDeclaration.metadata.firstWhere(
        (ann) => isAngularAnnotation(ann, 'Directive'),
        orElse: () => null);
    final annotationNode = componentNode ?? directiveNode;

    final inputElements = <InputElement>[];
    final outputElements = <OutputElement>[];
    final contentChilds = <ContentChildField>[];
    final contentChildrens = <ContentChildField>[];
    _parseContentChilds(classDeclaration, contentChilds, contentChildrens);

    if (annotationNode != null) {
      // Don't fail to create a Component just because of a broken or missing
      // selector, that results in cascading errors.
      final selector = _parseSelector(annotationNode) ?? new AndSelector([]);
      final exportAs = _parseExportAs(annotationNode);
      final elementTags = <ElementNameSelector>[];
      inputElements.addAll(_parseHeaderInputs(annotationNode));
      outputElements.addAll(_parseHeaderOutputs(annotationNode));
      _parseMemberInputsAndOutputs(
          classDeclaration, inputElements, outputElements);
      selector.recordElementNameSelectors(elementTags);
      if (componentNode != null) {
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
      if (directiveNode != null) {
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

    _parseMemberInputsAndOutputs(
        classDeclaration, inputElements, outputElements);
    if (inputElements.isNotEmpty ||
        outputElements.isNotEmpty ||
        contentChilds.isNotEmpty ||
        contentChildrens.isNotEmpty) {
      return new AngularAnnotatedClass(_currentClassElement,
          inputs: inputElements,
          outputs: outputElements,
          contentChildFields: contentChilds,
          contentChildrenFields: contentChildrens);
    }

    return null;
  }

  /// Returns an Angular [FunctionalDirective] for to the given [node].
  /// Returns `null` if not an Angular annotation.
  FunctionalDirective _getFunctionalDirective(
      ast.FunctionDeclaration functionDeclaration) {
    final functionElement = functionDeclaration.element as FunctionElement;
    final annotationNode = functionDeclaration.metadata.firstWhere(
        (ann) => isAngularAnnotation(ann, 'Directive'),
        orElse: () => null);

    if (annotationNode != null) {
      // Don't fail to create a directive just because of a broken or missing
      // selector, that results in cascading errors.
      final selector = _parseSelector(annotationNode) ?? new AndSelector([]);
      final elementTags = <ElementNameSelector>[];
      final exportAs = getNamedArgument(annotationNode, 'exportAs');
      if (exportAs != null) {
        errorReporter.reportErrorForNode(
            AngularWarningCode.FUNCTIONAL_DIRECTIVES_CANT_BE_EXPORTED,
            exportAs);
      }
      selector.recordElementNameSelectors(elementTags);
      return new FunctionalDirective(functionElement, selector, elementTags);
    }

    return null;
  }

  /// Return the first named argument with one of the given names, or
  /// `null` if this argument is not [ast.ListLiteral] or no such arguments.
  ast.ListLiteral _getListLiteralNamedArgument(
      ast.Annotation node, List<String> names) {
    for (final name in names) {
      // ignore: omit_local_variable_types
      final ast.Expression expression = getNamedArgument(node, name);
      if (expression != null) {
        return expression is ast.ListLiteral ? expression : null;
      }
    }
    return null;
  }

  /// Find all fields labeled with @ContentChild and the ranges of the type
  /// argument. We will use this to create an unlinked summary which can, at link
  /// time, check for errors and highlight the correct range. This is all we need
  /// from the AST itself, so all we should do here.
  void _parseContentChilds(
      ast.ClassDeclaration node,
      List<ContentChildField> contentChilds,
      List<ContentChildField> contentChildrens) {
    for (final member in node.members) {
      for (final annotation in member.metadata) {
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

        if (annotationArgs.isEmpty) {
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

          final parameters = member.parameters?.parameters;
          if (parameters != null && parameters.isNotEmpty) {
            final parameter = parameters[0];
            if (parameter is ast.SimpleFormalParameter &&
                parameter.type != null) {
              setterTypeOffset = parameter.type.offset;
              setterTypeLength = parameter.type.length;
            }
          }
        }

        if (name != null) {
          targetList.add(new ContentChildField(name,
              nameRange: new SourceRange(offset, length),
              typeRange: new SourceRange(setterTypeOffset, setterTypeLength)));
        }
      }
    }
  }

  AngularElement _parseExportAs(ast.Annotation node) {
    // Find the "exportAs" argument.
    // ignore: omit_local_variable_types
    final ast.Expression expression = getNamedArgument(node, 'exportAs');
    if (expression == null) {
      return null;
    }

    // Extract its content.
    final name = getExpressionString(expression);
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

  InputElement _parseHeaderInput(ast.Expression expression) {
    // ignore: omit_local_variable_types
    final Tuple4<String, SourceRange, String, SourceRange> nameValueAndRanges =
        _parseHeaderNameValueSourceRanges(expression);
    if (nameValueAndRanges != null && expression is ast.SimpleStringLiteral) {
      final boundName = nameValueAndRanges.item1;
      final boundRange = nameValueAndRanges.item2;
      final name = nameValueAndRanges.item3;
      final nameRange = nameValueAndRanges.item4;

      final setter = _resolveSetter(expression, name);
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

  List<InputElement> _parseHeaderInputs(ast.Annotation node) {
    final descList = _getListLiteralNamedArgument(
        node, const <String>['inputs', 'properties']);
    if (descList == null) {
      return const <InputElement>[];
    }
    // Create an input for each element.
    final inputElements = <InputElement>[];
    // ignore: omit_local_variable_types
    for (ast.Expression element in descList.elements) {
      final inputElement = _parseHeaderInput(element);
      if (inputElement != null) {
        inputElements.add(inputElement);
      }
    }
    return inputElements;
  }

  Tuple4<String, SourceRange, String, SourceRange>
      _parseHeaderNameValueSourceRanges(ast.Expression expression) {
    if (expression is ast.SimpleStringLiteral) {
      final offset = expression.contentsOffset;
      final value = expression.value;
      // TODO(mfairhurst) support for pipes
      final colonIndex = value.indexOf(':');
      if (colonIndex == -1) {
        final name = value;
        final nameRange = new SourceRange(offset, name.length);
        return new Tuple4<String, SourceRange, String, SourceRange>(
            name, nameRange, name, nameRange);
      } else {
        // Resolve the setter.
        final setterName = value.substring(0, colonIndex).trimRight();
        // Find the name.
        var boundOffset = colonIndex;
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
        final boundName = value.substring(boundOffset);
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

  OutputElement _parseHeaderOutput(ast.Expression expression) {
    // ignore: omit_local_variable_types
    final Tuple4<String, SourceRange, String, SourceRange> nameValueAndRanges =
        _parseHeaderNameValueSourceRanges(expression);
    if (nameValueAndRanges != null && expression is ast.SimpleStringLiteral) {
      final boundName = nameValueAndRanges.item1;
      final boundRange = nameValueAndRanges.item2;
      final name = nameValueAndRanges.item3;
      final nameRange = nameValueAndRanges.item4;

      final getter = _resolveGetter(expression, name);
      if (getter == null) {
        return null;
      }

      final eventType = _bindingTypeSynthesizer.getEventType(getter, name);

      return new OutputElement(boundName, boundRange.offset, boundRange.length,
          _source, getter, nameRange, eventType);
    } else {
      // TODO(mfairhurst) report a warning
      return null;
    }
  }

  List<OutputElement> _parseHeaderOutputs(ast.Annotation node) {
    final descList =
        _getListLiteralNamedArgument(node, const <String>['outputs']);
    if (descList == null) {
      return const <OutputElement>[];
    }
    // Create an output for each element.
    final outputs = <OutputElement>[];
    // ignore: omit_local_variable_types
    for (ast.Expression element in descList.elements) {
      final outputElement = _parseHeaderOutput(element);
      if (outputElement != null) {
        outputs.add(outputElement);
      }
    }
    return outputs;
  }

  /// Create a new input or output for the given class member [node] with
  /// the given `@Input` or `@Output` [annotation], and add it to the
  /// [inputElements] or [outputElements] array.
  void _parseMemberInputOrOutput(
      ast.ClassMember node,
      ast.Annotation annotation,
      List<InputElement> inputElements,
      List<OutputElement> outputElements) {
    // analyze the annotation
    final isInput = isAngularAnnotation(annotation, 'Input');
    final isOutput = isAngularAnnotation(annotation, 'Output');
    if ((!isInput && !isOutput) || annotation.arguments == null) {
      return null;
    }

    // analyze the class member
    PropertyAccessorElement property;
    if (node is ast.FieldDeclaration && node.fields.variables.length == 1) {
      final variable = node.fields.variables.first;
      final fieldElement = variable.element as FieldElement;
      property = isInput ? fieldElement.setter : fieldElement.getter;
    } else if (node is ast.MethodDeclaration) {
      if (isInput && node.isSetter) {
        property = node.element as PropertyAccessorElement;
      } else if (isOutput && node.isGetter) {
        property = node.element as PropertyAccessorElement;
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

    final setterOffset = property.nameOffset;
    final setterLength = property.nameLength;
    final arguments = annotation.arguments.arguments;

    // prepare the input name
    String name;
    int nameOffset;
    int nameLength;
    if (arguments.isEmpty) {
      final propertyName = property.displayName;
      name = propertyName;
      nameOffset = property.nameOffset;
      nameLength = name.length;
    } else {
      // ignore: omit_local_variable_types
      final ast.Expression nameArgument = arguments[0];
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
      final eventType = _bindingTypeSynthesizer.getEventType(property, name);
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

  /// Collect inputs and outputs for all class members with `@Input`
  /// or `@Output` annotations.
  void _parseMemberInputsAndOutputs(ast.ClassDeclaration node,
      List<InputElement> inputElements, List<OutputElement> outputElements) {
    for (final member in node.members) {
      for (final annotation in member.metadata) {
        _parseMemberInputOrOutput(
            member, annotation, inputElements, outputElements);
      }
    }
  }

  Selector _parseSelector(ast.Annotation node) {
    // Find the "selector" argument.
    // ignore: omit_local_variable_types
    final ast.Expression expression = getNamedArgument(node, 'selector');
    if (expression == null) {
      errorReporter.reportErrorForNode(
          AngularWarningCode.ARGUMENT_SELECTOR_MISSING, node);
      return null;
    }
    // Compute the selector text. Careful! Offsets may not be valid after this,
    // however, at the moment we don't use them anyway.
    // ignore: omit_local_variable_types
    final OffsettingConstantEvaluator constantEvaluation =
        calculateStringWithOffsets(expression);
    if (constantEvaluation == null || constantEvaluation.value is! String) {
      return null;
    }

    final selectorStr = constantEvaluation.value as String;
    final selectorOffset = expression.offset;
    // Parse the selector text.
    try {
      final selector =
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

  /// Resolve the output getter with the given [name] in [_currentClassElement].
  /// If undefined, report a warning and return `null`.
  PropertyAccessorElement _resolveGetter(
      ast.SimpleStringLiteral literal, String name) {
    final getter =
        _currentClassElement.lookUpGetter(name, _currentClassElement.library);
    if (getter == null) {
      errorReporter.reportErrorForNode(StaticTypeWarningCode.UNDEFINED_GETTER,
          literal, [name, _currentClassElement.displayName]);
    }
    return getter;
  }

  /// Resolve the input setter with the given [name] in [_currentClassElement].
  /// If undefined, report a warning and return `null`.
  PropertyAccessorElement _resolveSetter(
      ast.SimpleStringLiteral literal, String name) {
    final setter =
        _currentClassElement.lookUpSetter(name, _currentClassElement.library);
    if (setter == null) {
      errorReporter.reportErrorForNode(StaticTypeWarningCode.UNDEFINED_SETTER,
          literal, [name, _currentClassElement.displayName]);
    }
    return setter;
  }
}

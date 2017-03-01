import 'tasks.dart';
import 'model.dart';

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
      List<ElementNameSelector> elementTags =
          _getElementTagsFromSelector(selector);
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
            selector: selector,
            elementTags: elementTags,
            isHtml: false);
      }
      if (isDirective) {
        return new Directive(_currentClassElement,
            exportAs: exportAs,
            inputs: inputElements,
            outputs: outputElements,
            selector: selector,
            elementTags: elementTags    : p.bound.resolveToBound(typeProvider.dynamicType);
    };

    var bounds = classElement.typeParameters.map(getBound).toList();
    return classElement.type.instantiate(bounds);
  }
}

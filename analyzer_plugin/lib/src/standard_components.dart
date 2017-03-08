import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';

class StandardHtml {
  final Map<String, Component> components;
  final Map<String, OutputElement> events;
  final Map<String, InputElement> attributes;

  StandardHtml(this.components, this.events, this.attributes);
}

class BuildStandardHtmlComponentsVisitor extends RecursiveAstVisitor {
  final Map<String, Component> components;
  final Map<String, OutputElement> events;
  final Map<String, InputElement> attributes;
  final Source source;

  static const Map<String, String> specialElementClasses =
      const <String, String>{
    "OptionElement": 'option',
    "DialogElement": "dialog",
    "MediaElement": "media",
    "MenuItemElement": "menuitem",
    "ModElement": "mod",
    "PictureElement": "picture"
  };

  ClassElement classElement;

  BuildStandardHtmlComponentsVisitor(
      this.components, this.events, this.attributes, this.source);

  @override
  void visitClassDeclaration(ast.ClassDeclaration node) {
    classElement = node.element;
    super.visitClassDeclaration(node);
    if (classElement.name == 'HtmlElement') {
      List<OutputElement> outputElements = _buildOutputs(false);
      for (OutputElement outputElement in outputElements) {
        events[outputElement.name] = outputElement;
      }
      List<InputElement> inputElements = _buildInputs(false);
      for (InputElement inputElement in inputElements) {
        attributes[inputElement.name] = inputElement;
      }
    } else {
      String specialTagName = specialElementClasses[classElement.name];
      if (specialTagName != null) {
        String tag = specialTagName;
        // TODO any better offset we can do here?
        int tagOffset = classElement.nameOffset + 'HTML'.length;
        Component component = _buildComponent(tag, tagOffset);
        components[tag] = component;
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
    List<InputElement> inputElements = _buildInputs(true);
    List<OutputElement> outputElements = _buildOutputs(true);
    return new Component(classElement,
        inputs: inputElements,
        outputs: outputElements,
        selector: new ElementNameSelector(
            new SelectorName(tag, tagOffset, tag.length, source)),
        isHtml: true);
  }

  List<InputElement> _buildInputs(bool skipHtmlElement) {
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
              new SourceRange(accessor.nameOffset, accessor.nameLength),
              accessor.variable.type);
        }
      }
    }, skipHtmlElement); // Either grabbing HtmlElement attrs or skipping them
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
              outputMap[name] = new OutputElement(
                  name,
                  accessor.nameOffset,
                  accessor.nameLength,
                  accessor.source,
                  accessor,
                  null,
                  eventType);
            }
          }
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

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

  /// In attributes, there can be multiple strings that point to the
  /// same [InputElement] generated from [alternativeInputs] (below).
  /// This will provide a static source of unique [InputElement]s.
  final Set<InputElement> uniqueAttributeElements;

  StandardHtml(this.components, this.events, this.attributes)
      : uniqueAttributeElements = new Set.from(attributes.values);
}

class StandardAngular {
  final ClassElement templateRef;
  final ClassElement elementRef;
  final ClassElement queryList;
  final ClassElement pipeTransform;

  StandardAngular(
      {this.templateRef, this.elementRef, this.queryList, this.pipeTransform});
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

  // https://github.com/dart-lang/angular2/blob/8220ba3a693aff51eed33cd1ec9542bde9017423/lib/src/compiler/schema/dom_element_schema_registry.dart#L199
  static const alternativeInputs = const {
    'className': 'class',
    'innerHTML': 'innerHtml',
    'readOnly': 'readonly',
    'tabIndex': 'tabindex',
  };

  ClassElement classElement;

  BuildStandardHtmlComponentsVisitor(
      this.components, this.events, this.attributes, this.source);

  @override
  void visitClassDeclaration(ast.ClassDeclaration node) {
    classElement = node.element;
    super.visitClassDeclaration(node);
    if (classElement.name == 'HtmlElement') {
      final outputElements = _buildOutputs(false);
      for (final outputElement in outputElements) {
        events[outputElement.name] = outputElement;
      }
      final inputElements = _buildInputs(false);
      for (final inputElement in inputElements) {
        attributes[inputElement.name] = inputElement;
        final originalName = inputElement.originalName;
        if (originalName != null) {
          attributes[originalName] = inputElement;
        }
      }
    } else {
      final specialTagName = specialElementClasses[classElement.name];
      if (specialTagName != null) {
        final tag = specialTagName;
        // TODO any better offset we can do here?
        final tagOffset = classElement.nameOffset + 'HTML'.length;
        final component = _buildComponent(tag, tagOffset);
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
    // ignore: omit_local_variable_types
    final ast.Expression target = node.target;
    final argumentList = node.argumentList;
    if (target is ast.SimpleIdentifier &&
        target.name == 'document' &&
        node.methodName.name == 'createElement' &&
        argumentList != null &&
        argumentList.arguments.length == 1) {
      final argument = argumentList.arguments.single;
      if (argument is ast.SimpleStringLiteral) {
        final tag = argument.value;
        final tagOffset = argument.contentsOffset;
        final component = _buildComponent(tag, tagOffset);
        components[tag] = component;
      }
    } else if (node.methodName.name == 'JS' &&
        argumentList != null &&
        argumentList.arguments.length == 4) {
      final documentArgument = argumentList.arguments[2];
      final tagArgument = argumentList.arguments[3];
      if (documentArgument is ast.SimpleIdentifier &&
          documentArgument.name == 'document' &&
          tagArgument is ast.SimpleStringLiteral) {
        final tag = tagArgument.value;
        final tagOffset = tagArgument.contentsOffset;
        final component = _buildComponent(tag, tagOffset);
        components[tag] = component;
      }
    }
  }

  /// Return a new [Component] for the current [classElement].
  Component _buildComponent(String tag, int tagOffset) {
    final inputElements = _buildInputs(true);
    final outputElements = _buildOutputs(true);
    return new Component(classElement,
        inputs: inputElements,
        outputs: outputElements,
        selector: new ElementNameSelector(
            new SelectorName(tag, tagOffset, tag.length, source)),
        isHtml: true);
  }

  /// dart:html is missing an annotation to fix this casing. Compensate.
  /// TODO(mfairhurst) remove this fix once dart:html is fixed
  String fixName(String name) => name == 'innerHtml' ? 'innerHTML' : name;

  List<InputElement> _buildInputs(bool skipHtmlElement) =>
      _captureAspects((inputMap, accessor) {
        final name = fixName(accessor.displayName);
        final prettyName = alternativeInputs[name];
        final originalName = prettyName == null ? null : name;
        if (!inputMap.containsKey(name)) {
          if (accessor.isSetter) {
            inputMap[name] = new InputElement(
              prettyName ?? name,
              accessor.nameOffset,
              accessor.nameLength,
              accessor.source,
              accessor,
              new SourceRange(accessor.nameOffset, accessor.nameLength),
              accessor.variable.type,
              originalName: originalName,
            );
          }
        }
      }, skipHtmlElement); // Either grabbing HtmlElement attrs or skipping them

  List<OutputElement> _buildOutputs(bool skipHtmlElement) =>
      _captureAspects((outputMap, accessor) {
        final domName = _getDomName(accessor);
        if (domName == null) {
          return;
        }

        // Event domnames start with Element.on or Document.on
        final offset = domName.indexOf(".") + ".on".length;
        final name = domName.substring(offset);

        if (!outputMap.containsKey(name)) {
          if (accessor.isGetter) {
            final returnType =
                accessor.type == null ? null : accessor.type.returnType;
            DartType eventType;
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

  String _getDomName(Element element) {
    for (final annotation in element.metadata) {
      // this has caching built in, so we can compute every time
      final value = annotation.computeConstantValue();
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
    final aspectMap = <String, T>{};
    final visitedTypes = new Set<InterfaceType>();

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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';

typedef void CaptureAspectFn<T>(
    Map<String, T> aspectMap, PropertyAccessorElement accessor);

class BuildStandardHtmlComponentsVisitor extends RecursiveAstVisitor {
  static const Map<String, String> specialElementClasses =
      const <String, String>{
    "AudioElement": 'audio',
    "OptionElement": 'option',
    "DialogElement": "dialog",
    "MediaElement": "media",
    "MenuItemElement": "menuitem",
    "ModElement": "mod",
    "PictureElement": "picture"
  };
  static const alternativeInputs = const {
    'className': 'class',
    'innerHTML': 'innerHtml',
    'readOnly': 'readonly',
    'tabIndex': 'tabindex',
  };
  static const missingOutputs = const {
    'focusin': 'FocusEvent',
    'focusout': 'FocusEvent',
  };
  final Map<String, Component> components;
  final Map<String, OutputElement> events;

  final Map<String, InputElement> attributes;

  // https://github.com/dart-lang/angular2/blob/8220ba3a693aff51eed33cd1ec9542bde9017423/lib/src/compiler/schema/dom_element_schema_registry.dart#L199
  final Source source;

  final SecuritySchema securitySchema;

  ClassElement classElement;

  BuildStandardHtmlComponentsVisitor(this.components, this.events,
      this.attributes, this.source, this.securitySchema);

  /// dart:html is missing an annotation to fix this casing. Compensate.
  /// TODO(mfairhurst) remove this fix once dart:html is fixed
  String fixName(String name) => name == 'innerHtml' ? 'innerHTML' : name;

  @override
  void visitClassDeclaration(ast.ClassDeclaration node) {
    classElement = node.element;
    super.visitClassDeclaration(node);
    if (classElement.name == 'HtmlElement') {
      final outputElements = _buildOutputs(true);
      for (final outputElement in outputElements) {
        events[outputElement.name] = outputElement;
      }
      final inputElements = _buildInputs();
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
  void visitCompilationUnit(ast.CompilationUnit unit) {
    super.visitCompilationUnit(unit);

    missingOutputs.forEach((name, type) {
      final namespace = unit.element.library.publicNamespace;
      final ClassElement eventClass = namespace.get(type);
      events[name] = new OutputElement(
          name, null, null, unit.element.source, null, null, eventClass.type);
    });
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
        // don't track <template>, angular treats those specially.
        if (tag != "template") {
          final component = _buildComponent(tag, tagOffset);
          components[tag] = component;
        }
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
        // don't track <template>, angular treats those specially.
        if (tag != "template") {
          final component = _buildComponent(tag, tagOffset);
          components[tag] = component;
        }
      }
    }
  }

  /// Return a new [Component] for the current [classElement].
  Component _buildComponent(String tag, int tagOffset) {
    final inputElements = _buildInputs(tagname: tag);
    final outputElements = _buildOutputs(false);
    return new Component(classElement,
        inputs: inputElements,
        outputs: outputElements,
        selector: new ElementNameSelector(
            new SelectorName(tag, tagOffset, tag.length, source)),
        isHtml: true);
  }

  List<InputElement> _buildInputs({String tagname}) =>
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
                securityContext: tagname == null
                    ? securitySchema.lookupGlobal(name)
                    : securitySchema.lookup(tagname, name));
          }
        }
      }, tagname == null); // Either grabbing HtmlElement attrs or skipping them

  List<OutputElement> _buildOutputs(bool globalOutputs) =>
      _captureAspects((outputMap, accessor) {
        final domName = accessor.name.toLowerCase();
        if (domName == null) {
          return;
        }

        // Event domnames start with on
        final name = domName.substring("on".length);

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
      }, globalOutputs); // Either grabbing HtmlElement events or skipping them

  List<T> _captureAspects<T>(CaptureAspectFn<T> addAspect, bool globalAspects) {
    final aspectMap = <String, T>{};
    final visitedTypes = new Set<InterfaceType>();

    void addAspects(InterfaceType type) {
      if (type != null && visitedTypes.add(type)) {
        // The events defined here are handled specially because everything
        // (even directives) can use them. Note, this leaves only a few
        // special elements with outputs such as BodyElement, everything else
        // relies on standardHtmlEvents checked after the outputs.
        if (globalAspects || type.name != 'HtmlElement') {
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

class SecurityContext {
  final List<DartType> safeTypes;
  final bool sanitizationAvailable;

  SecurityContext(this.safeTypes, {this.sanitizationAvailable = true});
}

class SecuritySchema {
  final Map<String, SecurityContext> schema = {};

  SecuritySchema(
      {SecurityContext htmlSecurityContext,
      SecurityContext urlSecurityContext,
      SecurityContext scriptSecurityContext,
      SecurityContext styleSecurityContext,
      SecurityContext resourceUrlSecurityContext}) {
    // This is written to be easily synced to angular's security
    _registerSecuritySchema(
        htmlSecurityContext, ['iframe|srcdoc', '*|innerHTML', '*|outerHTML']);
    _registerSecuritySchema(styleSecurityContext, ['*|style']);
    _registerSecuritySchema(urlSecurityContext, [
      '*|formAction',
      'area|href',
      'area|ping',
      'audio|src',
      'a|href',
      'a|ping',
      'blockquote|cite',
      'body|background',
      'del|cite',
      'form|action',
      'img|src',
      'img|srcset',
      'input|src',
      'ins|cite',
      'q|cite',
      'source|src',
      'source|srcset',
      'video|poster',
      'video|src'
    ]);
    _registerSecuritySchema(resourceUrlSecurityContext, [
      'applet|code',
      'applet|codebase',
      'base|href',
      'embed|src',
      'frame|src',
      'head|profile',
      'html|manifest',
      'iframe|src',
      'link|href',
      'media|src',
      'object|codebase',
      'object|data',
      'script|src',
      'track|src'
    ]);
    // TODO where's script security?
  }

  SecurityContext lookup(String elementName, String name) =>
      schema['$elementName|$name'];

  SecurityContext lookupGlobal(String name) => schema['*|$name'];

  void _registerSecuritySchema(SecurityContext context, List<String> specs) {
    for (final spec in specs) {
      schema[spec] = context;
    }
  }
}

class StandardAngular {
  final ClassElement templateRef;
  final ClassElement elementRef;
  final ClassElement queryList;
  final ClassElement pipeTransform;
  final ClassElement component;
  final SecuritySchema securitySchema;

  StandardAngular(
      {this.templateRef,
      this.elementRef,
      this.queryList,
      this.pipeTransform,
      this.component,
      this.securitySchema});

  factory StandardAngular.fromAnalysis(
      {ResolvedUnitResult angularResult,
      ResolvedUnitResult securityResult,
      ResolvedUnitResult protoSecurityResult}) {
    final ng = angularResult.unit.element.library.exportNamespace;
    final security = securityResult.unit.element.library.exportNamespace;
    final protoSecurity = protoSecurityResult == null
        ? null
        : protoSecurityResult.unit.element.library.exportNamespace;

    List<DartType> safeTypes(String id) =>
        [security.get('Safe$id'), protoSecurity?.get('Safe${id}Proto')]
            .whereType<ClassElement>()
            .map((e) => e?.type)
            .where((e) => e != null)
            .toList();

    final securitySchema = new SecuritySchema(
        htmlSecurityContext: SecurityContext(safeTypes('Html')),
        urlSecurityContext: SecurityContext(safeTypes('Url')),
        styleSecurityContext: SecurityContext(safeTypes('Style')),
        scriptSecurityContext:
            SecurityContext(safeTypes('Script'), sanitizationAvailable: false),
        resourceUrlSecurityContext: SecurityContext(safeTypes('ResourceUrl'),
            sanitizationAvailable: false));

    return new StandardAngular(
        queryList: ng.get("QueryList") as ClassElement,
        elementRef: ng.get("ElementRef") as ClassElement,
        templateRef: ng.get("TemplateRef") as ClassElement,
        pipeTransform: ng.get("PipeTransform") as ClassElement,
        component: ng.get("Component") as ClassElement,
        securitySchema: securitySchema);
  }
}

class StandardHtml {
  final Map<String, Component> components;
  final Map<String, InputElement> attributes;
  final Map<String, OutputElement> standardEvents;
  final Map<String, OutputElement> customEvents;

  final ClassElement elementClass;

  final ClassElement htmlElementClass;

  /// In attributes, there can be multiple strings that point to the
  /// same [InputElement] generated from [alternativeInputs] (below).
  /// This will provide a static source of unique [InputElement]s.
  final Set<InputElement> uniqueAttributeElements;

  StandardHtml(this.components, this.attributes, this.standardEvents,
      this.customEvents, this.elementClass, this.htmlElementClass)
      : uniqueAttributeElements = new Set.from(attributes.values);

  Map<String, OutputElement> get events =>
      new Map<String, OutputElement>.from(standardEvents)..addAll(customEvents);
}

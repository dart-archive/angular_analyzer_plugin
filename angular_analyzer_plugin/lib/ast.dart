import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:meta/meta.dart';

abstract class AngularAstNode {
  List<AngularAstNode> get children;
  int get length;
  int get offset;

  void accept(AngularAstVisitor visitor);
}

abstract class AngularAstVisitor {
  void visitDocumentInfo(DocumentInfo document) {
    for (AngularAstNode child in document.childNodes) {
      child.accept(this);
    }
  }

  void visitElementInfo(ElementInfo elementInfo) =>
      _visitAllChildren(elementInfo);

  void visitEmptyStarBinding(EmptyStarBinding emptyBinding) =>
      visitTextAttr(emptyBinding);

  void visitExpressionBoundAttr(ExpressionBoundAttribute attr) =>
      _visitAllChildren(attr);

  void visitMustache(Mustache mustache) {}

  void visitStatementsBoundAttr(StatementsBoundAttribute attr) =>
      _visitAllChildren(attr);

  void visitTemplateAttr(TemplateAttribute attr) => _visitAllChildren(attr);

  void visitTextAttr(TextAttribute textAttr) => _visitAllChildren(textAttr);

  void visitTextInfo(TextInfo textInfo) => _visitAllChildren(textInfo);

  void _visitAllChildren(AngularAstNode node) {
    for (final child in node.children) {
      child.accept(this);
    }
  }
}

/// Information about an attribute.
abstract class AttributeInfo extends AngularAstNode {
  HasDirectives parent;

  final String name;
  final int nameOffset;

  final String value;
  final int valueOffset;

  final String originalName;
  final int originalNameOffset;

  AttributeInfo(this.name, this.nameOffset, this.value, this.valueOffset,
      this.originalName, this.originalNameOffset);

  @override
  int get length => valueOffset == null
      ? originalName.length
      : valueOffset + value.length - originalNameOffset;

  @override
  int get offset => originalNameOffset;

  int get valueLength => value != null ? value.length : 0;

  @override
  String toString() =>
      '([$name, $nameOffset], [$value, $valueOffset, $valueLength], '
      '[$originalName, $originalNameOffset])';
}

abstract class BoundAttributeInfo extends AttributeInfo {
  Map<String, LocalVariable> localVariables =
      new HashMap<String, LocalVariable>();

  BoundAttributeInfo(String name, int nameOffset, String value, int valueOffset,
      String originalName, int originalNameOffset)
      : super(name, nameOffset, value, valueOffset, originalName,
            originalNameOffset);

  @override
  List<AngularAstNode> get children => const <AngularAstNode>[];

  @override
  String toString() => '(${super.toString()}, [$children])';
}

/// Allows us to track ranges for navigating ContentChild(ren), and detect when
/// multiple ContentChilds are matched which is an error.

/// Naming here is important: "bound content child" != "content child binding."
class ContentChildBinding {
  final AbstractDirective directive;
  final ContentChild boundContentChild;
  final Set<ElementInfo> boundElements = new HashSet<ElementInfo>();
  // TODO: track bound attributes in #foo?

  ContentChildBinding(this.directive, this.boundContentChild);
}

/// A binding to an [AbstractDirective], either on an [ElementInfo] or a
/// [TemplateAttribute]. For each bound directive, there is a directive binding.
/// Has [InputBinding]s and [OutputBinding]s which themselves indicate an
/// [AttributeInfo] bound to an [InputElement] or [OutputElement] in the context
/// of this [DirectiveBinding].
///
/// Naming here is important: "bound directive" != "directive binding."
class DirectiveBinding {
  final AbstractDirective boundDirective;
  final inputBindings = <InputBinding>[];
  final outputBindings = <OutputBinding>[];
  final contentChildBindings = <ContentChild, ContentChildBinding>{};
  final contentChildrenBindings = <ContentChild, ContentChildBinding>{};

  DirectiveBinding(this.boundDirective);
}

/// A wrapper for a given HTML document or dart-angular inline HTML template.
class DocumentInfo extends ElementInfo {
  factory DocumentInfo() = DocumentInfo._;

  DocumentInfo._()
      : super(
          '',
          const SourceRange(0, 0),
          const SourceRange(0, 0),
          const SourceRange(0, 0),
          const SourceRange(0, 0),
          [],
          null,
          null,
          isTemplate: false,
        );

  @override
  List<AngularAstNode> get children => childNodes;

  @override
  bool get isSynthetic => false;

  @override
  void accept(AngularAstVisitor visitor) => visitor.visitDocumentInfo(this);
}

/// An element in an HTML tree.
class ElementInfo extends NodeInfo implements HasDirectives {
  final List<NodeInfo> childNodes = <NodeInfo>[];

  final String localName;
  final SourceRange openingSpan;
  final SourceRange closingSpan;
  final SourceRange openingNameSpan;
  final SourceRange closingNameSpan;
  final bool isTemplate;
  final List<AttributeInfo> attributes;
  final TemplateAttribute templateAttribute;
  final ElementInfo parent;

  @override
  final boundDirectives = <DirectiveBinding>[];
  @override
  final boundStandardOutputs = <OutputBinding>[];
  @override
  final boundStandardInputs = <InputBinding>[];
  @override
  final availableDirectives = <AbstractDirective, List<AngularElement>>{};

  int childNodesMaxEnd;

  bool tagMatchedAsTransclusion = false;
  bool tagMatchedAsDirective = false;
  bool tagMatchedAsImmediateContentChild = false;
  bool tagMatchedAsCustomTag = false;
  ElementInfo(
      this.localName,
      this.openingSpan,
      this.closingSpan,
      this.openingNameSpan,
      this.closingNameSpan,
      this.attributes,
      this.templateAttribute,
      this.parent,
      {@required this.isTemplate}) {
    if (!isSynthetic) {
      childNodesMaxEnd = offset + length;
    }
  }

  @override
  List<AngularAstNode> get children {
    final list = new List<AngularAstNode>.from(attributes);
    if (templateAttribute != null) {
      list.add(templateAttribute);
    }
    return list..addAll(childNodes);
  }

  List<AbstractDirective> get directives =>
      boundDirectives.map((bd) => bd.boundDirective).toList();
  bool get isOrHasTemplateAttribute => isTemplate || templateAttribute != null;

  @override
  bool get isSynthetic => openingSpan == null;

  @override
  int get length => (closingSpan != null)
      ? closingSpan.offset + closingSpan.length - openingSpan.offset
      : ((childNodesMaxEnd != null)
          ? childNodesMaxEnd - offset
          : openingSpan.length);

  @override
  int get offset => openingSpan.offset;

  bool get openingSpanIsClosed => isSynthetic
      ? false
      : (openingSpan.offset + openingSpan.length) ==
          (openingNameSpan.offset + openingNameSpan.length + ">".length);

  @override
  void accept(AngularAstVisitor visitor) => visitor.visitElementInfo(this);
}

/// `*ngFor` creates an empty text attribute, which is harmless. But so do the
/// less harmless cases of empty `*ngIf`, and or `*ngFor="let item of"`, etc.
class EmptyStarBinding extends TextAttribute {
  // is this an empty binding in the middle of the star, or is it the original
  // prefix binding which is usually harmless to be empty?
  bool isPrefix;

  EmptyStarBinding(
      String name, int nameOffset, String originalName, int originalNameOffset,
      {@required this.isPrefix})
      : super.synthetic(
            name, nameOffset, null, null, originalName, originalNameOffset, []);

  @override
  void accept(AngularAstVisitor visitor) => visitor.visitEmptyStarBinding(this);
}

class ExpressionBoundAttribute extends BoundAttributeInfo {
  Expression expression;
  final ExpressionBoundType bound;
  ExpressionBoundAttribute(
      String name,
      int nameOffset,
      String value,
      int valueOffset,
      String originalName,
      int originalNameOffset,
      this.expression,
      this.bound)
      : super(name, nameOffset, value, valueOffset, originalName,
            originalNameOffset);

  @override
  void accept(AngularAstVisitor visitor) =>
      visitor.visitExpressionBoundAttr(this);

  @override
  String toString() => '(${super.toString()}, [$bound, $expression])';
}

enum ExpressionBoundType { input, twoWay, attr, attrIf, clazz, style }

/// An AngularAstNode which has directives, such as [ElementInfo] and
/// [TemplateAttribute]. Contains an array of [DirectiveBinding]s because those
/// contain more info than just the bound directive.
abstract class HasDirectives extends AngularAstNode {
  Map<AbstractDirective, List<AngularElement>> get availableDirectives;
  List<DirectiveBinding> get boundDirectives;
  List<InputBinding> get boundStandardInputs;
  List<OutputBinding> get boundStandardOutputs;
}

/// A binding between an [AttributeInfo] and an [InputElement].  This is used in
/// the context of a [DirectiveBinding] because each instance of a bound
/// directive has different input bindings. Note that inputs can be bound via
/// bracket syntax (an [ExpressionBoundAttribute]), or via plain attribute syntax
/// (a [TextAttribute]).
///
/// Naming here is important: "bound input" != "input binding."
class InputBinding {
  final InputElement boundInput;
  final AttributeInfo attribute;

  InputBinding(this.boundInput, this.attribute);
}

/// A variable defined by a [AbstractDirective].
class LocalVariable extends AngularElementImpl {
  final LocalVariableElement dartVariable;

  LocalVariable(String name, int nameOffset, int nameLength, Source source,
      this.dartVariable)
      : super(name, nameOffset, nameLength, source);
}

class Mustache extends AngularAstNode {
  Expression expression;
  @override
  final int offset;
  @override
  final int length;
  final int exprBegin;
  final int exprEnd;

  Map<String, LocalVariable> localVariables =
      new HashMap<String, LocalVariable>();

  Mustache(
    this.offset,
    this.length,
    this.expression,
    this.exprBegin,
    this.exprEnd,
  );

  @override
  List<AngularAstNode> get children => const <AngularAstNode>[];

  @override
  void accept(AngularAstVisitor visitor) => visitor.visitMustache(this);
}

/// The HTML elements in the tree
abstract class NodeInfo extends AngularAstNode {
  bool get isSynthetic;
}

/// A binding between an [BoundAttributeInfo] and an [OutputElement]. This is
/// used in the context of a [DirectiveBinding] because each instance of a bound
/// directive has different output bindings.
///
/// Binds to an [BoundAttributeInfo] and not a [StatementsBoundAttribute] because
/// it might be a two-way binding, and thats the greatest common subtype of
/// statements bound and expression bound attributes.
///
/// Naming here is important: "bound output" != "output binding."
class OutputBinding {
  final OutputElement boundOutput;
  final BoundAttributeInfo attribute;

  OutputBinding(this.boundOutput, this.attribute);
}

class StatementsBoundAttribute extends BoundAttributeInfo {
  List<Statement> statements;

  /// Reductions as in `(keyup.ctrl.shift.space)`. Not currently analyzed.
  List<String> reductions;

  StatementsBoundAttribute(
      String name,
      int nameOffset,
      String value,
      int valueOffset,
      String originalName,
      int originalNameOffset,
      this.reductions,
      this.statements)
      : super(name, nameOffset, value, valueOffset, originalName,
            originalNameOffset);

  int get reductionsLength =>
      reductions.isEmpty ? null : '.'.length + reductions.join('.').length;

  int get reductionsOffset =>
      reductions.isEmpty ? null : nameOffset + name.length;
  @override
  void accept(AngularAstVisitor visitor) =>
      visitor.visitStatementsBoundAttr(this);

  @override
  String toString() => '(${super.toString()}, [$statements])';
}

class TemplateAttribute extends BoundAttributeInfo implements HasDirectives {
  final List<AttributeInfo> virtualAttributes;
  @override
  final boundDirectives = <DirectiveBinding>[];
  @override
  final boundStandardOutputs = <OutputBinding>[];
  @override
  final boundStandardInputs = <InputBinding>[];
  @override
  final availableDirectives = <AbstractDirective, List<AngularElement>>{};

  String prefix;

  TemplateAttribute(String name, int nameOffset, String value, int valueOffset,
      String originalName, int originalNameOffset, this.virtualAttributes,
      {this.prefix})
      : super(name, nameOffset, value, valueOffset, originalName,
            originalNameOffset);

  @override
  List<AngularAstNode> get children =>
      new List<AngularAstNode>.from(virtualAttributes);

  List<AbstractDirective> get directives =>
      boundDirectives.map((bd) => bd.boundDirective).toList();

  @override
  void accept(AngularAstVisitor visitor) => visitor.visitTemplateAttr(this);

  @override
  String toString() => '(${super.toString()}, [$virtualAttributes])';
}

class TextAttribute extends AttributeInfo {
  final List<Mustache> mustaches;
  final bool isReference;

  TextAttribute(String name, int nameOffset, String value, int valueOffset,
      this.mustaches)
      : isReference = name.startsWith('#'),
        super(name, nameOffset, value, valueOffset, name, nameOffset);

  TextAttribute.synthetic(
      String name,
      int nameOffset,
      String value,
      int valueOffset,
      String originalName,
      int originalNameOffset,
      this.mustaches)
      : isReference = name.startsWith('#'),
        super(name, nameOffset, value, valueOffset, originalName,
            originalNameOffset);

  @override
  List<AngularAstNode> get children => new List<AngularAstNode>.from(mustaches);

  @override
  void accept(AngularAstVisitor visitor) => visitor.visitTextAttr(this);
}

/// A text node in an HTML tree.
class TextInfo extends NodeInfo {
  final List<Mustache> mustaches;
  final ElementInfo parent;
  final String text;

  @override
  final int offset;
  final bool _isSynthetic;
  TextInfo(this.offset, this.text, this.parent, this.mustaches,
      {bool synthetic: false})
      : _isSynthetic = synthetic;

  @override
  List<AngularAstNode> get children => new List<AngularAstNode>.from(mustaches);

  @override
  bool get isSynthetic => _isSynthetic;

  @override
  int get length => text.length;

  @override
  void accept(AngularAstVisitor visitor) => visitor.visitTextInfo(this);
}

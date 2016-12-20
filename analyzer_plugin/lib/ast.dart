import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:analyzer/src/dart/element/element.dart';

enum ExpressionBoundType { input, twoWay, attr, clazz, style }

abstract class AngularAstNode {
  List<AngularAstNode> get children;
  int get offset;
  int get length;

  void accept(AngularAstVisitor visitor);
}

abstract class AngularAstVisitor {
  void visitMustache(Mustache mustache) {}

  void visitTextAttr(TextAttribute textAttr) => _visitAllChildren(textAttr);

  void visitTemplateAttr(TemplateAttribute attr) => _visitAllChildren(attr);

  void visitExpressionBoundAttr(ExpressionBoundAttribute attr) =>
      _visitAllChildren(attr);

  void visitStatementsBoundAttr(StatementsBoundAttribute attr) =>
      _visitAllChildren(attr);

  void visitTextInfo(TextInfo textInfo) => _visitAllChildren(textInfo);

  void visitElementInfo(ElementInfo elementInfo) =>
      _visitAllChildren(elementInfo);

  void _visitAllChildren(AngularAstNode node) {
    for (AngularAstNode child in node.children) {
      child.accept(this);
    }
  }
}

/**
 * Information about an attribute.
 */
abstract class AttributeInfo extends AngularAstNode {
  final String name;
  final int nameOffset;

  final String value;
  final int valueOffset;

  int get offset => nameOffset;
  int get length => valueOffset + value.length - nameOffset;

  AttributeInfo(this.name, this.nameOffset, this.value, this.valueOffset);

  int get valueLength => value != null ? value.length : 0;

  @override
  String toString() {
    return '([$name, $nameOffset], [$value, $valueOffset, $valueLength])';
  }
}

abstract class BoundAttributeInfo extends AttributeInfo {
  final String originalName;
  final int originalNameOffset;

  Map<String, LocalVariable> localVariables =
      new HashMap<String, LocalVariable>();

  BoundAttributeInfo(String name, int nameOffset, String value, int valueOffset,
      this.originalName, this.originalNameOffset)
      : super(name, nameOffset, value, valueOffset);

  List<AngularAstNode> get children => const <AngularAstNode>[];

  @override
  String toString() {
    return '(' + super.toString() + ', [$originalName, $originalNameOffset])';
  }
}

class TemplateAttribute extends BoundAttributeInfo {
  final List<AttributeInfo> virtualAttributes;
  List<AbstractDirective> directives = <AbstractDirective>[];

  TemplateAttribute(String name, int nameOffset, String value, int valueOffset,
      String originalName, int originalNameOffset, this.virtualAttributes)
      : super(name, nameOffset, value, valueOffset, originalName,
            originalNameOffset);

  List<AngularAstNode> get children =>
      new List<AngularAstNode>.from(virtualAttributes);

  @override
  String toString() {
    return '(' + super.toString() + ', [$virtualAttributes])';
  }

  void accept(AngularAstVisitor visitor) => visitor.visitTemplateAttr(this);
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
  String toString() {
    return '(' + super.toString() + ', [$bound, $expression])';
  }

  void accept(AngularAstVisitor visitor) =>
      visitor.visitExpressionBoundAttr(this);
}

class StatementsBoundAttribute extends BoundAttributeInfo {
  List<Statement> statements;
  StatementsBoundAttribute(
      String name,
      int nameOffset,
      String value,
      int valueOffset,
      String originalName,
      int originalNameOffset,
      this.statements)
      : super(name, nameOffset, value, valueOffset, originalName,
            originalNameOffset);

  @override
  String toString() {
    return '(' + super.toString() + ', [$statements])';
  }

  void accept(AngularAstVisitor visitor) =>
      visitor.visitStatementsBoundAttr(this);
}

class TextAttribute extends AttributeInfo {
  final List<Mustache> mustaches;
  List<AngularAstNode> get children => new List<AngularAstNode>.from(mustaches);

  TextAttribute(String name, int nameOffset, String value, int valueOffset,
      this.mustaches)
      : super(name, nameOffset, value, valueOffset);

  void accept(AngularAstVisitor visitor) => visitor.visitTextAttr(this);
}

class Mustache extends AngularAstNode {
  Expression expression;
  final int offset;
  final int length;

  Map<String, LocalVariable> localVariables =
      new HashMap<String, LocalVariable>();

  List<AngularAstNode> get children => const <AngularAstNode>[];

  Mustache(this.offset, this.length, this.expression);

  void accept(AngularAstVisitor visitor) => visitor.visitMustache(this);
}

/**
 * The HTML elements in the tree
 */
abstract class NodeInfo extends AngularAstNode {}

/**
 * A text node in an HTML tree.
 */
class TextInfo extends NodeInfo {
  final List<Mustache> mustaches;
  List<AngularAstNode> get children => new List<AngularAstNode>.from(mustaches);

  final String text;
  final int offset;

  TextInfo(this.offset, this.text, this.mustaches);

  int get length => offset + text.length;

  void accept(AngularAstVisitor visitor) => visitor.visitTextInfo(this);
}

/**
 * An element in an HTML tree.
 */
class ElementInfo extends NodeInfo {
  final List<NodeInfo> childNodes = <NodeInfo>[];

  final String localName;
  final SourceRange openingSpan;
  final SourceRange closingSpan;
  final SourceRange openingNameSpan;
  final SourceRange closingNameSpan;
  final bool isTemplate;
  final List<AttributeInfo> attributes;
  final TemplateAttribute templateAttribute;
  List<AbstractDirective> directives = <AbstractDirective>[];

  ElementInfo(
      this.localName,
      this.openingSpan,
      this.closingSpan,
      this.openingNameSpan,
      this.closingNameSpan,
      this.isTemplate,
      this.attributes,
      this.templateAttribute);

  int get offset => openingSpan.offset;
  int get length =>
      closingSpan.offset + closingSpan.length - openingSpan.offset;

  List<AngularAstNode> get children {
    var list = new List<AngularAstNode>.from(attributes);
    if (templateAttribute != null) {
      list.add(templateAttribute);
    }
    return list..addAll(childNodes);
  }

  bool get isOrHasTemplateAttribute => isTemplate || templateAttribute != null;

  void accept(AngularAstVisitor visitor) => visitor.visitElementInfo(this);
}

/**
 * A variable defined by a [AbstractDirective].
 */
class LocalVariable extends AngularElementImpl {
  final LocalVariableElementImpl dartVariable;

  LocalVariable(String name, int nameOffset, int nameLength, Source source,
      this.dartVariable)
      : super(name, nameOffset, nameLength, source);
}

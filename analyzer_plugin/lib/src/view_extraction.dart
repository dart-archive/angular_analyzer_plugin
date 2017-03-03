import 'dart:collection';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'tasks.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;
import 'package:angular_analyzer_plugin/src/angular_html_parser.dart';
import 'package:source_span/source_span.dart';
import 'package:analyzer/src/error/codes.dart';

class ViewExtractor extends AnnotationProcessorMixin {
  AnalysisContext context;
  Source source;
  ast.CompilationUnit unit;
  List<AbstractDirective> directivesDefinedInFile;

  ViewExtractor(
      this.unit, this.directivesDefinedInFile, this.context, this.source);

  List<View> getViews() {
    initAnnotationProcessor(source);
    //
    // Prepare inputs.
    //

    //
    // Process all classes.
    //
    List<View> views = <View>[];
    for (ast.CompilationUnitMember unitMember in unit.declarations) {
      if (unitMember is ast.ClassDeclaration) {
        ClassElement classElement = unitMember.element;
        ast.Annotation viewAnnotation;
        ast.Annotation componentAnnotation;

        for (ast.Annotation annotation in unitMember.metadata) {
          if (isAngularAnnotation(annotation, 'View')) {
            viewAnnotation = annotation;
          } else if (isAngularAnnotation(annotation, 'Component')) {
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
        }
      }
    }

    return views;
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
          getNamedArgument(annotation, 'templateUrl');
      definesTemplateUrl = templateUrlExpression != null;
      String templateUrl = getExpressionString(templateUrlExpression);
      if (templateUrl != null) {
        SourceFactory sourceFactory = context.sourceFactory;
        templateUriSource = sourceFactory.resolveUri(source, templateUrl);

        if (templateUriSource == null || !templateUriSource.exists()) {
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
      ast.Expression expression = getNamedArgument(annotation, 'template');
      if (expression != null) {
        templateOffset = expression.offset;
        definesTemplate = true;
        OffsettingConstantEvaluator constantEvaluation =
            calculateStringWithOffsets(expression);

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
    final directiveReferences = <DirectiveReference>[];
    findDirectives(annotation, directiveReferences);
    // Create View.
    return new View(classElement, component, <AbstractDirective>[],
        templateText: templateText,
        templateOffset: templateOffset,
        templateUriSource: templateUriSource,
        templateUrlRange: templateUrlRange,
        directiveReferences: directiveReferences,
        annotation: annotation);
  }

  Component _findComponentAnnotationOrReportError(ClassElement classElement) {
    for (AbstractDirective directive in directivesDefinedInFile) {
      if (directive is Component && directive.classElement == classElement) {
        return directive;
      }
    }
    errorReporter.reportErrorForElement(
        AngularWarningCode.COMPONENT_ANNOTATION_MISSING, classElement, []);
    return null;
  }

  void findDirectives(
      ast.Annotation annotation, List<DirectiveReference> directiveReferences) {
    // Prepare directives and elementTags
    ast.Expression listExpression = getNamedArgument(annotation, 'directives');
    if (listExpression is ast.ListLiteral) {
      for (ast.Expression item in listExpression.elements) {
        if (item is ast.Identifier) {
          var name = item.name;
          var prefix = "";
          if (item is ast.PrefixedIdentifier) {
            prefix = item.prefix.name;
          }
          Element element = item.staticElement;
          // LIST_OF_DIRECTIVES or TypeLiteral
          if (element is ClassElement ||
              element is PropertyAccessorElement &&
                  element.variable.constantValue != null) {
            directiveReferences.add(new DirectiveReference(
                name, prefix, new SourceRange(item.offset, item.length)));
            //DartObject value = element.variable.constantValue;
            //bool success = _addDirectivesAndElementTagsForDartObject(
            //    directiveReferences, value);
            //if (!success) {
            //  errorReporter.reportErrorForNode(
            //      AngularWarningCode.TYPE_LITERAL_EXPECTED, item);
            //  return null;
            //}
            continue;
          }
        }
        // unknown
        errorReporter.reportErrorForNode(
            AngularWarningCode.TYPE_LITERAL_EXPECTED, item);
      }
    }
  }
}

@deprecated
class ViewDirectiveLinker extends AnnotationProcessorMixin {
  List<AbstractDirective> _allDirectives;
  List<View> viewsToLink;
  Source source;

  ViewDirectiveLinker(this.viewsToLink, this._allDirectives, this.source);

  void linkDirectives() {
    initAnnotationProcessor(source);

    viewsToLink.forEach(findDirectives);
  }

  void findDirectives(View view) {
    // Prepare directives and elementTags
    ast.Expression listExpression =
        getNamedArgument(view.annotation, 'directives');
    if (listExpression is ast.ListLiteral) {
      for (ast.Expression item in listExpression.elements) {
        if (item is ast.Identifier) {
          Element element = item.staticElement;
          // TypeLiteral
          if (element is ClassElement) {
            _addDirectiveAndElementTagOrReportError(
                view.directives, view.elementTagsInfo, item, element);
            continue;
          }
          // LIST_OF_DIRECTIVES
          if (element is PropertyAccessorElement &&
              element.variable.constantValue != null) {
            DartObject value = element.variable.constantValue;
            bool success = _addDirectivesAndElementTagsForDartObject(
                view.directives, view.elementTagsInfo, value);
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

  /**
   * Attempt to find and add the [AbstractDirective] that corresponds to
   * the [classElement]. In addition, if Component, adds it to elementTags.
   * Returns `true` if at least directive is successfully added.
   */
  bool _addDirectiveAndElementTag(
      List<AbstractDirective> directives,
      Map<String, List<AbstractDirective>> elementTagsInfo,
      ClassElement classElement) {
    for (AbstractDirective directive in _allDirectives) {
      if (directive.classElement == classElement) {
        directives.add(directive);
        for (ElementNameSelector elementTag in directive.elementTags) {
          String elementTagName = elementTag.toString();
          if (!elementTagsInfo.containsKey(elementTagName)) {
            elementTagsInfo.putIfAbsent(
                elementTagName, () => new List<AbstractDirective>());
          }
          elementTagsInfo[elementTagName].add(directive);
        }
        return true;
      }
    }
    return false;
  }

  /**
   * Attempt to find and add the [AbstractDirective] and elementTag(if Component)
   * that corresponds to
   * the [classElement]. Return an error if the directive not found.
   */
  void _addDirectiveAndElementTagOrReportError(
      List<AbstractDirective> directives,
      Map<String, List<AbstractDirective>> elementTagsInfo,
      ast.Expression expression,
      ClassElement classElement) {
    bool success =
        _addDirectiveAndElementTag(directives, elementTagsInfo, classElement);
    if (!success) {
      errorReporter.reportErrorForNode(AngularWarningCode.TYPE_IS_NOT_DIRECTIVE,
          expression, [classElement.name]);
    }
  }

  /**
   * Walk the given [value] and add directives into [directives].
   * Return `true` if success, or `false` the [value] has items that don't
   * correspond to a directive.
   */
  bool _addDirectivesAndElementTagsForDartObject(
      List<AbstractDirective> directives,
      Map<String, List<AbstractDirective>> elementTagsInfo,
      DartObject value) {
    List<DartObject> listValue = value.toListValue();
    if (listValue != null) {
      for (DartObject listItem in listValue) {
        Object typeValue = listItem.toTypeValue();
        if (typeValue is InterfaceType) {
          bool success = _addDirectiveAndElementTag(
              directives, elementTagsInfo, typeValue.element);
          if (!success) {
            return false;
          }
        }
      }
      return true;
    }
    return false;
  }
}

class TemplateParser {
  html.Document document;
  final List<AnalysisError> parseErrors = <AnalysisError>[];

  void parse(String content, Source source, {int offset = 0}) {
    if (offset != null) {
      content = ' ' * offset + content;
    }
    AngularHtmlParser parser = new AngularHtmlParser(content,
        generateSpans: true, lowercaseAttrName: false);
    parser.compatMode = 'quirks';
    document = parser.parse();

    List<html.ParseError> htmlErrors = parser.errors;

    for (html.ParseError parseError in htmlErrors) {
      if (parseError.errorCode == 'expected-doctype-but-got-start-tag' ||
          parseError.errorCode == 'expected-doctype-but-got-chars' ||
          parseError.errorCode == 'expected-doctype-but-got-eof') {
        continue;
      }

      SourceSpan span = parseError.span;
      // html parser lib isn't nice enough to send this error all the time
      // see github #47 for dart-lang/html
      if (span == null) continue;

      this.parseErrors.add(new AnalysisError(source, span.start.offset,
          span.length, HtmlErrorCode.PARSE_ERROR, [parseError.errorCode]));
    }
  }
}

setIgnoredErrors(Template template, html.Document document) {
  if (document == null || document.nodes.length == 0) {
    return;
  }
  html.Node firstNode = document.nodes[0];
  if (firstNode is html.Comment) {
    String text = firstNode.text.trim();
    if (text.startsWith("@ngIgnoreErrors")) {
      text = text.substring("@ngIgnoreErrors".length);
      // Per spec: optional color
      if (text.startsWith(":")) {
        text = text.substring(1);
      }
      // Per spec: optional commas
      String delim = text.indexOf(',') == -1 ? ' ' : ',';
      template.ignoredErrors.addAll(new HashSet.from(
          text.split(delim).map((c) => c.trim().toUpperCase())));
    }
  }
}

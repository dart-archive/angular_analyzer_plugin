import 'dart:collection';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'tasks.dart';
import 'package:analyzer/error/error.dart';
import 'package:angular_ast/angular_ast.dart' as NgAst;

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

class TemplateParser {
  static const errorMap = const {
    NgAst.NgParserWarningCode.UNTERMINATED_MUSTACHE:
        AngularWarningCode.UNTERMINATED_MUSTACHE,
    NgAst.NgParserWarningCode.UNOPENED_MUSTACHE:
        AngularWarningCode.UNOPENED_MUSTACHE,
  };

  List<NgAst.TemplateAst> document;
  final List<AnalysisError> parseErrors = <AnalysisError>[];

  void parse(String content, Source source, {int offset = 0}) {
    if (offset != null) {
      content = ' ' * offset + content;
    }
    var exceptionHandler = new NgAst.RecoveringExceptionHandler();
    document = NgAst.parse(
      content,
      sourceUrl: source.toString(),
      desugar: false,
      parseExpressions: false,
      exceptionHandler: exceptionHandler,
    );

    for (NgAst.AngularParserException e in exceptionHandler.exceptions) {
      if (e.errorCode is NgAst.NgParserWarningCode) {
        this.parseErrors.add(new AnalysisError(
              source,
              e.offset,
              e.length,
              errorMap[e.errorCode] ?? e.errorCode,
            ));
      }
    }
  }
}

setIgnoredErrors(Template template, List<NgAst.TemplateAst> asts) {
  if (asts == null || asts.length == 0) {
    return;
  }
  for (NgAst.TemplateAst ast in asts) {
    if (ast is NgAst.TextAst && ast.value.trim().isEmpty) {
      continue;
    } else if (ast is NgAst.CommentAst) {
      String text = ast.value.trim();
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
    } else {
      return;
    }
  }
}

import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/errors.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';
import 'package:angular_ast/angular_ast.dart' as ng_ast;

import 'tasks.dart';

void setIgnoredErrors(Template template, List<ng_ast.TemplateAst> asts) {
  if (asts == null || asts.isEmpty) {
    return;
  }
  for (final ast in asts) {
    if (ast is ng_ast.TextAst && ast.value.trim().isEmpty) {
      continue;
    } else if (ast is ng_ast.CommentAst) {
      var text = ast.value.trim();
      if (text.startsWith("@ngIgnoreErrors")) {
        text = text.substring("@ngIgnoreErrors".length);
        // Per spec: optional color
        if (text.startsWith(":")) {
          text = text.substring(1);
        }
        // Per spec: optional commas
        final delim = !text.contains(',') ? ' ' : ',';
        template.ignoredErrors.addAll(new HashSet.from(
            text.split(delim).map((c) => c.trim().toUpperCase())));
      }
    } else {
      return;
    }
  }
}

class TemplateParser {
  //Todo(Max): remove errorMap after new ast implemented
  static const errorMap = const {
    ng_ast.NgParserWarningCode.UNTERMINATED_MUSTACHE:
        AngularWarningCode.UNTERMINATED_MUSTACHE,
    ng_ast.NgParserWarningCode.UNOPENED_MUSTACHE:
        AngularWarningCode.UNOPENED_MUSTACHE,
  };

  List<ng_ast.StandaloneTemplateAst> rawAst;
  final parseErrors = <AnalysisError>[];

  void parse(String content, Source source, {int offset = 0}) {
    if (offset != null) {
      // ignore: prefer_interpolation_to_compose_strings, parameter_assignments
      content = ' ' * offset + content;
    }
    final exceptionHandler = new ng_ast.RecoveringExceptionHandler();
    rawAst = ng_ast.parse(
      content,
      sourceUrl: source.uri.toString(),
      desugar: false,
      parseExpressions: false,
      exceptionHandler: exceptionHandler,
    ) as List<ng_ast.StandaloneTemplateAst>;

    for (final e in exceptionHandler.exceptions) {
      if (e.errorCode is ng_ast.NgParserWarningCode) {
        parseErrors.add(new AnalysisError(
          source,
          e.offset,
          e.length,
          errorMap[e.errorCode] ?? e.errorCode,
        ));
      }
    }
  }
}

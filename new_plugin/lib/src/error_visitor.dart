// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:angular_analysis_plugin/src/error_code.dart';

class AngularErrorVisitor extends RecursiveAstVisitor {
  final ErrorReporter reporter;

  AngularErrorVisitor(this.reporter);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (_hasAnnotation(node)) {
      reporter.reportErrorForNode(
          AngularErrorCode.INVALID_USE_OF_ANNOTATION, node.name);
    }
  }

  bool _hasAnnotation(AnnotatedNode node) {
    for (Annotation annotation in node.metadata) {
      if (annotation.name.name == 'annotation') {
        return true;
      }
    }
    return false;
  }
}

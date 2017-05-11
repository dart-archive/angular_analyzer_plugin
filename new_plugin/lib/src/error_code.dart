// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:front_end/src/base/errors.dart';

class AngularErrorCode extends ErrorCode {
  static final AngularErrorCode INVALID_USE_OF_ANNOTATION =
      new AngularErrorCode(
          'INVALID_USE_OF_ANNOTATION', 'Annotation cannot be used on classes');

  AngularErrorCode(String name, String message, [String correction])
      : super(name, message, correction);

  @override
  ErrorSeverity get errorSeverity => ErrorSeverity.WARNING;

  @override
  ErrorType get type => ErrorType.HINT;
}

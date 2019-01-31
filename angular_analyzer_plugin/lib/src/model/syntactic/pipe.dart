import 'package:analyzer/src/generated/source.dart' show Source;
import 'package:angular_analyzer_plugin/src/model/syntactic/element.dart';

/// The syntactic model of a pipe declaration.
///
/// ```dart
/// @Pipe('name', isPure: true)
/// class MyPipe {
///   Type transform(...) => ...;
/// }
/// ```
///
/// By tracking the class name and source, we can resolve the annotation's
/// computed constant value to see the state of `isPure`, and find the transform
/// method, which may be inherited.
///
/// Extends [AngularElementImpl] because it is navigable (Navigate to name).
class Pipe extends AngularElementImpl {
  final String pipeName;
  final String className;

  Pipe(String pipeName, int pipeNameOffset, this.className, Source source)
      : pipeName = pipeName,
        super(pipeName, pipeNameOffset, pipeName.length, source);
}

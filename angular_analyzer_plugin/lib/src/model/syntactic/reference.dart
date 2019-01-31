/// References are very weak in the syntactic stage. At link time, what's
/// referenced by one prefix or identifier may change. In practice, most all
/// references are essentially the same class, however, const lists have some
/// special treatment. We also split up [Pipe], [Directive], and [Export]
/// references into different classes so that they can be treated as different
/// concepts by the type system even though they are structurally equivalent
import 'dart:core' hide List;
import 'dart:core' as core show List;

import 'package:analyzer/src/generated/source.dart' show SourceRange;

/// A reference to a directive.
class Directive extends _Reference {
  Directive(String name, String prefix, SourceRange range)
      : super(name, prefix, range);
}

/// A reference to an export.
class Export extends _Reference {
  Export(String name, String prefix, SourceRange range)
      : super(name, prefix, range);
}

/// A const list identifier reference of some inner type [T]. Due to the way
/// Dart implements annotations, anything meant to be a list literal could be
/// given a simple variable. It makes error reporting less clean, but we can
/// handle it. Track the [SourceRange] for what little reporting we can do.
///
/// ```dart
///   foo
/// ```
class FromConstIdentifier<T extends _Reference> implements List<T> {
  final SourceRange sourceRange;

  FromConstIdentifier(this.sourceRange);
}

/// A const list literal reference of some inner type [T]:
///
/// ```dart
///   [A, B, C, ...]
/// ```
///
/// By tracking each identifier individually, we can give better error reporting
/// than [FromConstIdentifier].
class FromConstLiteral<T extends _Reference> implements List<T> {
  final core.List<T> references;

  FromConstLiteral(this.references);
}

/// A list reference of some inner type [T]. Implemented by [FromConstLiteral]
/// or [FromConstIdentifier], because either is valid.
abstract class List<T extends _Reference> {}

/// A reference to a pipe.
class Pipe extends _Reference {
  Pipe(String name, String prefix, SourceRange range)
      : super(name, prefix, range);
}

/// A referenced identifier. We must know its name and prefix to be able to
/// locate it at link time. Track a [SourceRange] for error reporting reasons.
///
/// This is private, users should use [Pipe], [Directive], or [Export]. That
/// gives some type safety that a reference to one can't be accidentally used
/// as a reference to another.
class _Reference {
  String name;
  String prefix;
  SourceRange range;

  _Reference(this.name, this.prefix, this.range);
}

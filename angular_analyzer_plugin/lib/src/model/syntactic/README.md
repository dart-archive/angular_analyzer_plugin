# Syntactic Model

The syntactic model can be thought of as the AST of angular declarations (as
opposed to templates). Since that is defined in Dart, the meaning can quickly
change semantically, and it contains a lot of information that's unnecessary to
angular analysis itself (such as method bodies).

As such, it does not contain any actual type information, but only references
to names that can be resolved against the Dart element model. It should be
primarily strings and source ranges.

## Performance

This is largely an optimization. The syntactic model is summarizable; we can
store it and reload it from a flatbuffer file. That is much faster than
reparsing every dart file and walking it.

Any time any dart file is changed, it can have cascading semantic effects on
other dart files:

`a.dart`
```dart
@Component(...)
class A {
  ...
}
```

`b.dart`
```dart
import 'a.dart';
@Component(
  ...
  directives: [A],
  ...
)
class ...
```

Here, if class `A` is renamed to `ComponentA`, moved to a different file,
removed, etc, then `b.dart` should produce new errors. This means we need to
re-resolve every dart file[1], which is O(n), so that parse time adds up very
quickly. We also cannot rely on resolved ASTs to do analysis because that is
the slowest operation the dart analyzer can perform.

For this reason, the syntactic model should not contain any information or be
built based on any information that can change in this way. That means no
references to any types or elements from the dart analyzer library.

Ideally, the syntactic model would be able to be built completely based on an
unresolved Dart AST, however, we currently require a resolved AST in order to,
for instance, identify @Component declarations. This makes first ever run of a
project slower, and slightly slows iterative analysis, so there's room for
improvement here.

## References (in `reference.dart`)

A particular subtlety that's important is that there are two classes named
`Directive` in the syntactic model. One is where a directive is declared,
defined in `directive.dart`, and another in `reference.dart` representing where
a directive is referenced:

```dart
@Directive(
  ...
)
class MyDirective { // this is a Directive
  ...
}

@Component(
  ...
  directives: [ MyDirective ] // this is a directive reference
  ...
)
class MyComponent { ...
  ...
}
```

Most other code shouldn't have to really worry about this distinction, if you
just import `directive.dart` it will do the right thing. On the off chance you
need to distinguish, a good approach is to
`import 'reference.dart' as reference_to` so that you can use the types
`Directive` and `reference_to.Directive`.

There are also `pipe.dart`'s `Pipe`, and `reference.dart` has a definition of
`Pipe`, and a `Export` references, which are references to dart terms and so
there's no corresponding angular declaration.

References also have an interesting quirk in that they may at times be list
literals, ie, `directives: [A, B, C]`, or they may be some other arbitrary
expression (normally a simple identifier `foo`). The latter can only be built
out of the element model itself, and contains no offset information that we can
use to present good errors. The former can be specializated to track the
individual items in the list in order to have better errors for them. This is
defined as `List<T extends _Reference>` in `reference.dart` and has two
implementations: `FromConstExpression` and `FromConstLiteral`.

[1] Currently the analyzer does not expose a means of hooking into its
FileTracker which would allow us to only reanalyze downstream files. However,
the downstream files may be all other project files, so the worst case is still
O(n).

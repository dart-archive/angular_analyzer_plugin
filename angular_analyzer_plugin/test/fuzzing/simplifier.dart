import 'dart:async';

final whitespace = new Set<String>()..addAll([' ', '\t', '\n']);

/// A class which will, based on a [tryFn] and a [String] starting state, remove
/// all characters that are not required to get the [tryFn] to return true.
///
/// This is used to clean up ugly fuzz results -- ie,
///
/// ```
///   <h1 #h1>Showing {{items.}
///   ]),
///     <form #ngForm="ngForm"></form>
///     {{ngForm.di^rty}}
///     <input [(ngModel)]="hdynamiceader" />
///     <my-counter
///       <my-counter></my-counter>
///     </my-counter>
///   </div>
/// ```
///
/// becomes
///
/// ```
/// {{n.^
/// ```
///
/// Note that this algorithm is so simple, it creates syntax errors where they
/// are not the original problem. It is not obvious how to prevent this since we
/// are fundamentally dealing with code that crashes, so things like using
/// parser error recovery to fill in missing tokens may not work.
class StringSimplifier {
  /// The current state of the simplification process.
  String currentState;

  /// A function which should return [true] for any valid simpler [String] that
  /// is tried.
  Future<bool> Function(String) tryFn;

  /// Whether any characters were successfully removed.
  bool wasSimplified = false;

  StringSimplifier(this.currentState, this.tryFn);

  /// Simplify the string and modify properties about how everything went.
  Future<void> run() async {
    var wasWhitespace = false;
    for (var i = currentState.length - 1; i >= 0; --i) {
      // TODO(mfairhurst) abstract this check to autocompletion only.
      if (currentState[i] == '^') {
        continue;
      }

      if (whitespace.contains(currentState[i])) {
        if (!wasWhitespace) {
          wasWhitespace = true;
          // Don't strip out a single piece of whitespace by itelf.
          continue;
        }
      } else {
        wasWhitespace = false;
      }

      final tryState = currentState.replaceRange(i, i + 1, '');
      if ((await tryFn(tryState))) {
        currentState = tryState;
        wasSimplified = true;
      }
    }
  }
}

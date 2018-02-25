import 'dart:math';
import 'package:analyzer/dart/ast/token.dart';

import 'case.dart';
import 'values.dart';

typedef String FuzzModification(String input);

const _seedMax = 4294967296;

class FuzzCaseProducer {
  /// Unfortunately, the class [Random] does not allow access to the internal
  /// state. To be able to reproduce fuzz cases, we must seed every case with a
  /// custom number -- it can begin as a random seed, and increment from there.
  int seed;

  /// This is set once per iteration since we can seed it, but cannot get its
  /// state after it has been used.
  Random random;

  List<FuzzModification> fuzzOptions;

  // Generate a random initial seed using a *different* instance of [Random].
  FuzzCaseProducer() : this.withSeed(new Random().nextInt(_seedMax));

  FuzzCaseProducer.withSeed(this.seed) {
    fuzzOptions = <FuzzModification>[
      removeChar,
      truncate,
      addChar,
      copyLine,
      dropLine,
      joinLine,
      shuffleLines,
      copyChunk,
      addKeyword,
      addDartChunk,
      addHtmlChunk,
    ];
  }

  FuzzCase get nextCase {
    final saveSeed = seed;
    random = new Random(seed++);
    final transforms = random.nextInt(20) + 1;
    var dart = baseDart;
    var html = baseHtml;

    for (var x = 0; x < transforms; ++x) {
      if (random.nextBool()) {
        dart = fuzzOptions[random.nextInt(fuzzOptions.length)](dart);
      } else {
        html = fuzzOptions[random.nextInt(fuzzOptions.length)](html);
      }
    }

    return new FuzzCase(saveSeed, transforms, dart, html);
  }

  int randomPos(String s) {
    if (s.isEmpty) {
      return 0;
    }
    // range is between 1 and n, but a random pos is 0 to n
    return random.nextInt(s.length);
  }

  int randomIndex(List s) {
    if (s.isEmpty) {
      return null;
    } else if (s.length == 1) {
      return 0;
    }
    // range is between 1 and n, but a random pos is 0 to n
    return random.nextInt(s.length - 1);
  }

  String removeChar(String input) {
    final charpos = randomIndex(input.codeUnits);
    if (charpos == null) {
      return input;
    }
    return input.replaceRange(charpos, charpos + 1, '');
  }

  String addChar(String input) {
    String newchar;
    if (input.isEmpty) {
      newchar = new String.fromCharCode(random.nextInt(128));
    } else {
      newchar = input[randomIndex(input.codeUnits)];
    }
    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, newchar);
  }

  String truncate(String input) {
    final charpos = randomPos(input);
    if (charpos == 0) {
      return '';
    }
    return input.substring(0, charpos);
  }

  String shuffleLines(String input) {
    final lines = input.split('\n')..shuffle(random);
    return lines.join('\n');
  }

  String dropLine(String input) {
    final lines = input.split('\n');
    lines.removeAt(randomIndex(lines)); // ignore: cascade_invocations
    return lines.join('\n');
  }

  String joinLine(String input) {
    final lines = input.split('\n');
    if (lines.length == 1) {
      return input;
    }
    final which = randomIndex(lines);
    final toPrepend = lines[which];
    lines.removeAt(which);
    // ignore: prefer_interpolation_to_compose_strings
    lines[which] = toPrepend + lines[which];
    return lines.join('\n');
  }

  String copyLine(String input) {
    final lines = input.split('\n');
    if (lines.length == 1) {
      return input;
    }
    final which = randomIndex(lines);
    final toPrepend = lines[which];
    lines.removeAt(which);
    // ignore: prefer_interpolation_to_compose_strings
    lines[which] = toPrepend + lines[which];
    return lines.join('\n');
  }

  String copyChunk(String input) {
    if (input.isEmpty) {
      return input;
    }

    final chunk = truncate(input.substring(randomIndex(input.codeUnits)));
    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, chunk);
  }

  String addKeyword(String input) {
    final token = Keyword.values[randomIndex(Keyword.values)];
    if (input.isEmpty) {
      return input;
    }

    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, token.lexeme);
  }

  String addDartChunk(String input) {
    var chunk = truncate(dartSnippets);
    if (chunk.length > 80) {
      chunk = chunk.substring(0, random.nextInt(80));
    } else if (chunk.isEmpty) {
      return input;
    } else {
      chunk = chunk.substring(randomPos(chunk));
    }
    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, chunk);
  }

  String addHtmlChunk(String input) {
    var chunk = truncate(htmlSnippets);
    if (chunk.length > 80) {
      chunk = chunk.substring(0, random.nextInt(80));
    } else if (chunk.isEmpty) {
      return input;
    } else {
      chunk = chunk.substring(randomPos(chunk));
    }
    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, chunk);
  }
}

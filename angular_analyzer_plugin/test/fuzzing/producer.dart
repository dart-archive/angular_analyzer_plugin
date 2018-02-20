import 'dart:math';
import 'package:analyzer/dart/ast/token.dart';

import 'case.dart';
import 'values.dart';

typedef String FuzzModification(String input);

class FuzzCaseProducer {
  final Random random = new Random();

  List<FuzzModification> fuzzOptions;

  FuzzCaseProducer() {
    fuzzOptions = <FuzzModification>[
      fuzz_removeChar,
      fuzz_truncate,
      fuzz_addChar,
      fuzz_copyLine,
      fuzz_dropLine,
      fuzz_joinLine,
      fuzz_shuffleLines,
      fuzz_copyChunk,
      fuzz_addKeyword,
      fuzz_addDartChunk,
      fuzz_addHtmlChunk,
    ];
  }

  FuzzCase get nextCase {
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

    return new FuzzCase(transforms, dart, html);
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

// ignore: non_constant_identifier_names
  String fuzz_removeChar(String input) {
    final charpos = randomIndex(input.codeUnits);
    if (charpos == null) {
      return input;
    }
    return input.replaceRange(charpos, charpos + 1, '');
  }

// ignore: non_constant_identifier_names
  String fuzz_addChar(String input) {
    String newchar;
    if (input.isEmpty) {
      newchar = new String.fromCharCode(random.nextInt(128));
    } else {
      newchar = input[randomIndex(input.codeUnits)];
    }
    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, newchar);
  }

// ignore: non_constant_identifier_names
  String fuzz_truncate(String input) {
    final charpos = randomPos(input);
    if (charpos == 0) {
      return '';
    }
    return input.substring(0, charpos);
  }

// ignore: non_constant_identifier_names
  String fuzz_shuffleLines(String input) {
    final lines = input.split('\n')..shuffle(random);
    return lines.join('\n');
  }

// ignore: non_constant_identifier_names
  String fuzz_dropLine(String input) {
    final lines = input.split('\n');
    lines.removeAt(randomIndex(lines)); // ignore: cascade_invocations
    return lines.join('\n');
  }

// ignore: non_constant_identifier_names
  String fuzz_joinLine(String input) {
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

// ignore: non_constant_identifier_names
  String fuzz_copyLine(String input) {
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

// ignore: non_constant_identifier_names
  String fuzz_copyChunk(String input) {
    if (input.isEmpty) {
      return input;
    }

    final chunk = fuzz_truncate(input.substring(randomIndex(input.codeUnits)));
    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, chunk);
  }

// ignore: non_constant_identifier_names
  String fuzz_addKeyword(String input) {
    final token = Keyword.values[randomIndex(Keyword.values)];
    if (input.isEmpty) {
      return input;
    }

    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, token.lexeme);
  }

// ignore: non_constant_identifier_names
  String fuzz_addDartChunk(String input) {
    var chunk = fuzz_truncate(dartSnippets);
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

// ignore: non_constant_identifier_names
  String fuzz_addHtmlChunk(String input) {
    var chunk = fuzz_truncate(htmlSnippets);
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

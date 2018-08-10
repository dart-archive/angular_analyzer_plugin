import 'dart:math';

/// "$"
const CHAR_DOLLAR = 0x24;

/// "."
const CHAR_DOT = 0x2E;

/// "_"
const CHAR_UNDERSCORE = 0x5F;

String capitalize(String str) {
  if (isEmpty(str)) {
    return str;
  }
  // ignore: prefer_interpolation_to_compose_strings
  return str.substring(0, 1).toUpperCase() + str.substring(1);
}

int compareStrings(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  return a.compareTo(b);
}

/// Counts how many times [sub] appears in [str].
int countMatches(String str, String sub) {
  if (isEmpty(str) || isEmpty(sub)) {
    return 0;
  }
  var count = 0;
  var idx = 0;
  // ignore: prefer_contains
  while ((idx = str.indexOf(sub, idx)) != -1) {
    count++;
    idx += sub.length;
  }
  return count;
}

String decapitalize(String str) {
  if (isEmpty(str)) {
    return str;
  }
  // ignore: prefer_interpolation_to_compose_strings
  return str.substring(0, 1).toLowerCase() + str.substring(1);
}

/// Returns the number of characters common to the end of [a] and the start
/// of [b].
int findCommonOverlap(String _a, String _b) {
  var a = _a;
  var b = _b;
  final aLength = a.length;
  final bLength = b.length;
  // all empty
  if (aLength == 0 || bLength == 0) {
    return 0;
  }
  // truncate
  if (aLength > bLength) {
    a = a.substring(aLength - bLength);
  } else if (aLength < bLength) {
    b = b.substring(0, aLength);
  }
  final textLength = min(aLength, bLength);
  // the worst case
  if (a == b) {
    return textLength;
  }
  // increase common length one by one
  var length = 0;
  while (length < textLength) {
    if (a.codeUnitAt(textLength - 1 - length) != b.codeUnitAt(length)) {
      break;
    }
    length++;
  }
  return length;
}

/// Return the number of characters common to the start of [a] and [b].
int findCommonPrefix(String a, String b) {
  final n = min(a.length, b.length);
  for (var i = 0; i < n; i++) {
    if (a.codeUnitAt(i) != b.codeUnitAt(i)) {
      return i;
    }
  }
  return n;
}

/// Return the number of characters common to the end of [a] and [b].
int findCommonSuffix(String a, String b) {
  final aLength = a.length;
  final bLength = b.length;
  final n = min(aLength, bLength);
  for (var i = 1; i <= n; i++) {
    if (a.codeUnitAt(aLength - i) != b.codeUnitAt(bLength - i)) {
      return i - 1;
    }
  }
  return n;
}

/// Returns a list of words for the given camel case string.
///
/// 'getCamelWords' => ['get', 'Camel', 'Words']
/// 'getHTMLText' => ['get', 'HTML', 'Text']
List<String> getCamelWords(String str) {
  if (str == null || str.isEmpty) {
    return <String>[];
  }
  final parts = <String>[];
  var wasLowerCase = false;
  var wasUpperCase = false;
  var wordStart = 0;
  for (var i = 0; i < str.length; i++) {
    final c = str.codeUnitAt(i);
    final newLowerCase = isLowerCase(c);
    final newUpperCase = isUpperCase(c);
    // myWord
    // | ^
    if (wasLowerCase && newUpperCase) {
      parts.add(str.substring(wordStart, i));
      wordStart = i;
    }
    // myHTMLText
    //   |   ^
    if (wasUpperCase &&
        newUpperCase &&
        i + 1 < str.length &&
        isLowerCase(str.codeUnitAt(i + 1))) {
      parts.add(str.substring(wordStart, i));
      wordStart = i;
    }
    wasLowerCase = newLowerCase;
    wasUpperCase = newUpperCase;
  }
  parts.add(str.substring(wordStart));
  return parts;
}

/// Checks if [str] is `null`, empty or is whitespace.
bool isBlank(String str) {
  if (str == null) {
    return true;
  }
  if (str.isEmpty) {
    return true;
  }
  return str.codeUnits.every(isSpace);
}

bool isDigit(int c) => c >= 0x30 && c <= 0x39;

bool isEmpty(String str) => str == null || str.isEmpty;

bool isLetter(int c) => (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

bool isLetterOrDigit(int c) => isLetter(c) || isDigit(c);

bool isLowerCase(int c) => c >= 0x61 && c <= 0x7A;

bool isSpace(int c) => c == 0x20 || c == 0x09;

bool isUpperCase(int c) => c >= 0x41 && c <= 0x5A;

bool isWhitespace(int c) => isSpace(c) || c == 0x0D || c == 0x0A;

String remove(String str, String remove) {
  if (isEmpty(str) || isEmpty(remove)) {
    return str;
  }
  return str.replaceAll(remove, '');
}

String removeEnd(String str, String remove) {
  if (isEmpty(str) || isEmpty(remove)) {
    return str;
  }
  if (str.endsWith(remove)) {
    return str.substring(0, str.length - remove.length);
  }
  return str;
}

String removeStart(String str, String remove) {
  if (isEmpty(str) || isEmpty(remove)) {
    return str;
  }
  if (str.startsWith(remove)) {
    return str.substring(remove.length);
  }
  return str;
}

String repeat(String s, int n) {
  final sb = new StringBuffer();
  for (var i = 0; i < n; i++) {
    sb.write(s);
  }
  return sb.toString();
}

/// Gets the substring after the last occurrence of a separator.
/// The separator is not returned.
String substringAfterLast(String str, String separator) {
  if (isEmpty(str)) {
    return str;
  }
  if (isEmpty(separator)) {
    return '';
  }
  final pos = str.lastIndexOf(separator);
  if (pos == -1) {
    return str;
  }
  return str.substring(pos + separator.length);
}

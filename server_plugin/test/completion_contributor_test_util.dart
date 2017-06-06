// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.services.completion.dart.util;

import 'dart:async';

import 'package:analyzer_plugin/protocol/protocol_common.dart' as protocol
    show ElementKind;
import 'package:analyzer_plugin/protocol/protocol_common.dart'
    hide Element, ElementKind;
import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_dart.dart';
import 'package:analysis_server/src/services/completion/completion_core.dart';
import 'package:analysis_server/src/services/completion/completion_performance.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:unittest/unittest.dart';

import 'analysis_test.dart';

int suggestionComparator(CompletionSuggestion s1, CompletionSuggestion s2) {
  final c1 = s1.completion.toLowerCase();
  final c2 = s2.completion.toLowerCase();
  return c1.compareTo(c2);
}

abstract class AbstractCompletionContributorTest
    extends BaseCompletionContributorTest {
  CompletionContributor contributor;
  CompletionRequest request;

  @override
  void setUp() {
    super.setUp();
    contributor = createContributor();
  }

  CompletionContributor createContributor();

  @override
  Future computeSuggestions([int times = 200]) async {
    final request = new CompletionRequestImpl(
      null,
      null,
      testSource,
      completionOffset,
      new CompletionPerformance(),
    );

    // Request completions
    suggestions = await contributor.computeSuggestions(request);
    replacementOffset = request.replacementOffset;
    replacementLength = request.replacementLength;
    expect(suggestions, isNotNull, reason: 'expected suggestions');
  }

  /// Compute all the views declared in the given [dartSource], and resolve the
  /// external template of all the views.
  Future resolveSingleTemplate(Source dartSource) async {
    final result = await angularDriver.resolveDart(dartSource.fullName);
    for (var d in result.directives) {
      if (d is Component && d.view.templateUriSource != null) {
        final htmlPath = d.view.templateUriSource.fullName;
        await angularDriver.resolveHtml(htmlPath);
      }
    }
  }
}

abstract class BaseCompletionContributorTest extends AbstractAngularTest {
  String testFile;
  Source testSource;
  int completionOffset;
  int replacementOffset;
  int replacementLength;
  List<CompletionSuggestion> suggestions;

  /// If `true` and `null` is specified as the suggestion's expected returnType
  /// then the actual suggestion is expected to have a `dynamic` returnType.
  /// Newer tests return `false` so that they can distinguish between
  /// `dynamic` and `null`.
  /// Eventually all tests should be converted and this getter removed.
  bool get isNullExpectedReturnTypeConsideredDynamic => true;

  void addTestSource(String content) {
    expect(completionOffset, isNull, reason: 'Call addTestUnit exactly once');
    completionOffset = content.indexOf('^');
    expect(completionOffset, isNot(equals(-1)), reason: 'missing ^');
    final nextOffset = content.indexOf('^', completionOffset + 1);
    expect(nextOffset, equals(-1), reason: 'too many ^');
    // ignore: parameter_assignments, prefer_interpolation_to_compose_strings
    content = content.substring(0, completionOffset) +
        content.substring(completionOffset + 1);
    testSource = newSource(testFile, content);
  }

  void assertHasNoParameterInfo(final suggestion) {
    expect(suggestion.parameterNames, isNull);
    expect(suggestion.parameterTypes, isNull);
    expect(suggestion.requiredParameterCount, isNull);
    expect(suggestion.hasNamedParameters, isNull);
  }

  void assertHasParameterInfo(final suggestion) {
    expect(suggestion.parameterNames, isNotNull);
    expect(suggestion.parameterTypes, isNotNull);
    expect(suggestion.parameterNames.length, suggestion.parameterTypes.length);
    expect(suggestion.requiredParameterCount,
        lessThanOrEqualTo(suggestion.parameterNames.length));
    expect(suggestion.hasNamedParameters, isNotNull);
  }

  void assertNoSuggestions({CompletionSuggestionKind kind: null}) {
    if (kind == null) {
      if (suggestions.isNotEmpty) {
        failedCompletion('Expected no suggestions', suggestions);
      }
      return;
    }
    final suggestion = suggestions.firstWhere((final cs) => cs.kind == kind,
        orElse: () => null);
    if (suggestion != null) {
      failedCompletion('did not expect completion: $completion\n  $suggestion');
    }
  }

  void assertNotSuggested(String completion) {
    final suggestion = suggestions.firstWhere(
        (final cs) => cs.completion == completion,
        orElse: () => null);
    if (suggestion != null) {
      failedCompletion('did not expect completion: $completion\n  $suggestion');
    }
  }

  CompletionSuggestion assertSuggest(String completion,
      {CompletionSuggestionKind csKind: CompletionSuggestionKind.INVOCATION,
      int relevance: DART_RELEVANCE_DEFAULT,
      String importUri,
      protocol.ElementKind elemKind: null,
      bool isDeprecated: false,
      bool isPotential: false,
      String elemFile,
      int elemOffset,
      final paramName,
      final paramType}) {
    final cs =
        getSuggest(completion: completion, csKind: csKind, elemKind: elemKind);
    if (cs == null) {
      failedCompletion('expected $completion $csKind $elemKind', suggestions);
    }
    expect(cs.kind, equals(csKind));
    if (isDeprecated) {
      expect(cs.relevance, equals(DART_RELEVANCE_LOW));
    } else {
      expect(cs.relevance, equals(relevance), reason: completion);
    }
    expect(cs.importUri, importUri);
    expect(cs.selectionOffset, equals(completion.length));
    expect(cs.selectionLength, equals(0));
    expect(cs.isDeprecated, equals(isDeprecated));
    expect(cs.isPotential, equals(isPotential));
    if (cs.element != null) {
      expect(cs.element.location, isNotNull);
      expect(cs.element.location.file, isNotNull);
      expect(cs.element.location.offset, isNotNull);
      expect(cs.element.location.length, isNotNull);
      expect(cs.element.location.startColumn, isNotNull);
      expect(cs.element.location.startLine, isNotNull);
    }
    if (elemFile != null) {
      expect(cs.element.location.file, elemFile);
    }
    if (elemOffset != null) {
      expect(cs.element.location.offset, elemOffset);
    }
    if (paramName != null) {
      expect(cs.parameterName, paramName);
    }
    if (paramType != null) {
      expect(cs.parameterType, paramType);
    }
    return cs;
  }

  CompletionSuggestion assertSuggestClass(String name,
      {int relevance: DART_RELEVANCE_DEFAULT,
      String importUri,
      CompletionSuggestionKind kind: CompletionSuggestionKind.INVOCATION,
      bool isDeprecated: false,
      String elemFile,
      String elemName,
      int elemOffset}) {
    final cs = assertSuggest(name,
        csKind: kind,
        relevance: relevance,
        importUri: importUri,
        isDeprecated: isDeprecated,
        elemFile: elemFile,
        elemOffset: elemOffset);
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.CLASS));
    expect(element.name, equals(elemName ?? name));
    expect(element.parameters, isNull);
    expect(element.returnType, isNull);
    assertHasNoParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestClassTypeAlias(String name,
      {int relevance: DART_RELEVANCE_DEFAULT,
      CompletionSuggestionKind kind: CompletionSuggestionKind.INVOCATION}) {
    final cs = assertSuggest(name, csKind: kind, relevance: relevance);
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.CLASS_TYPE_ALIAS));
    expect(element.name, equals(name));
    expect(element.parameters, isNull);
    expect(element.returnType, isNull);
    assertHasNoParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestConstructor(String name,
      {int relevance: DART_RELEVANCE_DEFAULT,
      String importUri,
      int elemOffset}) {
    final cs = assertSuggest(name,
        relevance: relevance, importUri: importUri, elemOffset: elemOffset);
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.CONSTRUCTOR));
    final index = name.indexOf('.');
    expect(element.name, index >= 0 ? name.substring(index + 1) : '');
    return cs;
  }

  CompletionSuggestion assertSuggestEnum(String completion,
      {bool isDeprecated: false}) {
    final suggestion = assertSuggest(completion, isDeprecated: isDeprecated);
    expect(suggestion.isDeprecated, isDeprecated);
    expect(suggestion.element.kind, protocol.ElementKind.ENUM);
    return suggestion;
  }

  CompletionSuggestion assertSuggestEnumConst(String completion,
      {int relevance: DART_RELEVANCE_DEFAULT, bool isDeprecated: false}) {
    final suggestion = assertSuggest(completion,
        relevance: relevance, isDeprecated: isDeprecated);
    expect(suggestion.completion, completion);
    expect(suggestion.isDeprecated, isDeprecated);
    expect(suggestion.element.kind, protocol.ElementKind.ENUM_CONSTANT);
    return suggestion;
  }

  CompletionSuggestion assertSuggestField(String name, String type,
      {int relevance: DART_RELEVANCE_DEFAULT,
      String importUri,
      CompletionSuggestionKind kind: CompletionSuggestionKind.INVOCATION,
      bool isDeprecated: false}) {
    final cs = assertSuggest(name,
        csKind: kind,
        relevance: relevance,
        importUri: importUri,
        elemKind: protocol.ElementKind.FIELD,
        isDeprecated: isDeprecated);
    // The returnType represents the type of a field
    expect(cs.returnType, type != null ? type : 'dynamic');
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.FIELD));
    expect(element.name, equals(name));
    expect(element.parameters, isNull);
    // The returnType represents the type of a field
    expect(element.returnType, type != null ? type : 'dynamic');
    assertHasNoParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestFunction(String name, String returnType,
      {CompletionSuggestionKind kind: CompletionSuggestionKind.INVOCATION,
      bool isDeprecated: false,
      int relevance: DART_RELEVANCE_DEFAULT,
      String importUri}) {
    final cs = assertSuggest(name,
        csKind: kind,
        relevance: relevance,
        importUri: importUri,
        isDeprecated: isDeprecated);
    if (returnType != null) {
      expect(cs.returnType, returnType);
    } else if (isNullExpectedReturnTypeConsideredDynamic) {
      expect(cs.returnType, 'dynamic');
    }
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.FUNCTION));
    expect(element.name, equals(name));
    expect(element.isDeprecated, equals(isDeprecated));
    final param = element.parameters;
    expect(param, isNotNull);
    expect(param[0], equals('('));
    expect(param[param.length - 1], equals(')'));
    if (returnType != null) {
      expect(element.returnType, returnType);
    } else if (isNullExpectedReturnTypeConsideredDynamic) {
      expect(element.returnType, 'dynamic');
    }
    assertHasParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestFunctionTypeAlias(
      String name, String returnType,
      {bool isDeprecated: false,
      int relevance: DART_RELEVANCE_DEFAULT,
      CompletionSuggestionKind kind: CompletionSuggestionKind.INVOCATION,
      String importUri}) {
    final cs = assertSuggest(name,
        csKind: kind,
        relevance: relevance,
        importUri: importUri,
        isDeprecated: isDeprecated);
    if (returnType != null) {
      expect(cs.returnType, returnType);
    } else if (isNullExpectedReturnTypeConsideredDynamic) {
      expect(cs.returnType, 'dynamic');
    } else {
      expect(cs.returnType, isNull);
    }
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.FUNCTION_TYPE_ALIAS));
    expect(element.name, equals(name));
    expect(element.isDeprecated, equals(isDeprecated));
    // TODO (danrubel) Determine why params are null
    //    final param = element.parameters;
    //    expect(param, isNotNull);
    //    expect(param[0], equals('('));
    //    expect(param[param.length - 1], equals(')'));
    expect(element.returnType,
        equals(returnType != null ? returnType : 'dynamic'));
    // TODO (danrubel) Determine why param info is missing
    //    assertHasParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestGetter(String name, String returnType,
      {int relevance: DART_RELEVANCE_DEFAULT,
      String importUri,
      CompletionSuggestionKind kind: CompletionSuggestionKind.INVOCATION,
      bool isDeprecated: false}) {
    final cs = assertSuggest(name,
        csKind: kind,
        relevance: relevance,
        importUri: importUri,
        elemKind: protocol.ElementKind.GETTER,
        isDeprecated: isDeprecated);
    expect(cs.returnType, returnType != null ? returnType : 'dynamic');
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.GETTER));
    expect(element.name, equals(name));
    expect(element.parameters, isNull);
    expect(element.returnType,
        equals(returnType != null ? returnType : 'dynamic'));
    assertHasNoParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestMethod(
      String name, String declaringType, String returnType,
      {int relevance: DART_RELEVANCE_DEFAULT,
      String importUri,
      CompletionSuggestionKind kind: CompletionSuggestionKind.INVOCATION,
      bool isDeprecated: false}) {
    final cs = assertSuggest(name,
        csKind: kind,
        relevance: relevance,
        importUri: importUri,
        isDeprecated: isDeprecated);
    expect(cs.declaringType, equals(declaringType));
    expect(cs.returnType, returnType != null ? returnType : 'dynamic');
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.METHOD));
    expect(element.name, equals(name));
    final param = element.parameters;
    expect(param, isNotNull);
    expect(param[0], equals('('));
    expect(param[param.length - 1], equals(')'));
    expect(element.returnType, returnType != null ? returnType : 'dynamic');
    assertHasParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestName(String name,
      {int relevance: DART_RELEVANCE_DEFAULT,
      String importUri,
      CompletionSuggestionKind kind: CompletionSuggestionKind.IDENTIFIER,
      bool isDeprecated: false}) {
    final cs = assertSuggest(name,
        csKind: kind,
        relevance: relevance,
        importUri: importUri,
        isDeprecated: isDeprecated);
    expect(cs.completion, equals(name));
    expect(cs.element, isNull);
    assertHasNoParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestSetter(String name,
      {int relevance: DART_RELEVANCE_DEFAULT,
      String importUri,
      CompletionSuggestionKind kind: CompletionSuggestionKind.INVOCATION,
      String returnType: 'dynamic'}) {
    final cs = assertSuggest(name,
        csKind: kind,
        relevance: relevance,
        importUri: importUri,
        elemKind: protocol.ElementKind.SETTER);
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.SETTER));
    expect(element.name, equals(name));
    // TODO (danrubel) assert setter param
    //expect(element.parameters, isNull);
    // TODO (danrubel) it would be better if this was always null
    if (element.returnType != null) {
      expect(element.returnType, returnType);
    }
    assertHasNoParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestTemplateInput(String name,
      {String elementName,
      int relevance: DART_RELEVANCE_DEFAULT,
      String importUri,
      CompletionSuggestionKind kind: CompletionSuggestionKind.INVOCATION}) {
    final cs = assertSuggest(name,
        csKind: kind,
        relevance: relevance,
        importUri: importUri,
        elemKind: protocol.ElementKind.SETTER);
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.SETTER));
    expect(element.name, equals(elementName));
    if (element.returnType != null) {
      expect(element.returnType, 'dynamic');
    }
    assertHasNoParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestStar(String name,
      {int relevance: DART_RELEVANCE_DEFAULT,
      CompletionSuggestionKind kind: CompletionSuggestionKind.IDENTIFIER}) {
    final cs = assertSuggest(name, csKind: kind, relevance: relevance);
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.CLASS));
    expect(element.name, equals(name));
    expect(element.parameters, isNull);
    expect(element.returnType, isNull);
    assertHasNoParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestTopLevelVar(String name, String returnType,
      {int relevance: DART_RELEVANCE_DEFAULT,
      CompletionSuggestionKind kind: CompletionSuggestionKind.INVOCATION,
      String importUri}) {
    final cs = assertSuggest(name,
        csKind: kind, relevance: relevance, importUri: importUri);
    if (returnType != null) {
      expect(cs.returnType, returnType);
    } else if (isNullExpectedReturnTypeConsideredDynamic) {
      expect(cs.returnType, 'dynamic');
    }
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.TOP_LEVEL_VARIABLE));
    expect(element.name, equals(name));
    expect(element.parameters, isNull);
    if (returnType != null) {
      expect(element.returnType, returnType);
    } else if (isNullExpectedReturnTypeConsideredDynamic) {
      expect(element.returnType, 'dynamic');
    }
    assertHasNoParameterInfo(cs);
    return cs;
  }

  CompletionSuggestion assertSuggestLocalVar(String name, String returnType,
      {int relevance: DART_RELEVANCE_LOCAL_VARIABLE,
      CompletionSuggestionKind kind: CompletionSuggestionKind.INVOCATION,
      String importUri}) {
    final cs = assertSuggest(name,
        csKind: kind, relevance: relevance, importUri: importUri);
    if (returnType != null) {
      expect(cs.returnType, returnType);
    } else if (isNullExpectedReturnTypeConsideredDynamic) {
      expect(cs.returnType, 'dynamic');
    }
    final element = cs.element;
    expect(element, isNotNull);
    expect(element.kind, equals(protocol.ElementKind.LOCAL_VARIABLE));
    expect(element.name, equals(name));
    expect(element.parameters, isNull);
    if (returnType != null) {
      expect(element.returnType, returnType);
    } else if (isNullExpectedReturnTypeConsideredDynamic) {
      expect(element.returnType, 'dynamic');
    }
    assertHasNoParameterInfo(cs);
    return cs;
  }

  Future computeSuggestions([int times = 200]);

  void failedCompletion(String message,
      [Iterable<CompletionSuggestion> completions]) {
    final sb = new StringBuffer(message);
    if (completions != null) {
      sb.write('\n  found');
      completions.toList()
        ..sort(suggestionComparator)
        ..forEach((final suggestion) {
          sb.write('\n    ${suggestion.completion} -> $suggestion');
        });
    }
    fail(sb.toString());
  }

  CompletionSuggestion getSuggest(
      {String completion: null,
      CompletionSuggestionKind csKind: null,
      protocol.ElementKind elemKind: null}) {
    var cs;
    if (suggestions != null) {
      suggestions.forEach((s) {
        if (completion != null && completion != s.completion) {
          return;
        }
        if (csKind != null && csKind != s.kind) {
          return;
        }
        if (elemKind != null) {
          final element = s.element;
          if (element == null || elemKind != element.kind) {
            return;
          }
        }
        if (cs == null) {
          cs = s;
        } else {
          failedCompletion('expected exactly one $cs',
              suggestions.where((s) => s.completion == completion));
        }
      });
    }
    return cs;
  }

  @override
  void setUp() {
    super.setUp();
    addAngularSources();
  }
}

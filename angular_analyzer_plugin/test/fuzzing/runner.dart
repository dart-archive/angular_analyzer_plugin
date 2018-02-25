import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:tuple/tuple.dart';

import 'analysis.dart';
import 'base.dart';
import 'case.dart';
import 'completion.dart';
import 'producer.dart';
import 'simplifier.dart';

void main(List<String> args) {
  final parser = new ArgParser()
    ..addOption('target')
    ..addCommand('rerun', new ArgParser()..addOption('target'))
    ..addCommand('simplify', new ArgParser()..addOption('target'));

  final result = parser.parse(args);

  FuzzRunner systemUnderTest;

  final command = result.command ?? result;
  final target = command['target'];

  switch (target) {
    case 'completion':
      systemUnderTest = new FuzzRunner(new CompletionFuzzTest());
      break;
    case 'analysis':
      systemUnderTest = new FuzzRunner(new AnalysisFuzzTest());
      break;
    default:
      throw new Exception('target must be completion or analysis: got $target');
  }

  print('Fuzzing target set to $target.');

  final commandName = result.command?.name;
  if (commandName == null) {
    if (command.rest.isNotEmpty) {
      throw new Exception('cannot have trailing arguments except for "rerun"'
          ' and "simplify" commands');
    }
    systemUnderTest.fuzzLoop();
    return;
  }

  if (command.rest.isEmpty) {
    throw new Exception('No seeds specified for subcommand');
  }

  switch (commandName) {
    case 'rerun':
      for (final seed in command.rest) {
        systemUnderTest.rerun(int.parse(seed));
      }
      break;
    case 'simplify':
      for (final seed in command.rest) {
        systemUnderTest.simplify(int.parse(seed));
      }
      break;
  }
}

/// A wrapper around a [Fuzzable] which can do a loop of random cases, rerun
/// failed fuzzes by seed, and simplify crash cases via [StringSimplifier]s.
class FuzzRunner {
  final Fuzzable fuzzable;

  /// Cache stacktraces to seeds to simplify output.
  final stackTracesSeeds = <String, int>{};

  FuzzCaseProducer fuzzProducer = new FuzzCaseProducer();

  FuzzRunner(this.fuzzable);

  Future fuzzLoop() async {
    const iters = 1000000;
    for (var i = 0; i < iters; ++i) {
      final nextCase = fuzzable.getNextCase(fuzzProducer);
      // Use stdout.write (so there is now newline).
      stdout.write('\r' // Clear previous line.
          '$i: seed ${nextCase.seed} ${nextCase.transformCount}'
          // Add a space so that print("FAILED") isn't right by 'transforms'.
          ' transforms ');
      await reportIfCrashes(nextCase);
    }
  }

  /// Create a seeded [FuzzProducer] to rerun a [FuzzCase] by seed.
  Future<bool> rerun(int seed) {
    fuzzProducer = new FuzzCaseProducer.withSeed(seed);
    final nextCase = fuzzable.getNextCase(fuzzProducer);
    // Use stdout.write (so there is now newline).
    print('rerunning seed ${nextCase.seed}'
        ' ${nextCase.transformCount} transforms');
    return reportIfCrashes(nextCase);
  }

  /// Attempt to simplify a fuzz case down to something where the underlying
  /// problem will be more obvious.
  void simplify(int seed) async {
    fuzzProducer = new FuzzCaseProducer.withSeed(seed);
    var fuzzCase = fuzzable.getNextCase(fuzzProducer);
    print('simplifying seed $seed');

    if (!await crashes(fuzzCase)) {
      throw new Exception(
          'seed $seed does not crash; can and should not be simplified.');
    }

    StringSimplifier htmlSimplifier;
    StringSimplifier dartSimplifier;
    do {
      htmlSimplifier = new StringSimplifier(
          fuzzCase.html,
          (newHtml) => crashes(new FuzzCase(
              fuzzCase.seed, fuzzCase.transformCount, fuzzCase.dart, newHtml)));
      await htmlSimplifier.run();

      dartSimplifier = new StringSimplifier(
          fuzzCase.dart,
          (newDart) => crashes(new FuzzCase(fuzzCase.seed,
              fuzzCase.transformCount, newDart, htmlSimplifier.currentState)));
      await dartSimplifier.run();

      fuzzCase = new FuzzCase(fuzzCase.seed, fuzzCase.transformCount,
          dartSimplifier.currentState, htmlSimplifier.currentState);
    } while (htmlSimplifier.wasSimplified || dartSimplifier.wasSimplified);

    print("Simplification complete!");
    print('<<==DART CODE==>>\n${fuzzCase.dart}\n'
        '<<==HTML CODE==>>\n${fuzzCase.html}');
  }

  /// Does a [FuzzCase] crash?
  Future<bool> crashes(FuzzCase fuzzCase) async =>
      (await getCrashReport(fuzzCase)) != null;

  /// Attempt to run a [FuzzCase] via the inner [Fuzzable]'s `perform()`
  /// implementation.
  Future<Tuple2<StackTrace, dynamic>> getCrashReport(FuzzCase fuzzCase) {
    final zoneCompleter = new Completer<Tuple2<StackTrace, dynamic>>();
    var complete = false;

    runZoned(() {
      fuzzable.setUp();
      final resultFuture = fuzzable.perform(fuzzCase);
      Future.wait([resultFuture]).then((_) {
        zoneCompleter.complete(null);
        complete = true;
      });
    }, onError: (e, stacktrace) {
      if (!complete) {
        zoneCompleter.complete(new Tuple2<StackTrace, dynamic>(stacktrace, e));
        complete = true;
      }
    });

    return zoneCompleter.future;
  }

  /// Run a [FuzzCase] via the inner [Fuzzable]'s `perform()` implementation,
  /// and print out the crash details if it crashed. Also attempt to dedupe
  /// different fuzz failures by their stacktraces, and print out information
  /// about seeds that seem to fail for the same reason.
  Future<void> reportIfCrashes(FuzzCase fuzzCase) async {
    final crashResult = await getCrashReport(fuzzCase);
    if (crashResult == null) {
      return null;
    }

    final reason = '<<==DART CODE==>>\n${fuzzCase.dart}\n'
        '<<==HTML CODE==>>\n${fuzzCase.html}\n'
        '<<==DONE==>>';
    final e = crashResult.item2;
    final stacktrace = crashResult.item1;

    var stacktraceString = stacktrace.toString();
    // Limit the exception stacktrace; if the last 500 chars match, call it.
    stacktraceString = stacktraceString.substring(
        stacktraceString.length - 500, stacktraceString.length);

    final previousFailureSeed = stackTracesSeeds[stacktraceString];
    if (previousFailureSeed == null) {
      stackTracesSeeds[stacktraceString] = fuzzCase.seed;
      print("FAILED \n$reason\n$e\n$stacktrace");
    } else {
      print("FAILED (same as previous $previousFailureSeed)");
    }
  }
}

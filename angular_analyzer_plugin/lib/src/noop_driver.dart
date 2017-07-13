import 'dart:async';
import 'package:analyzer/src/dart/analysis/driver.dart';

class NoopDriver implements AnalysisDriverGeneric {
  @override
  void addFile(String path) => null;

  @override
  void dispose() => null;

  @override
  Future<Null> performWork() async => null;

  @override
  bool get hasFilesToAnalyze => false;

  @override
  AnalysisDriverPriority get workPriority => AnalysisDriverPriority.nothing;

  @override
  set priorityFiles(Object o) => null; // ignore: avoid_setters_without_getters
}

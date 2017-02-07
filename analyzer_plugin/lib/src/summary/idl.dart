import 'package:analyzer/src/summary/base.dart' as base;
import 'package:analyzer/src/summary/base.dart' show Id, TopLevel, ImportedIdl;

@ImportedIdl()
import 'package:analyzer/src/summary/idl.dart' show AnalysisDriverUnitError;
import 'format.dart' as generated;

@TopLevel('APdl')
abstract class PackageBundle extends base.SummaryClass {
  factory PackageBundle.fromBuffer(List<int> buffer) =>
      generated.readPackageBundle(buffer);

  @Id(0)
  List<UnlinkedDartSummary> get unlinkedDartSummary;
}

@TopLevel('APLH')
abstract class LinkedHtmlSummary extends base.SummaryClass {
  factory LinkedHtmlSummary.fromBuffer(List<int> buffer) =>
      generated.readLinkedHtmlSummary(buffer);

  @Id(0)
  List<AnalysisDriverUnitError> get errors;
}

@TopLevel('APUH')
abstract class UnlinkedHtmlSummary extends base.SummaryClass {
  factory UnlinkedDartSummary.fromBuffer(List<int> buffer) =>
      generated.readUnlinkedHtmlSummary(buffer);

  @Id(0)
  List<SummarizedNgContent> get ngContents;

  @Id(1)
  List<AnalysisDriverUnitError> get errors;
}

@TopLevel('APLD')
abstract class LinkedDartSummary extends base.SummaryClass {
  factory LinkedDartSummary.fromBuffer(List<int> buffer) =>
      generated.readLinkedDartSummary(buffer);

  @Id(0)
  List<AnalysisDriverUnitError> get errors;

  @Id(1)
  List<String> get referencedHtmlFiles;
}

@TopLevel('APUD')
abstract class UnlinkedDartSummary extends base.SummaryClass {
  factory UnlinkedDartSummary.fromBuffer(List<int> buffer) =>
      generated.readUnlinkedDartSummary(buffer);

  @Id(0)
  List<SummarizedDirective> get directiveSummaries;

  @Id(1)
  List<AnalysisDriverUnitError> get errors;
}

abstract class SummarizedDirective extends base.SummaryClass {
  @Id(0)
  bool get isComponent;
  @Id(1)
  String get selectorStr;
  @Id(2)
  int get selectorOffset;
  @Id(3)
  String get decoratedClassName;
  @Id(4)
  String get exportAs;
  @Id(5)
  int get exportAsOffset;
  @Id(6)
  String get templateUrl;
  @Id(7)
  String get templateText;
  @Id(8)
  int get templateOffset;
  @Id(9)
  List<SummarizedNgContent> get ngContents;
  @Id(10)
  List<SummarizedBindable> get inputs;
  @Id(11)
  List<SummarizedBindable> get outputs;
  @Id(12)
  List<SummarizedDirectiveUse> get subdirectives;
}

abstract class SummarizedBindable extends base.SummaryClass {
  @Id(0)
  String get name;
  @Id(1)
  int get nameOffset;
  @Id(2)
  String get propName;
  @Id(3)
  int get propNameOffset;
}

abstract class SummarizedDirectiveUse extends base.SummaryClass {
  @Id(0)
  String get name;
  @Id(1)
  String get prefix;
}

abstract class SummarizedNgContent extends base.SummaryClass {
  @Id(0)
  String get offset;
  @Id(1)
  int get length;
  @Id(2)
  String get selectorStr;
  @Id(3)
  int get selectorOffset;
}

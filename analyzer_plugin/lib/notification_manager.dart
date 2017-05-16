import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/generated/source.dart';

abstract class NotificationManager {
  void recordAnalysisErrors(
      String path, LineInfo lineInfo, List<AnalysisError> analysisErrors);
}

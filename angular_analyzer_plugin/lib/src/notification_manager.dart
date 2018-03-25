import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/notification_manager.dart';

// TODO(mfairhurst) remove NotificationManager & old plugin loader.
class NoopNotificationManager implements NotificationManager {
  NoopNotificationManager();

  @override
  void recordAnalysisErrors(
      String path, LineInfo lineInfo, List<AnalysisError> analysisErrors) {}
}

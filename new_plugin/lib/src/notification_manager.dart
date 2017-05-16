import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer_plugin/channel/channel.dart';
import 'package:analyzer_plugin/protocol/protocol_constants.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:analyzer_plugin/utilities/analyzer_converter.dart';
import 'package:angular_analyzer_plugin/notification_manager.dart';

class ChannelNotificationManager implements NotificationManager {
  final PluginCommunicationChannel channel;

  ChannelNotificationManager(this.channel);

  @override
  void recordAnalysisErrors(
      String path, LineInfo lineInfo, List<AnalysisError> analysisErrors) {
    final converter = new AnalyzerConverter();
    // TODO(mfairhurst) Get the right analysis options.
    final errors = converter.convertAnalysisErrors(
      analysisErrors,
      lineInfo: lineInfo,
    );
    channel.sendNotification(
        new plugin.AnalysisErrorsParams(path, errors).toNotification());
  }
}

import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';

class IgnoringAnalysisErrorListener implements AnalysisErrorListener {
  @override
  void onError(AnalysisError error) {}
}

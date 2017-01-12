import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/generated/source.dart';

/**
 * A wrapper around AnalysisError which also links back to a "from" file for
 * context.
 *
 * Is a wrapper, not just an extension, so that it can have a different hashCode
 * than the error without a "from" path, in the case that a file is included
 * both sanely and strangely (which is common: prod and test).
 */
class FromFilePrefixedError implements AnalysisError {
  final Source fromSource;
  final String originalMessage;
  final AnalysisError originalError;
  String _message;

  FromFilePrefixedError(this.fromSource, AnalysisError originalError)
      : originalMessage = originalError.message,
        originalError = originalError {
    _message = "$originalMessage (from ${fromSource.fullName})";
  }

  @override
  ErrorCode get errorCode => originalError.errorCode;

  @override
  int get offset => originalError.offset;

  @override
  set offset(int v) => originalError.offset = v;

  @override
  int get length => originalError.length;

  @override
  set length(int v) => originalError.length = v;

  @override
  bool get isStaticOnly => originalError.isStaticOnly;

  @override
  set isStaticOnly(bool v) => originalError.isStaticOnly = v;

  @override
  getProperty<V>(ErrorProperty<V> v) => originalError.getProperty(v);

  @override
  String get correction => originalError.correction;

  @override
  Source get source => originalError.source;

  @override
  String get message => _message;

  @override
  int get hashCode {
    int hashCode = offset;
    hashCode ^= (_message != null) ? _message.hashCode : 0;
    hashCode ^= (source != null) ? source.hashCode : 0;
    return hashCode;
  }
}

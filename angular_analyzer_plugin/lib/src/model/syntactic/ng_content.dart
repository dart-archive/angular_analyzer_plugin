import 'package:angular_analyzer_plugin/src/selector.dart';

/// TODO(mfairhurst) where should this go? It is not based on dart source so
/// probably does not belong here.
class NgContent {
  final int offset;
  final int length;

  /// NOTE: May contain Null. Null in this case means no selector (all content).
  final Selector selector;
  final int selectorOffset;
  final int selectorLength;

  NgContent(this.offset, this.length)
      : selector = null,
        selectorOffset = null,
        selectorLength = null;

  NgContent.withSelector(this.offset, this.length, this.selector,
      this.selectorOffset, this.selectorLength);

  bool get matchesAll => selector == null;
}

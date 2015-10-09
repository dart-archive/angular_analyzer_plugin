library angular2.src.analysis.server_plugin.index;

import 'package:analysis_server/plugin/index/index_core.dart';
import 'package:analyzer/src/generated/element.dart' show ElementKind;
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';

/// [ElementKind] for Angular
const ElementKind ANGULAR = const ElementKind('ANGULAR', 50, "class");

/// A wrapper around an [AngularElement] that implements the [IndexableObject] interface.
class IndexableAngularElement implements IndexableObject {
  final AngularElement element;

  IndexableAngularElement(this.element) {
    if (element == null) {
      throw new ArgumentError.notNull('element');
    }
  }

  @override
  int get hashCode => element.hashCode;

  @override
  IndexableObjectKind get kind => IndexableElementKind.forElement(element);

  @override
  int get offset => element.nameOffset;

  @override
  Source get source => element.source;

  @override
  bool operator ==(Object object) =>
      object is IndexableAngularElement && element == object.element;

  @override
  String toString() => element.toString();
}

/// The kind associated with an [IndexableElement].
class IndexableElementKind implements IndexableObjectKind {
  @override
  final int index = IndexableObjectKind.nextIndex;

  final ElementKind elementKind;

  IndexableElementKind._(this.elementKind) {
    IndexableObjectKind.register(this);
  }

  @override
  IndexableObject decode(AnalysisContext context, String filePath, int offset) {
    // TODO: get the IndexableElement
    return null;
  }

  @override
  int encodeHash(StringToInt stringToInt, IndexableObject indexable) {
    // TODO: implement encodeHash
    return 0;
  }

  static IndexableElementKind forElement(AngularElement element) {
    return new IndexableElementKind._(ANGULAR);
  }
}

import 'package:analyzer/src/generated/source.dart' show Source, SourceRange;
import 'package:angular_analyzer_plugin/src/model/syntactic/base_class_directive.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/component.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/content_child.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/element.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/input.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/ng_content.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/output.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/reference.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';

/// An angular component that's still mostly syntactic, but has resolved
/// [NgContent]s.
class ComponentWithNgContents extends Component {
  final List<NgContent> ngContents;

  ComponentWithNgContents(String className, Source source,
      {AngularElement exportAs,
      List<Input> inputs,
      List<Output> outputs,
      Selector selector,
      List<ElementNameSelector> elementTags,
      List<ContentChild> contentChildFields,
      List<ContentChild> contentChildrenFields,
      ListOrReference directives,
      ListOrReference pipes,
      ListOrReference exports,
      String templateText,
      int templateOffset,
      String templateUrl,
      SourceRange templateUrlRange,
      this.ngContents})
      : super(className, source,
            exportAs: exportAs,
            inputs: inputs,
            outputs: outputs,
            selector: selector,
            elementTags: elementTags,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields,
            directives: directives,
            pipes: pipes,
            exports: exports,
            templateText: templateText,
            templateOffset: templateOffset,
            templateUrl: templateUrl,
            templateUrlRange: templateUrlRange);
}

import 'package:angular_analyzer_plugin/src/model/syntactic/element.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/top_level.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';

/// Core behavior to directives and components, including functional directives,
/// but excluding non directive parts of angular such as pipes and regular
/// annotated classes.
abstract class BaseDirective extends TopLevel {
  List<ElementNameSelector> get elementTags;

  AngularElement get exportAs;

  String get name;

  Selector get selector;
}

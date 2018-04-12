import 'dart:async';
import 'package:angular/angular.dart';

@Directive(selector: "[bubbled]", exportAs: 'bubble')
class BubbledDirective {

  @Input("BubbleWidth") int width;
  @Output() Stream popped;

}

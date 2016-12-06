import 'package:angular2/angular2.dart';

@Directive(selector: "[bubbled]", exportAs: 'bubble')
class BubbledDirective {
  int _width;

  @Input("bubbleWidth") set width(int x) => _width = x;
  int get width => _width;

  @Output() EventEmitter<int> get popped => new EventEmitter();

}

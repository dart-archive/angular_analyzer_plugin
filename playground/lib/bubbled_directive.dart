import 'package:angular2/angular2.dart';

@Directive(selector: "[bubbled]", exportAs: 'bubble')
class BubbledDirective {

  @Input("BubbleWidth") int width;
  @Output() EventEmitter popped = new EventEmitter();

}

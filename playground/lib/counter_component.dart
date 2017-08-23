import 'package:angular2/angular2.dart';
import 'dart:html';

const foo = 1;

@Component(
    selector: 'my-counter',
    template: r'<button (click)="increment($event)">++</button> {{foo}}',
    exports: const [foo])
class CounterComponent {
  @Input()
  int count;
  @Output()
  EventEmitter<int> incremented;

  increment(MouseEvent event) {
    count++;
    incremented.add(count);
  }

  CounterComponent() {}
}

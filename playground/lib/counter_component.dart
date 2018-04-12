import 'dart:async';
import 'dart:html';
import 'package:angular/angular.dart';

const foo = 1;

@Component(
    selector: 'my-counter',
    template: r'<button (click)="increment($event)">++</button> {{foo}}',
    exports: const [foo])
class CounterComponent {
  @Input()
  int count;
  StreamController<int> _incrementedController;
  @Output()
  Stream<int> get incremented => _incrementedController.stream;

  increment(MouseEvent event) {
    count++;
    _incrementedController.add(count);
  }

  CounterComponent() {}
}

import 'package:angular2/angular2.dart';
import 'dart:html';

@Component(selector: 'my-counter', template: r'{{count}} <button (click)="increment($event)">++</button>')
class CounterComponent {

  @Input() int count;
  @Output() EventEmitter<int> countChange;

  increment(MouseEvent event) {
    count++;
    countChange.add(count);
  }

  CounterComponent() {
  }
}

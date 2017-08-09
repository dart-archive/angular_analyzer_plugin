import 'package:angular2/angular2.dart';
import 'counter_component.dart';
import 'bubbled_directive.dart';

@Component(selector: 'blah',
    directives: const[CounterComponent, NgFor, NgIf, BubbledDirective],
    templateUrl: 'overview_component.html'
)
class OverviewComponent {
  String header;
  List<String> items;

  OtherComponent() {
  }
}

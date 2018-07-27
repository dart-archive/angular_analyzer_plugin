// package:tuple does not yet support Dart 2. In the meantime, hardcode the two
// tuple types used in this project.

class Tuple2<A, B> {
  final A item1;
  final B item2;
  Tuple2(this.item1, this.item2);
}

class Tuple4<A, B, C, D> {
  final A item1;
  final B item2;
  final C item3;
  final D item4;
  Tuple4(this.item1, this.item2, this.item3, this.item4);
}

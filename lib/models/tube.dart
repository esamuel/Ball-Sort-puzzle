class Tube {
  final int capacity;
  List<String> balls;

  Tube(this.balls, {this.capacity = 12});

  bool get isFull => balls.length >= capacity;

  // Allow move onto any tube that has free space. Color restriction removed per game spec.
  bool canAccept(String ball) => !isFull;
}

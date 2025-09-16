class Tube {
  final int capacity;
  List<String> balls;

  Tube(this.balls, {this.capacity = 12});

  bool get isFull => balls.length >= capacity;
  bool get isEmpty => balls.isEmpty;
  String get topBall => balls.isNotEmpty ? balls.last : '';
  
  bool get isSorted {
    if (isEmpty) return true;
    if (balls.length == 1) return true;
    final String firstColor = balls.first;
    return balls.every((ball) => ball == firstColor);
  }

  // Strictly sorted for win condition: must be full and homogeneous
  bool get isFullAndSorted {
    if (balls.length != capacity) return false;
    final String firstColor = balls.first;
    return balls.every((ball) => ball == firstColor);
  }

  // Allow move onto any tube that has free space. Color restriction removed per game spec.
  bool canAccept(String ball) => !isFull;
}

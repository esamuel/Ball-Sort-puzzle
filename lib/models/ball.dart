class Ball {
  final String color;
  final bool hasBeenMovedByUser;

  Ball(this.color, {this.hasBeenMovedByUser = false});

  Ball copyWith({String? color, bool? hasBeenMovedByUser}) {
    return Ball(
      color ?? this.color,
      hasBeenMovedByUser: hasBeenMovedByUser ?? this.hasBeenMovedByUser,
    );
  }

  @override
  String toString() => color;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ball &&
        other.color == color &&
        other.hasBeenMovedByUser == hasBeenMovedByUser;
  }

  @override
  int get hashCode => color.hashCode ^ hasBeenMovedByUser.hashCode;
}

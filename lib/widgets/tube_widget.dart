import 'package:flutter/material.dart';
import '../models/tube.dart';

class TubeWidget extends StatelessWidget {
  final Tube tube;
  final bool highlight;
  final int capacity;
  final int? tubeIndex; // used for drag data
  final bool hintAccept;
  final VoidCallback? onTap;
  final Function(int from, int to, String ball)? onDrop;
  // Optional: parent-provided predicate to decide if a ball can be dropped here
  final bool Function(String ball, Tube dest)? canDropPredicate;
  // When set, hides the topmost ball if it matches this color (used to avoid duplicate with ghost animation)
  final String? suppressTopForColor;

  const TubeWidget({
    super.key,
    required this.tube,
    this.highlight = false,
    this.capacity = 12,
    this.tubeIndex,
    this.hintAccept = false,
    this.onTap,
    this.onDrop,
    this.canDropPredicate,
    this.suppressTopForColor,
  });

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to size balls to fit in the available height
    return LayoutBuilder(
      builder: (context, constraints) {
        const double verticalPadding = 0; // exact fit to height when full
        const double horizontalPadding = 1;
        const double tubeBorderWidth = 2.0;
        const double itemSpacing = 0; // no spacing so balls fill height per slot

        final double usableHeight = constraints.maxHeight - (verticalPadding * 2) - (tubeBorderWidth * 2);
        final double usableWidth = constraints.maxWidth - (horizontalPadding * 2) - (tubeBorderWidth * 2);
        final int count = tube.balls.length.clamp(0, capacity);
        // Display from top to bottom: reverse so the visual top corresponds to tube.balls.last
        final List<String> displayBalls = List<String>.from(tube.balls.reversed);

        // Exact per-slot height with floor to avoid cumulative rounding overflow
        final double perSlot = usableHeight / capacity;
        double computedBallSize = perSlot.floorToDouble();
        if (computedBallSize > usableWidth) computedBallSize = usableWidth; // guard by inner width
        computedBallSize = computedBallSize.clamp(10.0, 96.0);

        return DragTarget<Map<String, dynamic>>(
          onWillAcceptWithDetails: (details) {
            final data = details.data;
            if (tubeIndex == null) return false;
            final int from = data['from'] as int;
            final String ball = data['ball'] as String;
            if (from == tubeIndex) return false;

            // If parent provided a predicate, use it to mirror game rules
            if (canDropPredicate != null) {
              return canDropPredicate!(ball, tube);
            }

            // Fallback: only accept if destination not full and (empty or same color)
            if (tube.isFull) return false;
            if (tube.isEmpty) return true;
            return tube.topBall == ball;
          },
          onAcceptWithDetails: (details) {
            if (onDrop != null && tubeIndex != null) {
              final data = details.data;
              final int from = data['from'] as int;
              final String ball = data['ball'] as String;
              onDrop!(from, tubeIndex!, ball);
            }
          },
          builder: (context, candidate, rejected) {
            final bool hover = candidate.isNotEmpty;
            Widget innerShell = Container(
              padding: const EdgeInsets.fromLTRB(horizontalPadding, verticalPadding, horizontalPadding, verticalPadding),
              decoration: BoxDecoration(
                border: Border.all(
                  color: hover
                      ? Colors.lightGreen
                      : (hintAccept ? Colors.lightGreen : (highlight ? Colors.orange : Colors.black54)),
                  width: tubeBorderWidth,
                ),
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF7F7F7), Color(0xFFD9D9D9)],
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.white70, offset: Offset(-1, -1), blurRadius: 1),
                  BoxShadow(color: Colors.black12, offset: Offset(1, 1), blurRadius: 2),
                ],
              ),
              child: Stack(
                children: [
                  // Inner bevel: subtle top highlight & bottom shadow
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.20),
                              Colors.transparent,
                              Colors.black.withOpacity(0.10),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                mainAxisAlignment: MainAxisAlignment.start, // portrait-like: placeholders on top, balls below
                children: [
                  // Always render placeholders for empty slots at the top so total height equals 12 slots
                  for (int i = 0; i < capacity - count; i++) ...[
                    Container(
                      width: computedBallSize,
                      height: computedBallSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                        border: Border.all(color: Colors.black12, width: 0.5),
                      ),
                    ),
                    if (i < capacity - count - 1) SizedBox(height: itemSpacing),
                  ],
                  // Render actual balls; displayBalls[0] is the visual TOP ball
                  for (int i = 0; i < count; i++) ...[
                    // Make ONLY the top ball draggable (i == 0)
                    if (i == 0 && tubeIndex != null && suppressTopForColor != displayBalls[i])
                      Draggable<Map<String, dynamic>>(
                        data: {'from': tubeIndex, 'ball': displayBalls[i]},
                        feedback: Container(
                          width: computedBallSize,
                          height: computedBallSize,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 4))],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset('assets/balls/${displayBalls[i]}.png', fit: BoxFit.cover),
                        ),
                        childWhenDragging: SizedBox(
                          width: computedBallSize,
                          height: computedBallSize,
                        ),
                        child: _ballWithDepth(displayBalls[i], computedBallSize),
                      )
                    else
                      _ballWithDepth(displayBalls[i], computedBallSize),
                    if (i < count - 1) SizedBox(height: itemSpacing),
                  ]
                ],
              ),
                ],
              ),
            );

            // Always use the full-height inner shell (fixed 12-slot tubes)
            Widget tubeBody = innerShell;

            // Remove bottom spacer to prevent overflow in tight layouts
            final double bottomLift = 0.0;

            // Wrap with a GestureDetector so taps are handled here, avoiding parent conflicts with Draggable
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tubeBody,
                  if (bottomLift > 0) SizedBox(height: bottomLift),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Wrap the ball image with subtle shadow to give 3D feel
  Widget _ballWithDepth(String colorName, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              "assets/balls/$colorName.png",
              fit: BoxFit.cover,
            ),
            // specular highlight gradient for extra depth
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.18),
                    Colors.transparent,
                    Colors.black.withOpacity(0.08),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

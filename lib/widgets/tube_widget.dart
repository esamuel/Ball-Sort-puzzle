import 'package:flutter/material.dart';
import '../models/tube.dart';

class TubeWidget extends StatelessWidget {
  final Tube tube;
  final bool highlight;
  final int capacity;
  final int? tubeIndex; // used for drag data
  final void Function(int from, int to, String ball)? onDrop;
  final bool hintAccept;
  final VoidCallback? onTap;
  // When set, hides the topmost ball if it matches this color (used to avoid duplicate with ghost animation)
  final String? suppressTopForColor;

  const TubeWidget({
    super.key,
    required this.tube,
    this.highlight = false,
    this.capacity = 12,
    this.tubeIndex,
    this.onDrop,
    this.hintAccept = false,
    this.onTap,
    this.suppressTopForColor,
  });

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to size balls to fit in the available height
    return LayoutBuilder(
      builder: (context, constraints) {
        const double verticalPadding = 0; // exact fit to height when full
        const double horizontalPadding = 2;
        const double tubeBorderWidth = 1.5;
        const double itemSpacing = 0; // no spacing so balls fill height per slot

        final double usableHeight = constraints.maxHeight - (verticalPadding * 2) - (tubeBorderWidth * 2);
        final double usableWidth = constraints.maxWidth - (horizontalPadding * 2) - (tubeBorderWidth * 2);
        final int count = tube.balls.length.clamp(0, capacity);
        // Orientation (used only for cosmetic bottom spacing inside each tile)
        final media = MediaQuery.of(context);
        final bool isLandscape = media.orientation == Orientation.landscape;
        // Display from top to bottom: reverse so the visual top corresponds to tube.balls.last
        final List<String> displayBalls = List<String>.from(tube.balls.reversed);

        // Exact per-slot height (portrait behavior): bottom ball touches lower edge, no margin.
        final double perSlot = usableHeight / capacity;
        double computedBallSize = perSlot;
        if (computedBallSize > usableWidth) computedBallSize = usableWidth; // guard by inner width
        computedBallSize = computedBallSize.clamp(8.0, 60.0);

        return DragTarget<Map<String, dynamic>>(
          onWillAccept: (data) {
            // accept only if moving to a different tube and destination can accept the ball
            if (data == null || tubeIndex == null) return false;
            final int from = data['from'] as int;
            final String ball = data['ball'] as String;
            if (from == tubeIndex) return false;
            return tube.canAccept(ball);
          },
          onAccept: (data) {
            if (onDrop != null && tubeIndex != null) {
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
                borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(10),
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
                  // Render actual balls; displayBalls[0] is the visual top ball
                  for (int i = 0; i < count; i++) ...[
                    // If we are asked to suppress the visual top ball (to avoid duplication during ghost flight),
                    // render a transparent spacer for the top slot instead of the ball/Draggable.
                    if (i == 0 && suppressTopForColor != null && displayBalls[i] == suppressTopForColor)
                      SizedBox(width: computedBallSize, height: computedBallSize)
                    else if (i == 0 && tubeIndex != null)
                      Draggable<Map<String, dynamic>>(
                        data: {
                          'from': tubeIndex,
                          'ball': displayBalls[i],
                        },
                        dragAnchorStrategy: childDragAnchorStrategy,
                        feedback: Material(
                          type: MaterialType.transparency,
                          child: Image.asset(
                            "assets/balls/${displayBalls[i]}.png",
                            width: computedBallSize,
                            height: computedBallSize,
                            fit: BoxFit.contain,
                          ),
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

            // Add a bottom spacer only in landscape to raise the tube bottom without moving the board
            final double bottomLift = isLandscape ? 24.0 : 0.0;

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

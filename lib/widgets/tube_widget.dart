import 'package:flutter/material.dart';
import '../models/tube.dart';
import '../models/ball.dart';

class AnimatedBall extends StatefulWidget {
  final String colorName;
  final double size;
  final bool isTop;

  const AnimatedBall({
    super.key,
    required this.colorName,
    required this.size,
    this.isTop = false,
  });

  @override
  State<AnimatedBall> createState() => _AnimatedBallState();
}

class _AnimatedBallState extends State<AnimatedBall>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _bounceAnimation = Tween<double>(
      begin: -5.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.bounceOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildBallWithDepth(),
          ),
        );
      },
    );
  }

  Widget _buildBallWithDepth() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // Main shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: widget.size * 0.15,
            offset: Offset(widget.size * 0.08, widget.size * 0.12),
            spreadRadius: 0,
          ),
          // Ambient shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: widget.size * 0.25,
            offset: Offset(0, widget.size * 0.08),
            spreadRadius: widget.size * 0.02,
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base ball image
            Image.asset(
              "assets/balls/${widget.colorName}.png",
              fit: BoxFit.cover,
            ),
            // Enhanced 3D lighting effects
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.4),
                  radius: 0.8,
                  colors: [
                    Colors.white.withOpacity(0.6),
                    Colors.white.withOpacity(0.2),
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.3),
                  ],
                  stops: const [0.0, 0.15, 0.4, 0.8, 1.0],
                ),
              ),
            ),
            // Specular highlight
            Positioned(
              top: widget.size * 0.15,
              left: widget.size * 0.2,
              child: Container(
                width: widget.size * 0.25,
                height: widget.size * 0.2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.size * 0.15),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.8),
                      Colors.white.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Rim lighting
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white.withOpacity(0.1),
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TubeWidget extends StatelessWidget {
  final Tube tube;
  final bool highlight;
  final int capacity;
  final int? tubeIndex; // used for drag data
  final bool hintAccept;
  final VoidCallback? onTap;
  final Function(int from, int to, String ball)? onDrop;
  // Optional: parent-provided predicate to decide if a ball can be dropped here
  // Provides source index, destination index, ball color and destination tube
  final bool Function(int from, int to, String ball, Tube dest)?
      canDropPredicate;
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
        const double horizontalPadding = 0.0; // no padding for tighter spacing
        const double tubeBorderWidth =
            0.5; // ultra-thin borders to minimize visual gaps
        const double itemSpacing =
            0; // no spacing so balls fill height per slot

        final double usableHeight = constraints.maxHeight -
            (verticalPadding * 2) -
            (tubeBorderWidth * 2);
        final double usableWidth = constraints.maxWidth -
            (horizontalPadding * 2) -
            (tubeBorderWidth * 2);
        final int count = tube.balls.length.clamp(0, capacity);
        // Display from top to bottom: reverse so the visual top corresponds to tube.balls.last
        final List<Ball> displayBalls = List<Ball>.from(tube.balls.reversed);

        // Maximize ball size to fill available width while respecting height per slot
        // Add a tiny safety margin to prevent 1-4px rounding overflows on some devices
        const double heightSafety = 2.0;
        final double perSlot = (usableHeight - heightSafety) / capacity;
        double computedBallSize = perSlot.floorToDouble();
        // Ensure the total stacked height never exceeds available
        if ((computedBallSize * capacity) > (usableHeight - heightSafety)) {
          computedBallSize =
              ((usableHeight - heightSafety) / capacity).floorToDouble();
        }
        // Use the full available width (no 10% margin) but never exceed it
        if (computedBallSize > usableWidth) computedBallSize = usableWidth;
        computedBallSize = computedBallSize.clamp(15.0, 60.0);

        return DragTarget<Map<String, dynamic>>(
          onWillAcceptWithDetails: (details) {
            final data = details.data;
            if (tubeIndex == null) return false;
            final int from = data['from'] as int;
            final Ball ball = data['ball'] as Ball;
            if (from == tubeIndex) return false;

            // If parent provided a predicate, use it to mirror game rules
            if (canDropPredicate != null && tubeIndex != null) {
              return canDropPredicate!(from, tubeIndex!, ball.color, tube);
            }

            // Fallback: only accept if destination not full and (empty or same color)
            if (tube.isFull) return false;
            if (tube.isEmpty) return true;
            return tube.topBallColor == ball.color;
          },
          onAcceptWithDetails: (details) {
            if (onDrop != null && tubeIndex != null) {
              final data = details.data;
              final int from = data['from'] as int;
              final Ball ball = data['ball'] as Ball;
              onDrop!(from, tubeIndex!, ball.color);
            }
          },
          builder: (context, candidate, rejected) {
            final bool hover = candidate.isNotEmpty;
            Widget innerShell = Container(
              padding: const EdgeInsets.fromLTRB(horizontalPadding,
                  verticalPadding, horizontalPadding, verticalPadding),
              decoration: BoxDecoration(
                border: Border.all(
                  color: hover
                      ? Colors.lightGreen
                      : (hintAccept
                          ? Colors.lightGreen
                          : (highlight ? Colors.orange : Colors.black54)),
                  width: tubeBorderWidth,
                ),
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFAFAFA),
                    const Color(0xFFE8E8E8),
                    const Color(0xFFD0D0D0),
                    const Color(0xFFBBBBBB),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
                boxShadow: [
                  // Main depth shadow
                  const BoxShadow(
                    color: Colors.black26,
                    offset: Offset(2, 4),
                    blurRadius: 6,
                    spreadRadius: 0.5,
                  ),
                  // Inner highlight
                  const BoxShadow(
                    color: Colors.white70,
                    offset: Offset(-2, -2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                  // Ambient shadow
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    offset: const Offset(0, 2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Enhanced inner depth with cylindrical effect
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.5),
                            radius: 1.2,
                            colors: [
                              Colors.white.withOpacity(0.4),
                              Colors.white.withOpacity(0.1),
                              Colors.transparent,
                              Colors.black.withOpacity(0.15),
                            ],
                            stops: const [0.0, 0.3, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Additional cylindrical side shadows
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 3,
                    child: IgnorePointer(
                      ignoring: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomLeft: Radius.circular(6),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 3,
                    child: IgnorePointer(
                      ignoring: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Colors.black.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment
                        .start, // portrait-like: placeholders on top, balls below
                    children: [
                      // Always render placeholders for empty slots at the top so total height equals 12 slots
                      for (int i = 0; i < capacity - count; i++) ...[
                        Container(
                          width: computedBallSize,
                          height: computedBallSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                            border:
                                Border.all(color: Colors.black12, width: 0.5),
                          ),
                        ),
                        if (i < capacity - count - 1)
                          SizedBox(height: itemSpacing),
                      ],
                      // Render actual balls; displayBalls[0] is the visual TOP ball
                      for (int i = 0; i < count; i++) ...[
                        // Make ONLY the top ball draggable (i == 0)
                        if (i == 0 &&
                            tubeIndex != null &&
                            suppressTopForColor != displayBalls[i].color)
                          Draggable<Map<String, dynamic>>(
                            data: {'from': tubeIndex, 'ball': displayBalls[i]},
                            feedback: Transform.scale(
                              scale: 1.2,
                              child: Container(
                                width: computedBallSize,
                                height: computedBallSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: computedBallSize * 0.3,
                                      offset: Offset(computedBallSize * 0.1,
                                          computedBallSize * 0.2),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: computedBallSize * 0.5,
                                      offset:
                                          Offset(0, computedBallSize * 0.15),
                                      spreadRadius: computedBallSize * 0.05,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.asset(
                                        'assets/balls/${displayBalls[i].color}.png',
                                        fit: BoxFit.cover,
                                      ),
                                      // Enhanced glow effect while dragging
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: RadialGradient(
                                            center: const Alignment(-0.3, -0.3),
                                            radius: 0.7,
                                            colors: [
                                              Colors.white.withOpacity(0.7),
                                              Colors.white.withOpacity(0.3),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Container(
                              width: computedBallSize,
                              height: computedBallSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.withOpacity(0.3),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: AnimatedBall(
                              colorName: displayBalls[i].color,
                              size: computedBallSize,
                              isTop: true,
                            ),
                          )
                        else
                          AnimatedBall(
                            colorName: displayBalls[i].color,
                            size: computedBallSize,
                            isTop: i == 0,
                          ),
                        if (i < count - 1) SizedBox(height: itemSpacing),
                      ]
                    ],
                  ),
                  // Counter badge removed per request
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
}

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import '../models/node.dart';

class AnimatedGraphPainter extends CustomPainter {
  final Map<int, List<GraphNode>> nodesByDepth;
  final GraphNode? selectedNode;
  final Function(GraphNode) onNodeTap;
  final Size canvasSize;
  final double selectionAnimation;
  final double pulseAnimation;
  final double connectionAnimation;
  final Color backgroundColor;

  AnimatedGraphPainter({
    required this.nodesByDepth,
    required this.selectedNode,
    required this.onNodeTap,
    required this.canvasSize,
    required this.selectionAnimation,
    required this.pulseAnimation,
    required this.connectionAnimation,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw gradient background
    _drawBackground(canvas, size);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Calculate positions for all nodes (hierarchical centering)
    Map<GraphNode, Offset> nodePositions = _calculateNodePositions(size);

    // Draw animated connections first (so they appear behind nodes)
    _drawAnimatedConnections(canvas, nodePositions);

    // Draw nodes with enhanced effects
    _drawEnhancedNodes(canvas, textPainter, nodePositions);

    // Draw particle effects for selected node
    if (selectedNode != null) {
      _drawParticleEffects(canvas, nodePositions[selectedNode!]);
    }
  }

  // Draw bubbles that move along the entire path from root to selected node.
  void _drawCombinedPathBubbles(Canvas canvas, Map<GraphNode, Offset> positions) {
    // Build node chain from root -> selected
    final chain = <GraphNode>[];
    GraphNode? cur = selectedNode;
    while (cur != null) {
      chain.add(cur);
      cur = cur.parent;
    }
    if (chain.length < 2) return;
    final pathNodes = chain.reversed.toList(); // root..selected

    final isMobile = canvasSize.width < 600;
    final nodeRadius = isMobile ? 20.0 : 30.0;
    final desiredGap = nodeRadius + 28.0;

    // Assemble segments along the path, matching the drawing layout (parent vertical, horizontal bus, child vertical)
    final segments = <List<Offset>>[]; // each: [start, end]
    for (int i = 0; i < pathNodes.length - 1; i++) {
      final parent = pathNodes[i];
      final child = pathNodes[i + 1];
      final parentPos = positions[parent];
      final childPos = positions[child];
      if (parentPos == null || childPos == null) continue;

      // Compute junctionY same as in _drawAnimatedConnections for this parent
      // Gather all children positions for the parent (for minChildY)
      final parentChildren = parent.children;
      if (parentChildren.isEmpty) continue;
      double? minChildY;
      for (final ch in parentChildren) {
        final p = positions[ch];
        if (p == null) continue;
        minChildY = (minChildY == null) ? p.dy : math.min(minChildY!, p.dy);
      }
      if (minChildY == null) continue;

      final parentStartY = parentPos.dy + nodeRadius + 2.0;
      final junctionY = math.max(parentStartY + 10.0, minChildY - desiredGap);

      final parentStart = Offset(parentPos.dx, parentStartY);
      final parentJunction = Offset(parentPos.dx, junctionY);
      final horizStart = Offset(parentPos.dx, junctionY);
      final horizEnd = Offset(childPos.dx, junctionY);
      final childTop = Offset(childPos.dx, junctionY);
      final childBottom = Offset(childPos.dx, childPos.dy - nodeRadius);

      segments.add([parentStart, parentJunction]);
      segments.add([horizStart, horizEnd]);
      segments.add([childTop, childBottom]);
    }

    if (segments.isEmpty) return;

    // Compute total length
    double total = 0.0;
    final lengths = <double>[];
    for (final seg in segments) {
      final len = (seg[1] - seg[0]).distance;
      lengths.add(len);
      total += len;
    }
    if (total < 1e-3) return;

    // Determine bubble positions along the cumulative path.
    // One full controller cycle goes from root to selected.
    final leadDist = connectionAnimation * total;
    final spacing = isMobile ? 60.0 : 90.0; // distance between bubbles
    final bubbleCount = isMobile ? 2 : 3; // number of equally styled bubbles
    final radius = isMobile ? 4.0 : 5.5; // make all bubbles big and same size

    for (int i = 0; i < bubbleCount; i++) {
      double d = leadDist - i * spacing;
      // Loop within [0,total)
      while (d < 0) d += total;
      d = d % total;

      // Find segment for distance d
      double acc = 0.0;
      for (int s = 0; s < segments.length; s++) {
        final segLen = lengths[s];
        if (d <= acc + segLen || s == segments.length - 1) {
          final localT = ((d - acc) / (segLen == 0 ? 1 : segLen)).clamp(0.0, 1.0);
          final p0 = segments[s][0];
          final p1 = segments[s][1];
          final pos = Offset.lerp(p0, p1, localT)!;

          // All bubbles same opacity and size (dark and big)
          final alpha = 0.9;
          final bubblePaint = Paint()
            ..color = Colors.cyan.withValues(alpha: alpha)
            ..style = PaintingStyle.fill;
          final glowPaint = Paint()
            ..color = Colors.cyan.withValues(alpha: 0.4)
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

          canvas.drawCircle(pos, radius, bubblePaint);
          canvas.drawCircle(pos, radius + (isMobile ? 2.0 : 3.0), glowPaint);
          break;
        }
        acc += segLen;
      }
    }
  }

  Map<GraphNode, Offset> _calculateNodePositions(Size size) {
    final positions = <GraphNode, Offset>{};
    if (nodesByDepth.isEmpty) return positions;

    // Responsive spacing and node sizing
    final isMobile = size.width < 600;
    final nodeRadius = isMobile ? 20.0 : 30.0;
    final minNodeSpacing = nodeRadius * 2.5; // Minimum center-to-center spacing horizontally
    final minVerticalSpacing = isMobile ? 80.0 : 110.0;

    // Determine root
    GraphNode? root;
    if (nodesByDepth.containsKey(0) && nodesByDepth[0]!.isNotEmpty) {
      root = nodesByDepth[0]!.first;
    } else {
      for (final entry in nodesByDepth.entries) {
        for (final n in entry.value) {
          if (n.parent == null) { root = n; break; }
        }
        if (root != null) break;
      }
    }
    if (root == null) return positions;

    // Compute depth to set vertical spacing
    int maxDepth = 0;
    nodesByDepth.forEach((d, _) { maxDepth = math.max(maxDepth, d); });
    final availableHeight = size.height - 100; // margins
    // Allow spacing to shrink when there are many levels so more fit on screen
    final verticalSpacing = math.min(minVerticalSpacing, availableHeight / (maxDepth + 2));

    // First pass: subtree widths
    double subtreeWidth(GraphNode node) {
      if (node.children.isEmpty) return math.max(minNodeSpacing, nodeRadius * 2);
      double total = 0.0;
      for (final c in node.children) {
        total += subtreeWidth(c);
      }
      // add spacing between child subtrees
      total += (node.children.length - 1) * minNodeSpacing;
      // Ensure at least space for the node itself
      return math.max(total, nodeRadius * 2);
    }

    // Second pass: position nodes, centering parent over children
    void position(GraphNode node, double centerX, double y) {
      positions[node] = Offset(centerX, y);
      if (node.children.isEmpty) return;

      // total width of children subtrees
      double totalChildrenWidth = 0.0;
      final childWidths = <double>[];
      for (final c in node.children) {
        final w = subtreeWidth(c);
        childWidths.add(w);
        totalChildrenWidth += w;
      }
      totalChildrenWidth += (node.children.length - 1) * minNodeSpacing;

      // leftmost start so that parent is centered over children block
      double currentX = centerX - totalChildrenWidth / 2;
      for (int i = 0; i < node.children.length; i++) {
        final cw = childWidths[i];
        final childCenter = currentX + cw / 2;
        position(node.children[i], childCenter, y + verticalSpacing);
        currentX += cw + minNodeSpacing;
      }
    }

    // Root X centered within canvas with margins
    final margin = 50.0;
    final rootCenterX = (size.width / 2).clamp(margin, size.width - margin);
    final startY = math.min(50.0 + nodeRadius, size.height - 50.0);
    position(root, rootCenterX, startY);

    return positions;
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Solid background color extending to the entire infinite plane (white)
    final paint = Paint()
      ..color = backgroundColor;
    
    // Draw a much larger background to cover the infinite scrollable area
    // This ensures the background color extends beyond the visible canvas
    final infiniteSize = 100000.0; // Very large size to cover infinite plane
    canvas.drawRect(Rect.fromLTWH(-infiniteSize/2, -infiniteSize/2, infiniteSize, infiniteSize), paint);
  }

  void _drawAnimatedConnections(Canvas canvas, Map<GraphNode, Offset> positions) {
    // Always draw connectors between all parents and their children,
    // but only show moving particles along the path from root to selected node.

    // Compute path edges for particle flow
    final pathEdges = <String>{};
    if (selectedNode != null) {
      final pathList = <GraphNode>[];
      GraphNode? c = selectedNode;
      while (c != null) { pathList.add(c); c = c.parent; }
      if (pathList.length > 1) {
        final forward = pathList.reversed.toList();
        for (int i = 0; i < forward.length - 1; i++) {
          pathEdges.add('${forward[i].id}->${forward[i+1].id}');
        }
      }
    }

    final isMobile = canvasSize.width < 600;
    final strokeWidth = isMobile ? 2.0 : 3.0;
    final linePaint = Paint()
      ..color = Colors.black.withAlpha(220)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final nodeRadius = isMobile ? 20.0 : 30.0;
    final desiredGap = nodeRadius + 28.0;

    positions.forEach((parent, parentPos) {
      if (parent.children.isEmpty) return;

      // Gather child positions
      final childPosList = <GraphNode, Offset>{};
      for (final ch in parent.children) {
        final p = positions[ch];
        if (p != null) childPosList[ch] = p;
      }
      if (childPosList.isEmpty) return;

      // Junction Y with generous gap
      final minChildY = childPosList.values.map((o) => o.dy).reduce(math.min);
      final parentStartY = parentPos.dy + nodeRadius + 2.0;
      final junctionY = math.max(parentStartY + 10.0, minChildY - desiredGap);

      // Parent vertical
      final parentStart = Offset(parentPos.dx, parentStartY);
      final parentJunction = Offset(parentPos.dx, junctionY);
      canvas.drawLine(parentStart, parentJunction, linePaint);

      // We no longer draw per-segment particles; a single bubble now travels the whole path

      // Horizontal bus across children
      final minX = childPosList.values.map((o) => o.dx).reduce(math.min);
      final maxX = childPosList.values.map((o) => o.dx).reduce(math.max);
      canvas.drawLine(Offset(minX, junctionY), Offset(maxX, junctionY), linePaint);

      // For each child: vertical connector
      childPosList.forEach((child, cp) {
        final top = Offset(cp.dx, junctionY);
        final bottom = Offset(cp.dx, cp.dy - nodeRadius);
        canvas.drawLine(top, bottom, linePaint);
      });
    });

    // Draw a single (or few) bubbles traveling from root to the selected node along the full path
    if (selectedNode != null) {
      _drawCombinedPathBubbles(canvas, positions);
    }
  }
  
  void _drawMovingParticles(Canvas canvas, Offset start, Offset end) {
    final isMobile = canvasSize.width < 600;
    // Fewer particles for a cleaner, calmer animation
    final particleCount = isMobile ? 1 : 2;
    final particleSize = isMobile ? 3.0 : 4.0;

    // Ensure constant pixel speed across any segment length
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1e-3) return;

    // Pixels traveled per full animation cycle (connectionAnimation: 0..1)
    // Lower values = slower particles
    final pixelsPerCycle = isMobile ? 140.0 : 180.0;
    final spacingPx = isMobile ? 70.0 : 90.0; // distance between particles

    for (int i = 0; i < particleCount; i++) {
      // Base distance traveled along the line for this animation frame
      final baseDist = (connectionAnimation * pixelsPerCycle) % length;
      final dist = (baseDist + i * spacingPx) % length;
      final t = dist / length; // convert distance to normalized t for interpolation

      final particlePosition = Offset.lerp(start, end, t)!;

      // Draw particle with glow effect
      final particlePaint = Paint()
        ..color = Colors.cyan.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(particlePosition, particleSize, particlePaint);

      // Add glow
      final glowPaint = Paint()
        ..color = Colors.cyan.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

      canvas.drawCircle(particlePosition, isMobile ? 4.0 : 6.0, glowPaint);
    }
  }

  void _drawEnhancedNodes(Canvas canvas, TextPainter textPainter, Map<GraphNode, Offset> positions) {
    positions.forEach((node, position) {
      _drawSingleNode(canvas, textPainter, node, position);
    });
  }

  void _drawSingleNode(Canvas canvas, TextPainter textPainter, GraphNode node, Offset position) {
    // Responsive node sizing
    final isMobile = canvasSize.width < 600;
    final baseRadius = isMobile ? 20.0 : 30.0;
    final isSelected = node == selectedNode;
    final pulseEffect = isSelected ? (1.0 + 0.2 * math.sin(pulseAnimation * 2 * math.pi)) : 1.0;
    var nodeRadius = baseRadius * pulseEffect;
    if (isSelected) {
      nodeRadius += (isMobile ? 4.0 : 8.0) * selectionAnimation;
    }
    
    // Draw outer glow only for selected node
    if (isSelected) {
      final glowPaint = Paint()
        ..color = _getNodeColor(node).withValues(alpha: 0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.0);
      
      canvas.drawCircle(position, nodeRadius + 10, glowPaint);
    }
    
    // Draw shadow (static for all nodes)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    
    canvas.drawCircle(position + const Offset(3, 3), baseRadius, shadowPaint);
    
    // Draw gradient node with pulse effect for selected node
    final gradient = RadialGradient(
      colors: [
        _getNodeColor(node).withValues(alpha: 0.9),
        _getNodeColor(node),
        _getNodeColor(node).withValues(alpha: 0.7),
      ],
      stops: const [0.0, 0.7, 1.0],
    );
    
    final nodePaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: position, radius: nodeRadius))
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position, nodeRadius, nodePaint);
    
    // Draw inner highlight with pulse effect for selected node
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position - const Offset(8, 8), nodeRadius * 0.3, highlightPaint);
    
    // Draw selection ring with animation
    if (isSelected) {
      final ringPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 4.0 + (2.0 * selectionAnimation)
        ..style = PaintingStyle.stroke;
      
      canvas.drawCircle(position, nodeRadius + 8, ringPaint);
      
      // Draw pulsing outer ring
      final outerRingPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * (1.0 - selectionAnimation))
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      
      canvas.drawCircle(position, nodeRadius + 15 + (10 * selectionAnimation), outerRingPaint);
      
      // Draw revolving dots around selected node using the node's own color
      _drawRevolvingDots(canvas, position, nodeRadius + 25, _getNodeColor(node));
    }
    
    // Draw node label with responsive sizing
    final fontSize = isMobile 
        ? (isSelected ? 14.0 : 12.0) 
        : (isSelected ? 20.0 : 18.0);
    
    textPainter.text = TextSpan(
      text: node.label,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: Offset(1, 1),
            blurRadius: 3,
          ),
        ],
      ),
    );
    textPainter.layout();
    
    final textOffset = Offset(
      position.dx - textPainter.width / 2,
      position.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  void _drawRevolvingDots(Canvas canvas, Offset center, double radius, Color baseColor) {
    final isMobile = canvasSize.width < 600;
    final dotCount = isMobile ? 4 : 6;
    final dotRadius = isMobile ? 2.5 : 4.0;
    final rotationSpeed = pulseAnimation * 2 * math.pi;
    
    for (int i = 0; i < dotCount; i++) {
      final angle = (i * 2 * math.pi / dotCount) + rotationSpeed;
      final dotPosition = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      final dotPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(dotPosition, dotRadius, dotPaint);
      
      // Add glow effect to dots
      final glowPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      
      canvas.drawCircle(dotPosition, dotRadius + 2, glowPaint);
    }
  }

  void _drawParticleEffects(Canvas canvas, Offset? nodePosition) {
    // Remove orbiting particle effects to prevent blinking
    // Only nodes should have pulse animation, not surrounding particles
    return;
  }

  Color _getNodeColor(GraphNode node) {
    if (node.isRoot) {
      return const Color(0xFF10B981); // Emerald
    } else if (node.isLeaf) {
      return const Color(0xFFF59E0B); // Amber
    } else {
      return const Color(0xFF8B5CF6); // Violet
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class GraphVisualizationWidget extends StatefulWidget {
  final Map<int, List<GraphNode>> nodesByDepth;
  final GraphNode? selectedNode;
  final Function(GraphNode) onNodeTap;
  final GlobalKey? repaintKey;
  final bool exportMode; // when true, hide selection and animations for clean export

  const GraphVisualizationWidget({
    super.key,
    required this.nodesByDepth,
    required this.selectedNode,
    required this.onNodeTap,
    this.repaintKey,
    this.exportMode = false,
  });

  @override
  State<GraphVisualizationWidget> createState() => _GraphVisualizationWidgetState();
}

class _GraphVisualizationWidgetState extends State<GraphVisualizationWidget>
    with TickerProviderStateMixin {
  late AnimationController _selectionController;
  late AnimationController _pulseController;
  late AnimationController _connectionController;
  late Animation<double> _selectionAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _connectionAnimation;
  late TransformationController _transformController;
  final double _minScale = 0.01; // Allow extreme zoom out
  final double _maxScale = 100.0; // Allow extreme zoom in

  void _handleWheelZoom(PointerSignalEvent event, Size viewportSize) {
    if (event is! PointerScrollEvent) return;
    // Scroll up to zoom in, down to zoom out
    final dy = event.scrollDelta.dy;
    final scaleDelta = math.exp(-dy * 0.0015); // smooth zoom

    final m = _transformController.value.clone();
    final currentScale = m.getMaxScaleOnAxis();
    double newScale = (currentScale * scaleDelta).clamp(_minScale, _maxScale);
    final effectiveScaleDelta = newScale / currentScale;

    // Zoom around the pointer position (in viewport coordinates)
    final focal = event.localPosition;
    final Matrix4 next = m
      // ignore: deprecated_member_use
      ..translate(focal.dx, focal.dy)
      // ignore: deprecated_member_use
      ..scale(effectiveScaleDelta)
      // ignore: deprecated_member_use
      ..translate(-focal.dx, -focal.dy);
    _transformController.value = next;
  }
  
  @override
  void initState() {
    super.initState();
    
    _transformController = TransformationController();

    _selectionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _selectionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _selectionController,
      curve: Curves.elasticOut,
    ));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_pulseController);

    _connectionController = AnimationController(
      // Increased speed by another ~40% (from 2140ms to ~1530ms per cycle)
      duration: const Duration(milliseconds: 1530),
      vsync: this,
      )..repeat();
    _connectionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_connectionController);
    
    // Start animations if there's already a selected node on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedNode != null) {
        _selectionController.forward();
        _pulseController.repeat();
      }
    });
  }

  @override
  void didUpdateWidget(GraphVisualizationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedNode != widget.selectedNode) {
      _selectionController.reset();
      _selectionController.forward();
      
      // Only start pulse animation for selected node
      if (widget.selectedNode != null) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    _pulseController.dispose();
    _connectionController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate required width and height for scrolling using subtree width and depth
        double requiredWidth = constraints.maxWidth;
        double requiredHeight = constraints.maxHeight;
        if (widget.nodesByDepth.isNotEmpty) {
          final isMobile = constraints.maxWidth < 600;
          final nodeRadius = isMobile ? 20.0 : 30.0;
          final minNodeSpacing = nodeRadius * 2.5;
          final minVerticalSpacing = isMobile ? 80.0 : 110.0;

          // Determine root
          GraphNode? root;
          if (widget.nodesByDepth.containsKey(0) && widget.nodesByDepth[0]!.isNotEmpty) {
            root = widget.nodesByDepth[0]!.first;
          } else {
            for (final entry in widget.nodesByDepth.entries) {
              for (final n in entry.value) { if (n.parent == null) { root = n; break; } }
              if (root != null) break;
            }
          }

          double subtreeWidth(GraphNode node) {
            if (node.children.isEmpty) return math.max(minNodeSpacing, nodeRadius * 2);
            double total = 0.0;
            for (final c in node.children) { total += subtreeWidth(c); }
            total += (node.children.length - 1) * minNodeSpacing;
            return math.max(total, nodeRadius * 2);
          }

          // Compute depth for height
          int maxDepth = 0;
          widget.nodesByDepth.forEach((d, _) { maxDepth = math.max(maxDepth, d); });
          final neededHeight = (maxDepth + 2) * minVerticalSpacing + 100; // include top/bottom margins

          if (root != null) {
            final neededWidth = subtreeWidth(root) + 100; // side margins
            requiredWidth = math.max(constraints.maxWidth, neededWidth);
            requiredHeight = math.max(constraints.maxHeight, neededHeight);
          }
        }

        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final sceneSize = Size(requiredWidth, requiredHeight);
        final nodePositions = _calculateNodePositions(sceneSize);

        return Listener(
          onPointerSignal: (evt) => _handleWheelZoom(evt, viewportSize),
          child: Stack(
            children: [
              InteractiveViewer(
                transformationController: _transformController,
                minScale: _minScale,
                maxScale: _maxScale,
                scaleEnabled: true,
                panEnabled: true,
                panAxis: PanAxis.free,
                boundaryMargin: const EdgeInsets.all(10000),
                constrained: false,
                child: RepaintBoundary(
                  key: widget.repaintKey,
                  child: SizedBox(
                  width: sceneSize.width,
                  height: sceneSize.height,
                  child: GestureDetector(
                    onTapDown: (details) {
                      _handleTap(details.localPosition, sceneSize);
                    },
                    child: AnimatedBuilder(
                      animation: widget.exportMode
                          ? const AlwaysStoppedAnimation(0.0)
                          : (widget.selectedNode != null 
                              ? Listenable.merge([
                                  _selectionAnimation,
                                  _pulseAnimation,
                                  _connectionAnimation,
                                ])
                              : _connectionAnimation),
                      builder: (context, child) {
                        return CustomPaint(
                          size: sceneSize,
                          painter: AnimatedGraphPainter(
                            nodesByDepth: widget.nodesByDepth,
                            selectedNode: widget.exportMode ? null : widget.selectedNode,
                            onNodeTap: widget.onNodeTap,
                            canvasSize: sceneSize,
                            selectionAnimation: widget.exportMode ? 0.0 : _selectionAnimation.value,
                            pulseAnimation: widget.exportMode ? 0.0 : (widget.selectedNode != null ? _pulseAnimation.value : 0.0),
                            connectionAnimation: widget.exportMode ? 0.0 : _connectionAnimation.value,
                            backgroundColor: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: AnimatedBuilder(
                  animation: _transformController,
                  builder: (context, _) {
                    return _MiniMap(
                      size: const Size(140, 100),
                      sceneSize: sceneSize,
                      viewportSize: viewportSize,
                      transform: _transformController.value,
                      nodePositions: nodePositions,
                      onDoubleTap: () {
                        _resetToGraphBounds(viewportSize, sceneSize, nodePositions);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleTap(Offset tapPosition, Size size) {
    // Calculate node positions (same logic as in painter)
    Map<GraphNode, Offset> nodePositions = _calculateNodePositions(size);
    
    // Check if tap is within any node's bounds with larger tap radius for better selection
    final isMobile = size.width < 600;
    final baseNodeRadius = isMobile ? 20.0 : 30.0;
    final tapRadius = baseNodeRadius + 25.0; // Tap radius is node radius + 25px for easy selection
    
    // Find the closest node to the tap position
    GraphNode? closestNode;
    double closestDistance = double.infinity;
    
    nodePositions.forEach((node, position) {
      final distance = (tapPosition - position).distance;
      if (distance <= tapRadius && distance < closestDistance) {
        closestNode = node;
        closestDistance = distance;
      }
    });
    
    // Select the closest node if any was found within tap radius
    if (closestNode != null) {
      widget.onNodeTap(closestNode!);
    }
  }

  void _resetToGraphBounds(Size viewport, Size scene, Map<GraphNode, Offset> positions) {
    if (positions.isEmpty) return;
    double minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    positions.forEach((node, pos) {
      minX = math.min(minX, pos.dx);
      minY = math.min(minY, pos.dy);
      maxX = math.max(maxX, pos.dx);
      maxY = math.max(maxY, pos.dy);
    });
    final isMobile = viewport.width < 600;
    final nodeRadius = isMobile ? 20.0 : 30.0;
    final padding = nodeRadius * 2;
    final rect = Rect.fromLTRB(minX - padding, minY - padding, maxX + padding, maxY + padding);
    final scaleX = viewport.width / rect.width;
    final scaleY = viewport.height / rect.height;
    final targetScale = (math.min(scaleX, scaleY) * 0.9).clamp(_minScale, _maxScale);
    final tx = -rect.left * targetScale + (viewport.width - rect.width * targetScale) / 2;
    final ty = -rect.top * targetScale + (viewport.height - rect.height * targetScale) / 2;
    final m = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(tx, ty)
      // ignore: deprecated_member_use
      ..scale(targetScale);
    _transformController.value = m;
  }

  Map<GraphNode, Offset> _calculateNodePositions(Size size) {
    final positions = <GraphNode, Offset>{};
    if (widget.nodesByDepth.isEmpty) return positions;

    // Responsive spacing and node sizing (same as painter)
    final isMobile = size.width < 600;
    final nodeRadius = isMobile ? 20.0 : 30.0;
    final minNodeSpacing = nodeRadius * 2.5; // Minimum space between node centers
    final minVerticalSpacing = isMobile ? 100.0 : 140.0;

    // Determine root
    GraphNode? root;
    if (widget.nodesByDepth.containsKey(0) && widget.nodesByDepth[0]!.isNotEmpty) {
      root = widget.nodesByDepth[0]!.first;
    } else {
      for (final entry in widget.nodesByDepth.entries) {
        for (final n in entry.value) { if (n.parent == null) { root = n; break; } }
        if (root != null) break;
      }
    }
    if (root == null) return positions;

    // Compute depth to set vertical spacing
    int maxDepth = 0;
    widget.nodesByDepth.forEach((d, _) { maxDepth = math.max(maxDepth, d); });
    final availableHeight = size.height - 100; // margins
    final verticalSpacing = math.min(minVerticalSpacing, availableHeight / (maxDepth + 2));

    // First pass: subtree widths
    double subtreeWidth(GraphNode node) {
      if (node.children.isEmpty) return math.max(minNodeSpacing, nodeRadius * 2);
      double total = 0.0;
      for (final c in node.children) { total += subtreeWidth(c); }
      total += (node.children.length - 1) * minNodeSpacing;
      return math.max(total, nodeRadius * 2);
    }

    // Second pass: position nodes, centering parent over children
    void position(GraphNode node, double centerX, double y) {
      positions[node] = Offset(centerX, y);
      if (node.children.isEmpty) return;
      double totalChildrenWidth = 0.0;
      final childWidths = <double>[];
      for (final c in node.children) { final w = subtreeWidth(c); childWidths.add(w); totalChildrenWidth += w; }
      totalChildrenWidth += (node.children.length - 1) * minNodeSpacing;
      double currentX = centerX - totalChildrenWidth / 2;
      for (int i = 0; i < node.children.length; i++) {
        final cw = childWidths[i];
        final childCenter = currentX + cw / 2;
        position(node.children[i], childCenter, y + verticalSpacing);
        currentX += cw + minNodeSpacing;
      }
    }

    // Root X centered within canvas with margins
    final margin = 50.0;
    final rootCenterX = (size.width / 2).clamp(margin, size.width - margin);
    final startY = math.min(50.0 + nodeRadius, size.height - 50.0);
    position(root, rootCenterX, startY);

    return positions;
  }
}

class _MiniMap extends StatelessWidget {
  final Size size;
  final Size sceneSize;
  final Size viewportSize;
  final Matrix4 transform;
  final Map<GraphNode, Offset> nodePositions;
  final VoidCallback onDoubleTap;

  const _MiniMap({
    super.key,
    required this.size,
    required this.sceneSize,
    required this.viewportSize,
    required this.transform,
    required this.nodePositions,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: 'Double-tap to reset view',
        waitDuration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onDoubleTap: onDoubleTap,
          child: CustomPaint(
            size: size,
            painter: _MiniMapPainter(
              sceneSize: sceneSize,
              viewportSize: viewportSize,
              transform: transform,
              nodePositions: nodePositions,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  final Size sceneSize;
  final Size viewportSize;
  final Matrix4 transform;
  final Map<GraphNode, Offset> nodePositions;

  _MiniMapPainter({
    required this.sceneSize,
    required this.viewportSize,
    required this.transform,
    required this.nodePositions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background panel
    final bg = Paint()..color = Colors.black.withAlpha(100);
    final border = Paint()
      ..color = Colors.white.withAlpha(180)
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawRRect(rrect, bg);
    canvas.drawRRect(rrect, border);

    if (nodePositions.isEmpty || sceneSize.width == 0 || sceneSize.height == 0) return;

    // Fit scene into minimap
    final scaleX = size.width / sceneSize.width;
    final scaleY = size.height / sceneSize.height;
    final s = math.min(scaleX, scaleY);
    final offset = Offset(
      (size.width - sceneSize.width * s) / 2,
      (size.height - sceneSize.height * s) / 2,
    );

    // Draw nodes as tiny dots
    final dot = Paint()..color = Colors.white.withAlpha(220);
    for (final pos in nodePositions.values) {
      final p = Offset(pos.dx * s, pos.dy * s) + offset;
      canvas.drawCircle(p, 1.5, dot);
    }

    // Draw current viewport rectangle (scaled properly and constrained to minimap bounds)
    // Inverse transform to map viewport corners into scene space
    final inv = Matrix4.copy(transform);
    final det = inv.invert();
    if (det != 0.0) {
      final topLeftScene = MatrixUtils.transformPoint(inv, Offset.zero);
      final bottomRightScene = MatrixUtils.transformPoint(
        inv,
        Offset(viewportSize.width, viewportSize.height),
      );
      
      // Scale the viewport rectangle to match the minimap scale
      final scaledTopLeft = Offset(topLeftScene.dx * s, topLeftScene.dy * s) + offset;
      final scaledBottomRight = Offset(bottomRightScene.dx * s, bottomRightScene.dy * s) + offset;
      
      // Constrain the rectangle to minimap bounds to prevent overflow
      final minimapBounds = Rect.fromLTWH(0, 0, size.width, size.height);
      final constrainedTopLeft = Offset(
        scaledTopLeft.dx.clamp(minimapBounds.left, minimapBounds.right),
        scaledTopLeft.dy.clamp(minimapBounds.top, minimapBounds.bottom),
      );
      final constrainedBottomRight = Offset(
        scaledBottomRight.dx.clamp(minimapBounds.left, minimapBounds.right),
        scaledBottomRight.dy.clamp(minimapBounds.top, minimapBounds.bottom),
      );
      
      // Ensure the rectangle is visible and properly scaled
      final rect = Rect.fromPoints(constrainedTopLeft, constrainedBottomRight);
      
      // Only draw if the rectangle has valid dimensions
      if (rect.width > 0 && rect.height > 0) {
        final vpPaint = Paint()
          ..color = Colors.cyan.withAlpha(120)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawRect(rect, vpPaint);
        
        // Add a subtle fill to make it more visible
        final fillPaint = Paint()
          ..color = Colors.cyan.withAlpha(30)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.nodePositions.length != nodePositions.length ||
        oldDelegate.sceneSize != sceneSize ||
        oldDelegate.viewportSize != viewportSize;
  }
}

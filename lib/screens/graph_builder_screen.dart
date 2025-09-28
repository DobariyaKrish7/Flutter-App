import 'package:flutter/material.dart';
import 'dart:ui' as ui show ImageByteFormat;
import 'package:flutter/rendering.dart';
import '../utils/save_image_platform.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../controllers/graph_controller.dart';
import '../widgets/graph_painter.dart';

class GraphBuilderScreen extends StatefulWidget {
  const GraphBuilderScreen({super.key});

  @override
  State<GraphBuilderScreen> createState() => _GraphBuilderScreenState();
}

class _GraphBuilderScreenState extends State<GraphBuilderScreen> {
  late GraphController _controller;
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchResults = [];
  final GlobalKey _repaintKey = GlobalKey();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _controller = GraphController();
  }

  void _showResetConfirmation(BuildContext context, GraphController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white.withValues(alpha: 0.95),
          title: Row(
            children: [
              Icon(Icons.refresh, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Text('Reset Graph'),
            ],
          ),
          content: const Text('Are you sure you want to reset the entire graph? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Cancel'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    controller.resetGraph();
                  });
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Reset', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportPng() async {
    if (_isExporting) return;
    setState(() { _isExporting = true; });
    try {
      // Ensure the frame is rendered before capturing
      await WidgetsBinding.instance.endOfFrame;
      // Find the render object
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to export yet. Try again.')),
        );
        return;
      }

      // Choose a safe pixel ratio (web fails if readPixels exceeds caps)
      final rbSize = boundary.size;
      final maxDim = math.max(rbSize.width, rbSize.height);
      double pixelRatio = 3.0;
      final webMax = 4096.0; // conservative
      final ioMax = 8000.0;
      final allowed = (kIsWeb ? webMax : ioMax) / (maxDim == 0 ? 1 : maxDim);
      pixelRatio = math.min(pixelRatio, allowed);
      if (pixelRatio < 0.3) pixelRatio = 0.3;

      // Render to image
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final savedWhere = await ImageSaver.saveBytes(pngBytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image exported: $savedWhere')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() { _isExporting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Graph Builder', 
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: 1.2,
            fontFamily: 'serif',
          )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Undo button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF61a5c2).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF468faf).withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.undo, 
                    color: _controller.canUndo ? Colors.white : Colors.white54),
                  onPressed: _controller.canUndo ? () {
                    setState(() {
                      _controller.undo();
                    });
                  } : null,
                  tooltip: 'Undo',
                ),
                Text(
                  'Undo',
                  style: TextStyle(
                    color: _controller.canUndo ? Colors.white : Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Redo button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF61a5c2).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF468faf).withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.redo, 
                    color: _controller.canRedo ? Colors.white : Colors.white54),
                  onPressed: _controller.canRedo ? () {
                    setState(() {
                      _controller.redo();
                    });
                  } : null,
                  tooltip: 'Redo',
                ),
                Text(
                  'Redo',
                  style: TextStyle(
                    color: _controller.canRedo ? Colors.white : Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Search button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF61a5c2).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF468faf).withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {
                    _showSearchDialog();
                  },
                  tooltip: 'Search Nodes',
                ),
                const Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Reset button
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF61a5c2).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF468faf).withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => _showResetConfirmation(context, _controller),
                  tooltip: 'Reset Graph',
                ),
                const Text(
                  'Reset',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
       body: Container(
         decoration: const BoxDecoration(
           // Page background gradient using #01497c as base color
           gradient: LinearGradient(
             begin: Alignment.topLeft,
             end: Alignment.bottomRight,
             colors: [
               Color(0xFF01497c),
               Color(0xFF012a4a),
               Color(0xFF01497c),
               Color(0xFF026aa7),
             ],
             stops: [0.0, 0.3, 0.7, 1.0],
           ),
         ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 600;
            
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: isWideScreen
                  ? _buildWideLayout(context, _controller, constraints)
                  : _buildNarrowLayout(context, _controller, constraints),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, GraphController controller, BoxConstraints constraints) {
    return Row(
      children: [
        // Graph visualization area
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 100, 8, 16),
            decoration: BoxDecoration(
              color: Colors.transparent, // Transparent to show infinite background
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: GraphVisualizationWidget(
                nodesByDepth: controller.getNodesByDepth(),
                selectedNode: controller.selectedNode,
                onNodeTap: (node) {
                  setState(() {
                    controller.selectNode(node);
                  });
                },
                repaintKey: _repaintKey,
                exportMode: _isExporting,
              ),
            ),
          ),
        ),
        // Control panel
        Container(
          width: 320,
          margin: const EdgeInsets.fromLTRB(8, 100, 16, 16),
          child: _buildGlassmorphicControlPanel(context, controller),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, GraphController controller, BoxConstraints constraints) {
    return Column(
      children: [
        // Control panel at top for mobile
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 100, 16, 8),
          child: _buildGlassmorphicMobileControlPanel(context, controller),
        ),
        // Graph visualization area
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Colors.transparent, // Transparent to show infinite background
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: GraphVisualizationWidget(
                nodesByDepth: controller.getNodesByDepth(),
                selectedNode: controller.selectedNode,
                onNodeTap: (node) {
                  setState(() {
                    controller.selectNode(node);
                  });
                },
                repaintKey: _repaintKey,
                exportMode: _isExporting,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassmorphicControlPanel(BuildContext context, GraphController controller) {
    return Container(
      decoration: BoxDecoration(
         color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
         borderRadius: BorderRadius.circular(24),
         border: Border.all(color: const Color(0xFF61a5c2).withValues(alpha: 0.4)),
         boxShadow: [
           BoxShadow(
             color: const Color(0xFF61a5c2).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Controls',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.8,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildEnhancedSelectedNodeInfo(context, controller),
                  const SizedBox(height: 24),
                  _buildEnhancedActionButtons(context, controller),
                  const SizedBox(height: 20),
                  _buildCompactEnhancedLegend(context),
                  const SizedBox(height: 8), // Reduced bottom padding
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassmorphicMobileControlPanel(BuildContext context, GraphController controller) {
    return Container(
      decoration: BoxDecoration(
         color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
         borderRadius: BorderRadius.circular(20),
         border: Border.all(color: const Color(0xFF61a5c2).withValues(alpha: 0.4)),
         boxShadow: [
           BoxShadow(
             color: const Color(0xFF61a5c2).withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildEnhancedSelectedNodeInfo(context, controller)),
                    const SizedBox(width: 16),
                    _buildEnhancedMobileActionButtons(context, controller),
                  ],
                ),
                const SizedBox(height: 16),
                _buildEnhancedMobileLegend(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedSelectedNodeInfo(BuildContext context, GraphController controller) {
    final selectedNode = controller.selectedNode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Selected Node',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  fontFamily: 'sans-serif',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedNode != null) ...[
            _buildInfoRow('Label', selectedNode.label, Icons.label),
            _buildInfoRow('Depth', selectedNode.getDepth().toString(), Icons.layers),
            _buildInfoRow('Children', selectedNode.children.length.toString(), Icons.account_tree),
            _buildInfoRow('Type', selectedNode.isRoot ? 'Root' : selectedNode.isLeaf ? 'Leaf' : 'Branch', Icons.category),
          ] else
            Row(
              children: [
                Icon(Icons.touch_app, color: Colors.white.withValues(alpha: 0.6), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Tap a node to select',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedActionButtons(BuildContext context, GraphController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: controller.selectedNode != null && controller.selectedNode!.getDepth() < 99
                ? () {
                    setState(() {
                      controller.addChildNode();
                    });
                  }
                : null,
            icon: const Icon(Icons.add_circle, color: Colors.white),
            label: const Text('Add Child Node', style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 0.3,
              fontFamily: 'sans-serif',
            )),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF44336), Color(0xFFD32F2F)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: controller.selectedNode != null && !controller.selectedNode!.isRoot
                ? () => _showDeleteConfirmation(context, controller)
                : null,
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text('Delete Node', style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 0.3,
              fontFamily: 'sans-serif',
            )),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _exportPng,
            icon: const Icon(Icons.image_outlined, color: Colors.white),
            label: const Text('Export PNG', style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 0.3,
              fontFamily: 'sans-serif',
            )),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedMobileActionButtons(BuildContext context, GraphController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: controller.selectedNode != null && controller.selectedNode!.getDepth() < 99
                ? () {
                    setState(() {
                      controller.addChildNode();
                    });
                  }
                : null,
            icon: const Icon(Icons.add_circle, color: Colors.white),
            tooltip: 'Add Child',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF44336), Color(0xFFD32F2F)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: controller.selectedNode != null && !controller.selectedNode!.isRoot
                ? () => _showDeleteConfirmation(context, controller)
                : null,
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: 'Delete Node',
          ),
        ),
      ],
    );
  }

  Widget _buildCompactEnhancedLegend(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.legend_toggle,
                color: Colors.white.withValues(alpha: 0.8),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Legend',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.4,
                  fontFamily: 'cursive',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCompactLegendItem(Colors.green, 'Root', Icons.home),
          const SizedBox(height: 4),
          _buildCompactLegendItem(Colors.purple, 'Branch', Icons.account_tree),
          const SizedBox(height: 4),
          _buildCompactLegendItem(Colors.orange, 'Leaf', Icons.circle),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app, color: Colors.white.withValues(alpha: 0.6), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tap nodes to select',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLegendItem(Color color, String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 10),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }


  Widget _buildEnhancedMobileLegend(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _buildEnhancedLegendItem(Colors.green, 'Root', Icons.home),
          _buildEnhancedLegendItem(Colors.purple, 'Branch', Icons.account_tree),
          _buildEnhancedLegendItem(Colors.orange, 'Leaf', Icons.circle),
        ],
      ),
    );
  }

  Widget _buildEnhancedLegendItem(Color color, String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 12),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, GraphController controller) {
    final nodeToDelete = controller.selectedNode!;
    final childCount = nodeToDelete.getAllDescendants().length;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white.withValues(alpha: 0.95),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('Delete Node'),
            ],
          ),
          content: Text(
            childCount > 0
                ? 'Are you sure you want to delete node "${nodeToDelete.label}" and its $childCount descendant(s)?'
                : 'Are you sure you want to delete node "${nodeToDelete.label}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Cancel'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF44336), Color(0xFFD32F2F)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    controller.deleteNode(nodeToDelete);
                  });
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Search functionality
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white.withValues(alpha: 0.95),
              title: Row(
                children: [
                  const Icon(Icons.search, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text('Search Nodes'),
                ],
              ),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Enter node label to search...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          final results = _controller.searchNodes(value);
                          _searchResults = results.map((node) => node.id).toList();
                        });
                      },
                      onSubmitted: (value) {
                        // When Enter is pressed, select the first search result if available
                        if (_searchResults.isNotEmpty) {
                          final firstNodeId = _searchResults[0];
                          final firstNode = _controller.rootNode.findNodeById(firstNodeId);
                          if (firstNode != null) {
                            setState(() {
                              _controller.selectNode(firstNode);
                            });
                            _searchController.clear();
                            _searchResults.clear();
                            Navigator.of(context).pop();
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_searchResults.isNotEmpty) ...[
                      const Text('Search Results:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final nodeId = _searchResults[index];
                            final node = _controller.rootNode.findNodeById(nodeId);
                            return ListTile(
                              leading: Icon(
                                node?.isRoot == true ? Icons.home :
                                node?.isLeaf == true ? Icons.circle : Icons.account_tree,
                                color: node?.isRoot == true ? Colors.green :
                                       node?.isLeaf == true ? Colors.orange : Colors.purple,
                              ),
                              title: Text('Node ${node?.label}'),
                              subtitle: Text('ID: ${node?.id}'),
                              onTap: () {
                                if (node != null) {
                                  setState(() {
                                    _controller.selectNode(node);
                                  });
                                  Navigator.of(context).pop();
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ] else if (_searchController.text.isNotEmpty) ...[
                      const Text('No nodes found', style: TextStyle(color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Select first result if available, same as Enter key
                    if (_searchResults.isNotEmpty) {
                      final firstNodeId = _searchResults[0];
                      final firstNode = _controller.rootNode.findNodeById(firstNodeId);
                      if (firstNode != null) {
                        setState(() {
                          _controller.selectNode(firstNode);
                        });
                        _searchController.clear();
                        _searchResults.clear();
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  child: const Text('OK'),
                ),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _searchResults.clear();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

}

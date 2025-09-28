import '../models/node.dart';

class GraphState {
  final GraphNode rootNode;
  final GraphNode? selectedNode;
  final int nextNodeId;
  
  GraphState({
    required this.rootNode,
    required this.selectedNode,
    required this.nextNodeId,
  });
  
  GraphState copyWith({
    GraphNode? rootNode,
    GraphNode? selectedNode,
    int? nextNodeId,
  }) {
    return GraphState(
      rootNode: rootNode ?? this.rootNode.deepCopy(),
      selectedNode: selectedNode ?? this.selectedNode,
      nextNodeId: nextNodeId ?? this.nextNodeId,
    );
  }
}

class GraphController {
  late GraphNode _rootNode;
  GraphNode? _selectedNode;
  int _nextNodeId = 2; // Start from 2 since root is "1"
  
  // Undo/Redo functionality
  final List<GraphState> _history = [];
  int _historyIndex = -1;
  final int _maxHistorySize = 50;

  GraphController() {
    // Initialize with root node labeled "1"
    _rootNode = GraphNode(id: '1', label: '1');
    _selectedNode = _rootNode;
    _saveState();
  }

  // Getters
  GraphNode get rootNode => _rootNode;
  GraphNode? get selectedNode => _selectedNode;
  int get nextNodeId => _nextNodeId;

  // Select a node
  void selectNode(GraphNode node) {
    // Always select the provided node
    _selectedNode = node;
  }

  // Save current state to history
  void _saveState() {
    // Remove any states after current index (for redo functionality)
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    
    // Add current state
    final state = GraphState(
      rootNode: _rootNode.deepCopy(),
      selectedNode: _selectedNode,
      nextNodeId: _nextNodeId,
    );
    
    _history.add(state);
    _historyIndex++;
    
    // Limit history size
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  // Add a child node to the currently selected node
  void addChildNode() {
    if (_selectedNode == null) return;
    
    // Check maximum depth constraint (100)
    if (_selectedNode!.getDepth() >= 99) {
      // Can't add child as it would exceed max depth of 100
      return;
    }

    final newNode = GraphNode(
      id: _nextNodeId.toString(),
      label: _nextNodeId.toString(),
    );
    
    _selectedNode!.addChild(newNode);
    _nextNodeId++;
    _saveState();
  }

  // Delete a node and all its descendants
  void deleteNode(GraphNode nodeToDelete) {
    // Can't delete the root node
    if (nodeToDelete.isRoot) return;

    // If we're deleting the selected node, select its parent
    if (_selectedNode == nodeToDelete) {
      _selectedNode = nodeToDelete.parent;
    } else {
      // Check if selected node is a descendant of the node being deleted
      GraphNode? current = _selectedNode;
      while (current != null) {
        if (current == nodeToDelete) {
          _selectedNode = nodeToDelete.parent;
          break;
        }
        current = current.parent;
      }
    }

    nodeToDelete.removeFromParent();
    _saveState();
  }

  // Undo last operation
  bool undo() {
    if (_historyIndex <= 0) return false;
    
    _historyIndex--;
    final state = _history[_historyIndex];
    
    _rootNode = state.rootNode.deepCopy();
    _nextNodeId = state.nextNodeId;
    
    // Find the selected node in the new tree
    if (state.selectedNode != null) {
      _selectedNode = _rootNode.findNodeById(state.selectedNode!.id);
    } else {
      _selectedNode = null;
    }
    
    return true;
  }

  // Redo last undone operation
  bool redo() {
    if (_historyIndex >= _history.length - 1) return false;
    
    _historyIndex++;
    final state = _history[_historyIndex];
    
    _rootNode = state.rootNode.deepCopy();
    _nextNodeId = state.nextNodeId;
    
    // Find the selected node in the new tree
    if (state.selectedNode != null) {
      _selectedNode = _rootNode.findNodeById(state.selectedNode!.id);
    } else {
      _selectedNode = null;
    }
    
    return true;
  }

  // Check if undo is available
  bool get canUndo => _historyIndex > 0;

  // Check if redo is available
  bool get canRedo => _historyIndex < _history.length - 1;

  // Search for nodes by label
  List<GraphNode> searchNodes(String query) {
    if (query.isEmpty) return [];
    
    final results = <GraphNode>[];
    final allNodes = getAllNodes();
    
    for (final node in allNodes) {
      if (node.label.toLowerCase().contains(query.toLowerCase())) {
        results.add(node);
      }
    }
    
    return results;
  }

  // Get all nodes in the graph (for rendering)
  List<GraphNode> getAllNodes() {
    List<GraphNode> allNodes = [_rootNode];
    allNodes.addAll(_rootNode.getAllDescendants());
    return allNodes;
  }

  // Reset the graph to initial state
  void resetGraph() {
    _rootNode = GraphNode(id: '1', label: '1');
    _selectedNode = _rootNode;
    _nextNodeId = 2;

    // Reset undo/redo history as well
    _history.clear();
    _historyIndex = -1;
    _saveState();
  }

  // Get nodes by depth level (for layout purposes)
  Map<int, List<GraphNode>> getNodesByDepth() {
    Map<int, List<GraphNode>> nodesByDepth = {};
    
    void addNodeToDepthMap(GraphNode node) {
      int depth = node.getDepth();
      nodesByDepth.putIfAbsent(depth, () => []);
      nodesByDepth[depth]!.add(node);
      
      for (GraphNode child in node.children) {
        addNodeToDepthMap(child);
      }
    }
    
    addNodeToDepthMap(_rootNode);
    return nodesByDepth;
  }
}

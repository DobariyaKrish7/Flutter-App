class GraphNode {
  final String id;
  final String label;
  final List<GraphNode> children;
  GraphNode? parent;
  
  GraphNode({
    required this.id,
    required this.label,
    this.parent,
    List<GraphNode>? children,
  }) : children = children ?? [];

  // Add a child node to this node
  void addChild(GraphNode child) {
    child.parent = this;
    children.add(child);
  }

  // Remove a child node from this node
  void removeChild(GraphNode child) {
    child.parent = null;
    children.remove(child);
  }

  // Remove this node and all its descendants
  void removeFromParent() {
    parent?.removeChild(this);
  }

  // Get all descendant nodes (children, grandchildren, etc.)
  List<GraphNode> getAllDescendants() {
    List<GraphNode> descendants = [];
    for (GraphNode child in children) {
      descendants.add(child);
      descendants.addAll(child.getAllDescendants());
    }
    return descendants;
  }

  // Get the depth of this node (root = 0)
  int getDepth() {
    int depth = 0;
    GraphNode? current = parent;
    while (current != null) {
      depth++;
      current = current.parent;
    }
    return depth;
  }

  // Check if this node is a leaf (has no children)
  bool get isLeaf => children.isEmpty;

  // Check if this node is the root (has no parent)
  bool get isRoot => parent == null;

  // Create a deep copy of this node and all its descendants
  GraphNode deepCopy({GraphNode? newParent}) {
    final copy = GraphNode(
      id: id,
      label: label,
      parent: newParent,
    );
    
    for (GraphNode child in children) {
      copy.addChild(child.deepCopy(newParent: copy));
    }
    
    return copy;
  }
  
  // Find a node by ID in this subtree
  GraphNode? findNodeById(String nodeId) {
    if (id == nodeId) return this;
    
    for (GraphNode child in children) {
      final found = child.findNodeById(nodeId);
      if (found != null) return found;
    }
    
    return null;
  }

  @override
  String toString() => 'GraphNode(id: $id, label: $label, children: ${children.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GraphNode && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

# Graph Builder

A Flutter application for creating and managing graph structures with a modern, responsive UI.

## Features

### 🎯 Core Functionality
- **Interactive Graph Visualization**: Create and manage graph structures with smooth animations
- **Node Management**: Add child nodes, delete nodes with cascade deletion, and select nodes for editing
- **Undo/Redo System**: Full undo/redo functionality with state management for all graph operations
- **Search Functionality**: Search nodes by label with real-time results and quick selection
- **Graph Reset with Confirmation**: Reset the entire graph with a confirmation dialog
- **Export PNG**: Export the current graph view to a high-resolution PNG
- **Zoom & Pan**: Seamless zoom (mouse wheel) and pan (drag) across an infinite canvas
- **Mini-map**: Always-on overview with viewport indicator and double-tap to recenter

### 🎨 Visual Design
- **Modern UI**: Material 3 design with glassmorphic effects and gradient backgrounds
- **Color-Coded Nodes**: 
  - 🟢 **Green**: Root nodes
  - 🟣 **Purple**: Branch nodes (have children)
  - 🟠 **Orange**: Leaf nodes (no children)
- **Smooth Animations**: Node selection animations, moving particles along connections, and UI transitions
- **Responsive Layout**: Adapts to different screen sizes (desktop and mobile)

### 📱 Responsive Design
- **Desktop Layout**: Side-by-side layout with graph visualization and control panel
- **Mobile Layout**: Stacked layout optimized for smaller screens
- **Adaptive Controls**: Button layouts adjust based on screen size

### 🎮 User Interface Elements
- **AppBar Controls**: 
  - Undo button with "Undo" label
  - Redo button with "Redo" label  
  - Search button with "Search" label
  - Reset button with "Reset" label (shows confirmation dialog)
- **Control Panel**: Node information display and action buttons
- **Interactive Legend**: Visual guide for node types and interactions

## Technical Architecture

### 🏗️ Project Structure
```
lib/
├── main.dart                    # App entry point with Provider setup
├── models/
│   └── node.dart               # GraphNode data model
├── controllers/
│   └── graph_controller.dart   # State management and business logic
├── screens/
│   └── graph_builder_screen.dart # Main UI screen with responsive layouts
└── widgets/
    └── graph_painter.dart      # Custom graph visualization widget
```

### 🔧 Key Components

#### GraphNode Model
- Unique ID generation for each node
- Hierarchical structure with parent-child relationships
- Depth calculation and node type detection
- Cascade deletion support

#### GraphController
- Provider-based state management
- Undo/redo stack implementation
- Node selection and manipulation
- Search functionality
- Maximum depth enforcement (100 levels)

#### Custom Graph Painter
- Custom painting for graph visualization
- Node positioning algorithms
- Connection line drawing
- Animation support for selections

### 🎯 State Management
- **Provider Pattern**: Used for reactive state management
- **Undo/Redo System**: Command pattern implementation for reversible operations
- **Node Selection**: Single node selection with visual feedback

## Usage Instructions

### Basic Operations
1. **Adding Nodes**: Select a node and click "Add Child Node" to create children
2. **Deleting Nodes**: Select a non-root node and click "Delete Node" (cascades to children)
3. **Node Selection**: Tap/click any node to select it and view its information
4. **Undo/Redo**: Use the undo/redo buttons to reverse or restore operations
5. **Search**: Click the search button to find nodes by label
6. **Reset**: Click the reset button, confirm in the dialog to clear the entire graph
7. **Zoom & Pan**:
   - Mouse wheel to zoom in/out (smooth exponential scaling)
   - Click-drag to pan the canvas
8. **Mini-map**:
   - View current position/zoom as a cyan rectangle
   - Double-tap the mini-map to recenter and fit the graph in view
9. **Export PNG**:
   - Click "Export PNG"; on success a snackbar shows the saved path/location

### Node Information Display
- **Label**: Auto-generated unique identifier
- **Depth**: Level in the tree hierarchy
- **Children Count**: Number of direct children
- **Type**: Root, Branch, or Leaf classification

### Keyboard Shortcuts
- **Enter**: In search dialog, selects the first search result
- **Escape**: Closes dialogs

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
```

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- IDE with Flutter support (VS Code, Android Studio, etc.)

### Installation
1. Clone the repository
2. Navigate to the project directory
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the application

### Supported Platforms
- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## Features in Detail

### Graph Visualization
- **Tree Layout**: Hierarchical arrangement with proper spacing
- **Connection Lines**: Visual connections between parent and child nodes
- **Node Styling**: Circular nodes with gradients and shadows
- **Selection Feedback**: Visual highlighting of selected nodes

### Navigation & Camera
- **Infinite Canvas**: Pan freely in any direction; background fills the extended plane
- **Smooth Wheel Zoom**: Zoom centered around the pointer position
- **Fit to Graph**: Mini-map supports double-tap to fit the entire graph into the viewport

### Mini-map & Viewport
- Compact overview of the whole scene with node dots
- Cyan rectangle indicates the current viewport
- Double-tap to reset view to graph bounds

### Animations
- Node selection pulse and highlight rings
- Moving particles along connection lines with constant speed on both horizontal and vertical segments
- Revolving dots around the selected node

### Exporting
- Export the current scene to PNG at a safe pixel ratio
- Adaptive limits on web vs. desktop to avoid GPU readback issues
- Snackbar feedback with the save location

### Confirmation Dialogs
- Delete Node: Warns about deleting the node and its descendant count
- Reset Graph: Confirms clearing the entire graph before proceeding

### Responsive Behavior
- **Wide Screen (>600px)**: Side-by-side layout with detailed control panel
- **Narrow Screen (≤600px)**: Stacked layout with compact controls
- **Adaptive Text**: Font sizes and spacing adjust to screen size

### Error Handling
- **Maximum Depth**: Prevents infinite nesting (100 level limit)
- **Root Protection**: Root node cannot be deleted
- **Validation**: Input validation for all operations

### Performance Optimizations
- **Efficient Rendering**: Custom painter for optimal graph drawing
- **State Management**: Minimal rebuilds with Provider
- **Memory Management**: Proper disposal of controllers and resources

## Contributing

This project follows Flutter best practices and Material Design guidelines. When contributing:

1. Follow the existing code structure and naming conventions
2. Add appropriate comments for complex logic
3. Test on multiple screen sizes and platforms
4. Ensure accessibility compliance
5. Update documentation for new features

## License

This project is created as a demonstration of Flutter development capabilities.

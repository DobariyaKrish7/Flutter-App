import 'package:flutter/material.dart';
import 'screens/graph_builder_screen.dart';

void main() {
  runApp(const GraphBuilderApp());
}

class GraphBuilderApp extends StatelessWidget {
  const GraphBuilderApp({super.key});

  ThemeData _buildResponsiveTheme(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final isDesktop = screenSize.width >= 1200;
    final isMobile = screenSize.width < 600;
    
    // Responsive font sizes
    final titleFontSize = isDesktop ? 28.0 : isTablet ? 26.0 : 24.0;
    final buttonPadding = isDesktop 
        ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
        : isTablet 
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    
    // Responsive border radius
    final borderRadius = isDesktop ? 20.0 : isTablet ? 18.0 : 16.0;
    final cardBorderRadius = isDesktop ? 24.0 : isTablet ? 22.0 : 20.0;
    
    // Responsive elevation
    final elevation = isDesktop ? 12.0 : isTablet ? 10.0 : 8.0;
    final cardElevation = isDesktop ? 16.0 : isTablet ? 14.0 : 12.0;

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: titleFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        toolbarHeight: isDesktop ? 80 : isTablet ? 70 : 60,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: elevation,
          shadowColor: Colors.black26,
          padding: buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: TextStyle(
            fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: cardElevation,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(cardBorderRadius)),
        ),
        margin: EdgeInsets.all(isDesktop ? 16 : isTablet ? 12 : 8),
      ),
      iconTheme: IconThemeData(
        size: isDesktop ? 28 : isTablet ? 26 : 24,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: isDesktop ? 32 : isTablet ? 30 : 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          fontSize: isDesktop ? 28 : isTablet ? 26 : 24,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontSize: isDesktop ? 22 : isTablet ? 20 : 18,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: TextStyle(
          fontSize: isDesktop ? 18 : isTablet ? 17 : 16,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
        ),
        bodyMedium: TextStyle(
          fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
        ),
        bodySmall: TextStyle(
          fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
        ),
      ),
      // Responsive spacing for various components
      visualDensity: isDesktop 
          ? VisualDensity.comfortable 
          : isMobile 
              ? VisualDensity.compact 
              : VisualDensity.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graph Builder',
      theme: _buildResponsiveTheme(context),
      home: const GraphBuilderScreen(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Ensure responsive theme updates on orientation changes
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).size.width < 600 ? 0.9 : 1.0,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

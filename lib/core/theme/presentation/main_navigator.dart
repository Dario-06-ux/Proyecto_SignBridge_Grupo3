import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importamos las dos pantallas reales usando RUTAS ABSOLUTAS (package:)
// Actualizado al nombre correcto (camera_screen.dart)
import 'package:detector_senas/features/camera_translator/presentation/camera_screen.dart';
import 'package:detector_senas/features/chatbot/presentation/chatbot_screen.dart';

class MainNavigator extends ConsumerStatefulWidget {
  const MainNavigator({super.key});

  @override
  ConsumerState<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends ConsumerState<MainNavigator> {
  int _selectedIndex = 1; // Lo ponemos en 1 para que abra el chat por defecto al iniciar

  // Lista de pantallas reales conectadas
  final List<Widget> _screens = [
    const CameraScreen(),   // Índice 0: Traductor (Cámara)
    const ChatbotScreen(),  // Índice 1: Chatbot (Texto)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam_rounded),
            label: 'Visión',
            tooltip: 'Traductor por cámara (MediaPipe en Android)',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
            tooltip: 'Asistente y ejemplos en GIF',
          ),
        ],
      ),
    );
  }
}
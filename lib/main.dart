import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'ganado_screen.dart';
import 'sanidad_screen.dart';
import 'reproduccion_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GanaderoProApp());
}

class GanaderoProApp extends StatelessWidget {
  const GanaderoProApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GanaderoPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Lista de las 4 pantallas principales de la aplicación
  final List<Widget> _screens = [
    const DashboardScreen(),
    const GanadoScreen(),
    const SanidadScreen(),
    const ReproduccionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: 'Ganado',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Sanidad',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Reproducción',
          ),
        ],
      ),
    );
  }
}
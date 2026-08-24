import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // <-- 1. Importar localizaciones
import 'theme/app_theme.dart';
import 'screens/mi_finca_screen.dart';
import 'screens/ganado_screen.dart';
import 'screens/sanidad_screen.dart';
import 'screens/reproduccion_screen.dart';
import 'screens/produccion_screen.dart';
import 'screens/finanzas_screen.dart';
import 'screens/inventario_screen.dart';
import 'screens/configuracion_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GanaderoProApp());
}

class GanaderoProApp extends StatelessWidget {
  const GanaderoProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GanaderoPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // 2. Configurar los delegados de localización
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 3. Definir los idiomas soportados (español por defecto)
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'ES'), // <-- Forzar idioma español
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Las 4 pantallas principales controladas exclusivamente por la barra inferior
  final List<Widget> _screens = [
    const MiFincaScreen(),
    const GanadoScreen(),
    const SanidadScreen(),
    const ReproduccionScreen(),
  ];

  // Método para abrir módulos secundarios desde el Drawer de forma independiente
  void _navegarA(Widget pantalla, String titulo) {
    Navigator.pop(context); // Cierra el drawer

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(titulo),
          ),
          body: pantalla,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_obtenerTituloBarra(_currentIndex)),
      ),
      // Menú lateral (Drawer) con acceso a todos los módulos
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppTheme.obtenerIcono(AppTheme.iconoGanado, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    'GanaderoPro',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Gestión Integral de Fincas',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(AppTheme.iconoMiFinca, color: AppTheme.primaryGreen),
              title: const Text('Mi Finca'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            ListTile(
              leading: AppTheme.obtenerIcono(AppTheme.iconoGanado, color: AppTheme.primaryGreen, size: 24),
              title: const Text('Ganado'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(AppTheme.iconoSanidad, color: AppTheme.primaryGreen),
              title: const Text('Sanidad'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(AppTheme.iconoReproduccion, color: AppTheme.primaryGreen),
              title: const Text('Reproducción'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(AppTheme.iconoProduccion, color: Colors.blue),
              title: const Text('Producción (Leche)'),
              onTap: () => _navegarA(const ProduccionScreen(), 'Producción de Leche'),
            ),
            ListTile(
              leading: const Icon(AppTheme.iconoFinanzas, color: Colors.blue),
              title: const Text('Finanzas'),
              onTap: () => _navegarA(const FinanzasScreen(), 'Control Financiero'),
            ),
            ListTile(
              leading: const Icon(AppTheme.iconoInventario, color: Colors.blue),
              title: const Text('Inventario (Bodega)'),
              onTap: () => _navegarA(const InventarioScreen(), 'Inventario y Bodega'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(AppTheme.iconoConfiguracion, color: Colors.grey),
              title: const Text('Configuración'),
              onTap: () => _navegarA(const ConfiguracionScreen(), 'Configuración'),
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(AppTheme.iconoMiFinca),
            label: 'Mi Finca',
          ),
          BottomNavigationBarItem(
            icon: AppTheme.obtenerIcono(
              AppTheme.iconoGanado, 
              size: 24, 
            ),
            label: 'Ganado',
          ),
          const BottomNavigationBarItem(
            icon: Icon(AppTheme.iconoSanidad),
            label: 'Sanidad',
          ),
          const BottomNavigationBarItem(
            icon: Icon(AppTheme.iconoReproduccion),
            label: 'Reproducción',
          ),
        ],
      ),
    );
  }

  String _obtenerTituloBarra(int index) {
    switch (index) {
      case 0:
        return 'Mi Finca';
      case 1:
        return 'Control de Ganado';
      case 2:
        return 'Control de Sanidad';
      case 3:
        return 'Control de Reproducción';
      default:
        return 'GanaderoPro';
    }
  }
}
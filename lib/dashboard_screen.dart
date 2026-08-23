import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  int _totalGanado = 0;
  int _totalSanidad = 0;
  int _totalReproduccion = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarMetricas();
  }

  // Método para contar los registros de cada tabla
  Future<void> _cargarMetricas() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final ganado = await _dbHelper.queryAllGanado();
      final sanidad = await _dbHelper.queryAllSanidad();
      final reproduccion = await _dbHelper.queryAllReproduccion();

      setState(() {
        _totalGanado = ganado.length;
        _totalSanidad = sanidad.length;
        _totalReproduccion = reproduccion.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar métricas: $e')),
      );
    }
  }

  // Método para exportar la base de datos física SQLite
  Future<void> _exportarBaseDeDatos() async {
    try {
      var databasesPath = await getDatabasesPath();
      String path = p.join(databasesPath, 'prototipoganado.db');

      File dbFile = File(path);

      if (await dbFile.exists()) {
        await Share.shareXFiles(
          [XFile(dbFile.path)],
          text: 'Base de datos de GanaderoPro (.db)',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró el archivo de la base de datos.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar base de datos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GanaderoPro - Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar métricas',
            onPressed: _cargarMetricas,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarMetricas,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    color: Colors.green[800],
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '¡Bienvenido a tu Finca!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Control operativo 100% offline de ganado, sanidad y reproducción.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Resumen General',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildMetricCard(
                        title: 'Total Ganado',
                        value: '$_totalGanado',
                        icon: Icons.pets,
                        color: Colors.blue,
                      ),
                      _buildMetricCard(
                        title: 'Eventos Sanidad',
                        value: '$_totalSanidad',
                        icon: Icons.healing,
                        color: Colors.green,
                      ),
                      _buildMetricCard(
                        title: 'Eventos Reproducción',
                        value: '$_totalReproduccion',
                        icon: Icons.favorite,
                        color: Colors.pink,
                      ),
                      _buildMetricCard(
                        title: 'Modo',
                        value: 'Offline',
                        icon: Icons.storage,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _exportarBaseDeDatos,
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text(
                      'Exportar Base de Datos (.db)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Comparte este archivo para respaldar tu información en la PC.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
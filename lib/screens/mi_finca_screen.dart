import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import 'configuracion_screen.dart'; // 1. Importa la pantalla de configuración

class MiFincaScreen extends StatefulWidget {
  const MiFincaScreen({Key? key}) : super(key: key);

  @override
  State<MiFincaScreen> createState() => _MiFincaScreenState();
}

class _MiFincaScreenState extends State<MiFincaScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  int _totalGanado = 0;
  double _totalLecheMes = 0.0;
  Map<String, double> _finanzasMes = {'ingresos': 0.0, 'gastos': 0.0, 'balance': 0.0};
  List<Map<String, dynamic>> _actividadesPendientes = [];
  bool _isLoading = true;
  String _simboloMoneda = 'Bs '; // 2. Variable para almacenar el símbolo dinámico

  @override
  void initState() {
    super.initState();
    _cargarDatosFinca();
  }

  // Método para consultar todos los indicadores, actividades y la moneda de la BD
  Future<void> _cargarDatosFinca() async {
    setState(() => _isLoading = true);

    try {
      // Obtenemos el símbolo configurado
      String simbolo = await ConfiguracionScreen.obtenerSimboloMoneda();

      // Obtenemos el año y mes actual en formato 'YYYY-MM' para los filtros de SQLite
      final now = DateTime.now();
      final anioMes = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      int ganado = await _dbHelper.getCountGanadoActivo();
      double leche = await _dbHelper.getTotalLecheTotalMes(anioMes);
      Map<String, double> finanzas = await _dbHelper.getBalanceFinancieroMes(anioMes);
      List<Map<String, dynamic>> actividades = await _dbHelper.queryActividadesPendientes();

      setState(() {
        _simboloMoneda = simbolo; // 3. Actualizamos el símbolo
        _totalGanado = ganado;
        _totalLecheMes = leche;
        _finanzasMes = finanzas;
        _actividadesPendientes = actividades;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Manejo simple de error en consola
      debugPrint("Error al cargar datos de la finca: $e");
    }
  }

  // Marcar actividad como completada
  Future<void> _completarTarea(int id) async {
    await _dbHelper.completarActividad(id);
    _cargarDatosFinca(); // Recargamos la vista
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatosFinca,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  const Text(
                    'Indicadores del Mes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  // Fila de Tarjetas de Indicadores Clave
                  Row(
                    children: [
                      _buildCardIndicador(
                        'Ganado Activo',
                        '$_totalGanado',
                        AppTheme.iconoGanado,
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildCardIndicador(
                        'Leche (Mes)',
                        '${_totalLecheMes.toStringAsFixed(1)} L',
                        AppTheme.iconoProduccion,
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildCardIndicador(
                        'Balance Mes',
                        // 4. Usamos la variable de moneda dinámica en lugar de '$' fijo
                        '$_simboloMoneda${_finanzasMes['balance']?.toStringAsFixed(2)}',
                        AppTheme.iconoFinanzas,
                        (_finanzasMes['balance'] ?? 0) >= 0 ? AppTheme.primaryGreen : Colors.red,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Actividades y Tareas Pendientes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Lista de Actividades
                  _actividadesPendientes.isEmpty
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                '¡Excelente! No hay actividades pendientes por ahora.',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _actividadesPendientes.length,
                          itemBuilder: (context, index) {
                            final actividad = _actividadesPendientes[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.notifications_active, color: AppTheme.primaryGreen),
                                title: Text(
                                  actividad['titulo'] ?? 'Sin título',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Lote/Área: ${actividad['tipo_lote'] ?? 'General'} | Fecha: ${actividad['fecha_programada'] ?? ''}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: AppTheme.primaryGreen),
                                  onPressed: () => _completarTarea(actividad['id']),
                                  tooltip: 'Marcar como completada',
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  // Widget auxiliar para construir las tarjetas de indicadores de forma limpia
  Widget _buildCardIndicador(String titulo, String valor, dynamic icono, Color colorIcono) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTheme.obtenerIcono(icono, color: colorIcono, size: 28),
              const SizedBox(height: 10),
              Text(
                titulo,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                valor,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
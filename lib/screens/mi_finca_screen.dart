import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_date_field.dart';
import 'configuracion_screen.dart';
import 'dart:io';

class MiFincaScreen extends StatefulWidget {
  const MiFincaScreen({Key? key}) : super(key: key);

  @override
  State<MiFincaScreen> createState() => _MiFincaScreenState();
}

class _MiFincaScreenState extends State<MiFincaScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  int _totalGanado = 0;
  double _totalLecheRango = 0.0;
  Map<String, double> _balanceTotal = {'ingresos': 0.0, 'gastos': 0.0, 'balance': 0.0};
  Map<String, double> _finanzasRango = {'ingresos': 0.0, 'gastos': 0.0, 'balance': 0.0};
  List<Map<String, dynamic>> _actividadesPendientes = [];
  bool _isLoading = true;
  String _simboloMoneda = 'Bs ';
  bool _panelCalculoAbierto = false;

  // Controladores para el selector de rango de fechas
  final TextEditingController _fechaInicioController = TextEditingController();
  final TextEditingController _fechaFinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatosFinca();
  }

  Future<void> _cargarRangoFechas() async {
    final prefs = await SharedPreferences.getInstance();
    String? inicioStr = prefs.getString('finca_fecha_inicio');
    String? finStr = prefs.getString('finca_fecha_fin');

    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    if (inicioStr != null && finStr != null && inicioStr.isNotEmpty && finStr.isNotEmpty) {
      startDate = _parseFechaDDMMYYYY(inicioStr);
      endDate = _parseFechaDDMMYYYY(finStr);

      while (now.isAfter(endDate)) {
        startDate = DateTime(startDate.year, startDate.month + 1, startDate.day);
        endDate = DateTime(endDate.year, endDate.month + 1, endDate.day);
      }
    } else {
      if (now.day >= 26) {
        startDate = DateTime(now.year, now.month, 26);
        endDate = DateTime(now.month == 12 ? now.year + 1 : now.year, now.month == 12 ? 1 : now.month + 1, 26);
      } else {
        startDate = DateTime(now.month == 1 ? now.year - 1 : now.year, now.month == 1 ? 12 : now.month - 1, 26);
        endDate = DateTime(now.year, now.month, 26);
      }
    }

    _fechaInicioController.text = _formatearFechaDDMMYYYY(startDate);
    _fechaFinController.text = _formatearFechaDDMMYYYY(endDate);

    await prefs.setString('finca_fecha_inicio', _fechaInicioController.text);
    await prefs.setString('finca_fecha_fin', _fechaFinController.text);
  }

  Future<void> _guardarYRecargarRango() async {
    if (_fechaInicioController.text.trim().isEmpty || _fechaFinController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ambas fechas son obligatorias para el cálculo.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('finca_fecha_inicio', _fechaInicioController.text.trim());
    await prefs.setString('finca_fecha_fin', _fechaFinController.text.trim());

    _cargarDatosFinca();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rango de fechas actualizado con éxito.')),
    );
  }

  Future<void> _cargarDatosFinca() async {
    setState(() => _isLoading = true);

    try {
      String simbolo = await ConfiguracionScreen.obtenerSimboloMoneda();
      await _cargarRangoFechas();

      int ganado = await _dbHelper.getCountGanadoActivo();

      String inicioISO = _convertirAISO(_fechaInicioController.text);
      String finISO = _convertirAISO(_fechaFinController.text);

      double lecheRango = await _dbHelper.getTotalLecheRango(inicioISO, finISO);
      Map<String, double> finanzasRango = await _dbHelper.getBalanceFinancieroRango(inicioISO, finISO);
      Map<String, double> balanceTotal = await _dbHelper.getBalanceFinancieroTotal();
      List<Map<String, dynamic>> actividades = await _dbHelper.queryActividadesPendientes();

      setState(() {
        _simboloMoneda = simbolo;
        _totalGanado = ganado;
        _totalLecheRango = lecheRango;
        _balanceTotal = balanceTotal;
        _finanzasRango = finanzasRango;
        _actividadesPendientes = actividades;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error al cargar datos de la finca: $e");
    }
  }

  Future<void> _completarTarea(int id) async {
    await _dbHelper.completarActividad(id);
    _cargarDatosFinca();
  }

  DateTime _parseFechaDDMMYYYY(String text) {
    try {
      final parts = text.split('/');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return DateTime.now();
  }

  String _formatearFechaDDMMYYYY(DateTime date) {
    String day = date.day.toString().padLeft(2, '0');
    String month = date.month.toString().padLeft(2, '0');
    String year = date.year.toString();
    return '$day/$month/$year';
  }

  String _convertirAISO(String fechaDDMMYYYY) {
    final parts = fechaDDMMYYYY.split('/');
    if (parts.length == 3) {
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }
    return fechaDDMMYYYY;
  }

  void _mostrarDetalleActividad(Map<String, dynamic> actividad) {
    final String fechaVisual = ConfiguracionScreen.formatearFechaVisual(actividad['fecha_programada']);
    final String tipoLote = actividad['tipo_lote'] ?? 'General';
    bool esGestante = tipoLote.toLowerCase().contains('gestante');

    String infoParto = '';
    if (esGestante) {
      try {
        DateTime fechaProg = DateTime.parse(actividad['fecha_programada']);
        DateTime fechaParto = fechaProg.add(const Duration(days: 15));
        DateTime hoy = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        int diasRestantes = fechaParto.difference(hoy).inDays;
        String fppVisual = ConfiguracionScreen.formatearFechaVisual(fechaParto.toIso8601String().split('T')[0]);

        if (diasRestantes > 0) {
          infoParto = '⏳ Faltan $diasRestantes días para el parto (FPP: $fppVisual)';
        } else if (diasRestantes == 0) {
          infoParto = '🚨 ¡Parto esperado HOY! (FPP: $fppVisual)';
        } else {
          infoParto = '⚠️ Parto cumplido hace ${diasRestantes.abs()} días (FPP: $fppVisual)';
        }
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Detalle de Actividad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text(actividad['titulo'] ?? 'Sin título', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Área / Lote: $tipoLote'),
              if (esGestante && infoParto.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(infoParto, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
              ],
              const SizedBox(height: 6),
              Text('Fecha Programada Alerta: $fechaVisual'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Marcar como Completada', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(context);
                    _completarTarea(actividad['id']);
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _mostrarModalRegistrarActividad() {
    final tituloController = TextEditingController();
    final fechaController = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    String tipoLoteSeleccionado = 'Sanidad';

    final List<String> tiposLote = [
      'Sanidad',
      'Reproducción / Maternidad',
      'Alimentación',
      'Mantenimiento',
      'General'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Programar Actividad'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: tituloController,
                        decoration: const InputDecoration(labelText: 'Título de la actividad *'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tipoLoteSeleccionado,
                        decoration: const InputDecoration(labelText: 'Área / Lote'),
                        items: tiposLote
                            .map((lote) => DropdownMenuItem(value: lote, child: Text(lote)))
                            .toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            tipoLoteSeleccionado = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomDateField(
                        controller: fechaController,
                        labelText: 'Fecha Programada (dd/mm/aaaa)',
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (tituloController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El título es obligatorio.')),
                      );
                      return;
                    }

                    // Convertimos dd/mm/aaaa a YYYY-MM-DD para SQLite
                    String fechaISO = fechaController.text.trim().isEmpty
                        ? DateTime.now().toIso8601String().split('T')[0]
                        : _convertirAISO(fechaController.text.trim());

                    await _dbHelper.insertarActividad({
                      'titulo': tituloController.text.trim(),
                      'tipo_lote': tipoLoteSeleccionado,
                      'fecha_programada': fechaISO,
                      'completada': 0,
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                    _cargarDatosFinca();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Actividad programada con éxito.')),
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
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
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      initiallyExpanded: _panelCalculoAbierto,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _panelCalculoAbierto = expanded;
                        });
                      },
                      leading: const Icon(Icons.date_range, color: AppTheme.primaryGreen),
                      title: const Text(
                        'Periodo de Cálculo / Pago',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Actual: ${_fechaInicioController.text} al ${_fechaFinController.text}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomDateField(
                                      controller: _fechaInicioController,
                                      labelText: 'Desde',
                                      hintText: 'dd/mm/aaaa',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: CustomDateField(
                                      controller: _fechaFinController,
                                      labelText: 'Hasta',
                                      hintText: 'dd/mm/aaaa',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryGreen,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _guardarYRecargarRango,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Aplicar Rango de Fechas'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Indicadores del Periodo y Finca',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
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
                        'Leche (Rango)',
                        '${_totalLecheRango.toStringAsFixed(1)} L',
                        AppTheme.iconoProduccion,
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _buildCardIndicador(
                        'Balance General (Total)',
                        '$_simboloMoneda${_balanceTotal['balance']?.toStringAsFixed(2)}',
                        AppTheme.iconoFinanzas,
                        (_balanceTotal['balance'] ?? 0) >= 0 ? AppTheme.primaryGreen : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      _buildCardIndicador(
                        'Balance (Rango)',
                        '$_simboloMoneda${_finanzasRango['balance']?.toStringAsFixed(2)}',
                        AppTheme.iconoFinanzas,
                        (_finanzasRango['balance'] ?? 0) >= 0 ? AppTheme.primaryGreen : Colors.red,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Actividades y Tareas Pendientes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

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
                            final String fechaVisual = ConfiguracionScreen.formatearFechaVisual(actividad['fecha_programada']);
                            final String tipoLote = actividad['tipo_lote'] ?? 'General';
                            bool esGestante = tipoLote.toLowerCase().contains('gestante');

                            // Datos de la vaca y servicio
                            final String? fotoPath = actividad['animal_foto'];
                            final String nombreVaca = actividad['animal_nombre'] ?? '';
                            final String areteVaca = actividad['animal_arete'] ?? '';
                            final String tipoServicio = actividad['ultimo_tipo_evento'] ?? 'Servicio'; 
                            bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();

                            String tituloCard = actividad['titulo'] ?? 'Sin título';
                            if (esGestante && areteVaca.isNotEmpty) {
                              tituloCard = 'Arete: $areteVaca ${nombreVaca.isNotEmpty ? '($nombreVaca)' : ''}';
                            }

                            int diasRestantes = 0;
                            String subtitulo = 'Área: $tipoLote | Fecha: $fechaVisual';
                            if (esGestante) {
                              try {
                                DateTime fechaProg = DateTime.parse(actividad['fecha_programada']);
                                DateTime fechaParto = fechaProg.add(const Duration(days: 15));
                                DateTime hoy = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                                diasRestantes = fechaParto.difference(hoy).inDays;

                                if (diasRestantes > 0) {
                                  subtitulo = 'Servicio: $tipoServicio | ⏳ Faltan $diasRestantes días para el parto';
                                } else if (diasRestantes == 0) {
                                  subtitulo = 'Servicio: $tipoServicio | 🚨 ¡Parto esperado HOY!';
                                } else {
                                  subtitulo = 'Servicio: $tipoServicio | ⚠️ Parto atrasado por ${diasRestantes.abs()} días';
                                }
                              } catch (_) {}
                            }

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                                  backgroundImage: esArchivoLocal ? FileImage(File(fotoPath)) : null,
                                  child: !esArchivoLocal 
                                      ? Icon(esGestante ? Icons.favorite : Icons.notifications_active, color: AppTheme.primaryGreen) 
                                      : null,
                                ),
                                title: Text(
                                  tituloCard,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(subtitulo),
                                trailing: IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: AppTheme.primaryGreen),
                                  onPressed: () => _completarTarea(actividad['id']),
                                  tooltip: 'Marcar como completada',
                                ),
                                onTap: () => _mostrarDetalleActividad(actividad),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarModalRegistrarActividad,
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Programar Actividad',
      ),
    );
  }

  Widget _buildCardIndicador(String titulo, String valor, dynamic icono, Color colorIcono) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTheme.obtenerIcono(icono, color: colorIcono, size: 26),
              const SizedBox(height: 10),
              Text(
                titulo,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                valor,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

class ReproduccionScreen extends StatefulWidget {
  const ReproduccionScreen({Key? key}) : super(key: key);

  @override
  State<ReproduccionScreen> createState() => _ReproduccionScreenState();
}

class _ReproduccionScreenState extends State<ReproduccionScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _listaReproduccion = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarReproduccion();
  }

  // Consultar historial de reproducción ordenado por ID descendente
  Future<void> _cargarReproduccion() async {
    setState(() => _isLoading = true);
    
    final db = await _dbHelper.database;
    final data = await db.query('reproduccion', orderBy: 'id DESC');

    setState(() {
      _listaReproduccion = data;
      _isLoading = false;
    });
  }

  // Modal para registrar un nuevo evento reproductivo
  void _mostrarModalRegistrarReproduccion() async {
    // Obtenemos los aretes activos para el selector desplegable
    List<Map<String, dynamic>> animalesActivos = await _dbHelper.queryAllGanadoActivo();
    
    if (animalesActivos.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero debes registrar al menos un animal en el módulo Ganado.')),
      );
      return;
    }

    String? areteSeleccionado = animalesActivos.first['arete'];
    String tipoEventoSeleccionado = 'Inseminación';
    final notasController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Registrar Evento Reproductivo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Desplegable inteligente de aretes
                    DropdownButtonFormField<String>(
                      value: areteSeleccionado,
                      decoration: const InputDecoration(labelText: 'Seleccionar Arete'),
                      items: animalesActivos.map((animal) {
                        return DropdownMenuItem<String>(
                          value: animal['arete'],
                          child: Text('Arete: ${animal['arete']} (${animal['categoria']})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          areteSeleccionado = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: tipoEventoSeleccionado,
                      decoration: const InputDecoration(labelText: 'Tipo de Evento'),
                      items: ['Inseminación', 'Monta', 'Diagnóstico Preñez', 'Parto', 'Aborto']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          tipoEventoSeleccionado = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notasController,
                      decoration: const InputDecoration(labelText: 'Notas / Observaciones'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (areteSeleccionado != null) {
                      await _dbHelper.insertReproduccion({
                        'arete_asociado': areteSeleccionado,
                        'tipo_evento': tipoEventoSeleccionado,
                        'fecha': DateTime.now().toIso8601String().split('T')[0],
                        'notas': notasController.text.trim(),
                      });
                      Navigator.pop(context);
                      _cargarReproduccion();
                    }
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

  // Modal desplegable (Bottom Sheet) para ver el detalle al hacer clic en una tarjeta
  void _mostrarDetalleReproduccion(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
                  Text(
                    'Ficha Reproductiva',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text('Arete del Animal: ${item['arete_asociado']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Evento: ${item['tipo_evento']}'),
              const SizedBox(height: 6),
              Text('Fecha: ${item['fecha']}'),
              const SizedBox(height: 12),
              const Text('Notas / Observaciones:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(item['notas']?.isEmpty == true ? 'Sin notas adicionales registradas.' : item['notas']),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listaReproduccion.isEmpty
              ? const Center(
                  child: Text(
                    'No hay registros reproductivos.\nPresiona el botón "+" para registrar un evento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _listaReproduccion.length,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    final item = _listaReproduccion[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                          child: Icon(AppTheme.iconoReproduccion, color: AppTheme.primaryGreen),
                        ),
                        title: Text(
                          'Arete: ${item['arete_asociado']} - ${item['tipo_evento']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Fecha: ${item['fecha']}',
                        ),
                        trailing: const Icon(Icons.info_outline, color: Colors.grey),
                        onTap: () => _mostrarDetalleReproduccion(item), // Despliega el modal al hacer clic
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarModalRegistrarReproduccion,
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Registrar Reproducción',
      ),
    );
  }
}
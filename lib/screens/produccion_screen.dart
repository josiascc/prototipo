import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

class ProduccionScreen extends StatefulWidget {
  const ProduccionScreen({Key? key}) : super(key: key);

  @override
  State<ProduccionScreen> createState() => _ProduccionScreenState();
}

class _ProduccionScreenState extends State<ProduccionScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _listaProduccion = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarProduccion();
  }

  // Consultar registros de producción ordenados por ID descendente
  Future<void> _cargarProduccion() async {
    setState(() => _isLoading = true);
    
    final db = await _dbHelper.database;
    final data = await db.query('produccion', orderBy: 'id DESC');

    setState(() {
      _listaProduccion = data;
      _isLoading = false;
    });
  }

  // Modal para registrar una nueva producción de leche
  void _mostrarModalRegistrarProduccion() async {
    List<Map<String, dynamic>> animalesActivos = await _dbHelper.queryAllGanadoActivo();
    
    List<String> opcionesArete = ['GENERAL_FINCA'];
    for (var animal in animalesActivos) {
      opcionesArete.add(animal['arete']);
    }

    String areteSeleccionado = opcionesArete.first;
    String turnoSeleccionado = 'Mañana';
    final litrosController = TextEditingController();
    final notasController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Registrar Producción de Leche'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: areteSeleccionado,
                      decoration: const InputDecoration(labelText: 'Arete o Destino'),
                      items: opcionesArete.map((val) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(val == 'GENERAL_FINCA' ? 'General Finca' : 'Arete: $val'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          areteSeleccionado = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: turnoSeleccionado,
                      decoration: const InputDecoration(labelText: 'Turno de Ordeño'),
                      items: ['Mañana', 'Tarde']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          turnoSeleccionado = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: litrosController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Litros Producidos'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notasController,
                      decoration: const InputDecoration(labelText: 'Notas adicionales (Opcional)'),
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
                    double? litros = double.tryParse(litrosController.text.trim());
                    if (litros != null && litros > 0) {
                      await _dbHelper.insertProduccion({
                        'arete_asociado': areteSeleccionado,
                        'turno': turnoSeleccionado,
                        'litros': litros,
                        'fecha': DateTime.now().toIso8601String().split('T')[0],
                        'notas': notasController.text.trim(),
                      });
                      Navigator.pop(context);
                      _cargarProduccion();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor ingresa una cantidad válida de litros.')),
                      );
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
  void _mostrarDetalleProduccion(Map<String, dynamic> item) {
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
                  const Text(
                    'Detalle de Producción',
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
              Text('Registro para: ${item['arete_asociado']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Turno: ${item['turno']}'),
              const SizedBox(height: 6),
              Text('Litros: ${item['litros']} L'),
              const SizedBox(height: 6),
              Text('Fecha: ${item['fecha']}'),
              const SizedBox(height: 12),
              const Text('Notas:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(item['notas']?.isEmpty == true ? 'Sin notas adicionales.' : item['notas']),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _listaProduccion.isEmpty
                ? const Center(
                    child: Text(
                      'No hay registros de leche.\nPresiona el botón "+" para registrar el ordeño.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: _listaProduccion.length,
                    padding: const EdgeInsets.all(8.0),
                    itemBuilder: (context, index) {
                      final item = _listaProduccion[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                            child: const Icon(AppTheme.iconoProduccion, color: AppTheme.primaryGreen),
                          ),
                          title: Text(
                            '${item['litros']} Litros - Turno: ${item['turno']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Origen: ${item['arete_asociado']} | Fecha: ${item['fecha']}',
                          ),
                          trailing: const Icon(Icons.info_outline, color: Colors.grey),
                          onTap: () => _mostrarDetalleProduccion(item),
                        ),
                      );
                    },
                  ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _mostrarModalRegistrarProduccion,
            backgroundColor: AppTheme.primaryGreen,
            tooltip: 'Registrar Leche',
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
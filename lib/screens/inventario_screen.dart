import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({Key? key}) : super(key: key);

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _listaInventario = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarInventario();
  }

  // Consultar historial de inventario ordenado por ID descendente
  Future<void> _cargarInventario() async {
    setState(() => _isLoading = true);
    
    final db = await _dbHelper.database;
    try {
      final data = await db.query('inventario', orderBy: 'id DESC');
      setState(() {
        _listaInventario = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error al consultar inventario: $e");
    }
  }

  // Modal para registrar un nuevo producto o insumo en bodega
  void _mostrarModalRegistrarInventario() {
    final nombreController = TextEditingController();
    final cantidadController = TextEditingController();
    String unidadSeleccionada = 'Sacos';
    final descripcionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Registrar en Inventario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre del Insumo / Producto'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cantidadController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Cantidad Actual'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: unidadSeleccionada,
                      decoration: const InputDecoration(labelText: 'Unidad de Medida'),
                      items: ['Sacos', 'Kilos', 'Litros', 'Unidades', 'Frascos', 'Dosis']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          unidadSeleccionada = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descripcionController,
                      decoration: const InputDecoration(labelText: 'Descripción / Ubicación (Opcional)'),
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
                    if (nombreController.text.isNotEmpty) {
                      double? cantidad = double.tryParse(cantidadController.text.trim()) ?? 0.0;
                      
                      final db = await _dbHelper.database;
                      await db.insert('inventario', {
                        'nombre': nombreController.text.trim(),
                        'cantidad': cantidad,
                        'unidad': unidadSeleccionada,
                        'descripcion': descripcionController.text.trim(),
                        'fecha_actualizacion': DateTime.now().toIso8601String().split('T')[0],
                      });

                      Navigator.pop(context);
                      _cargarInventario();
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
  void _mostrarDetalleInventario(Map<String, dynamic> item) {
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
                    'Detalle de Bodega',
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
              Text('Producto: ${item['nombre']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Stock: ${item['cantidad']} ${item['unidad']}'),
              const SizedBox(height: 6),
              Text('Última Actualización: ${item['fecha_actualizacion'] ?? 'N/D'}'),
              const SizedBox(height: 12),
              const Text('Descripción / Ubicación:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(item['descripcion']?.isEmpty == true ? 'Sin descripción registrada.' : item['descripcion']),
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
            : _listaInventario.isEmpty
                ? const Center(
                    child: Text(
                      'No hay insumos en bodega.\nPresiona el botón "+" para agregar productos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: _listaInventario.length,
                    padding: const EdgeInsets.all(8.0),
                    itemBuilder: (context, index) {
                      final item = _listaInventario[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                            child: const Icon(AppTheme.iconoInventario, color: AppTheme.primaryGreen),
                          ),
                          title: Text(
                            '${item['nombre']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Stock: ${item['cantidad']} ${item['unidad']} | Actualizado: ${item['fecha_actualizacion'] ?? ''}',
                          ),
                          trailing: const Icon(Icons.info_outline, color: Colors.grey),
                          onTap: () => _mostrarDetalleInventario(item),
                        ),
                      );
                    },
                  ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _mostrarModalRegistrarInventario,
            backgroundColor: AppTheme.primaryGreen,
            tooltip: 'Registrar Insumo',
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
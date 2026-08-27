import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_date_field.dart';
import 'configuracion_screen.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({Key? key}) : super(key: key);

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _listaInventario = [];
  bool _isLoading = true;

  // Variables para el diseño interactivo y menú FAB
  bool _menuFabAbierto = false;

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

  // ===========================================================================
  // 1. REGISTRAR NUEVO PRODUCTO
  // ===========================================================================
  void _mostrarModalRegistrarInventario() {
    setState(() => _menuFabAbierto = false);

    final nombreController = TextEditingController();
    final cantidadController = TextEditingController();
    String unidadSeleccionada = 'Sacos';
    final descripcionController = TextEditingController();

    // Fechas en formato visual dd/mm/aaaa
    final String fechaHoyISO = DateTime.now().toIso8601String().split('T')[0];
    final fechaRegistroController = TextEditingController(
      text: ConfiguracionScreen.formatearFechaVisual(fechaHoyISO),
    );
    final fechaVencimientoController = TextEditingController(); // Opcional o por defecto vacía

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Registrar Nuevo Producto'),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre del Insumo / Producto *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: cantidadController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Stock Inicial *'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: unidadSeleccionada,
                        decoration: const InputDecoration(labelText: 'Unidad de Medida'),
                        items: ['Sacos', 'Kilos', 'Litros', 'Unidades', 'Frascos', 'Dosis']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (val) => setStateDialog(() => unidadSeleccionada = val!),
                      ),
                      const SizedBox(height: 12),
                      CustomDateField(
                        controller: fechaRegistroController,
                        labelText: 'Fecha de Registro (dd/mm/aaaa)',
                        hintText: 'Ej: 26/08/2026',
                      ),
                      const SizedBox(height: 12),
                      CustomDateField(
                        controller: fechaVencimientoController,
                        labelText: 'Fecha de Vencimiento (dd/mm/aaaa) (Opcional)',
                        hintText: 'Ej: 26/08/2027',
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (nombreController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor ingrese el nombre del producto.')),
                      );
                      return;
                    }

                    double cantidad = double.tryParse(cantidadController.text.trim()) ?? 0.0;
                    
                    // Conversión de ambas fechas a ISO (YYYY-MM-DD)
                    String fechaRegistroISO = fechaRegistroController.text.trim().isEmpty
                        ? fechaHoyISO
                        : _convertirFechaAISO(fechaRegistroController.text.trim());

                    String? fechaVencimientoISO = fechaVencimientoController.text.trim().isEmpty
                        ? null
                        : _convertirFechaAISO(fechaVencimientoController.text.trim());

                    final db = await _dbHelper.database;
                    await db.insert('inventario', {
                      'nombre_producto': nombreController.text.trim(),
                      'stock_actual': cantidad,
                      'unidad_medida': unidadSeleccionada,
                      'categoria': descripcionController.text.trim().isEmpty ? 'General' : descripcionController.text.trim(),
                      'fecha_registro': fechaRegistroISO,
                      'fecha_vencimiento': fechaVencimientoISO,
                      'monto': 0.0,
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                    _cargarInventario();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Producto registrado exitosamente.')),
                    );
                  },
                  child: const Text('Guardar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 2. SELECCIONADOR PARA EDITAR, ENTRADA O SALIDA
  // ===========================================================================
  void _mostrarModalSeleccionarProducto({required String accion}) {
    setState(() => _menuFabAbierto = false);

    String titulo = 'Seleccionar Producto';
    if (accion == 'editar') titulo = 'Seleccionar para Editar';
    if (accion == 'entrada') titulo = 'Registrar Entrada de Stock';
    if (accion == 'salida') titulo = 'Registrar Salida / Uso';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(titulo),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            height: 400,
            child: _listaInventario.isEmpty
                ? const Center(child: Text('No hay insumos en bodega.'))
                : ListView.builder(
                    itemCount: _listaInventario.length,
                    itemBuilder: (context, index) {
                      final item = _listaInventario[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(item['nombre_producto'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Stock actual: ${item['stock_actual']} ${item['unidad_medida']}'),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.primaryGreen),
                          onTap: () {
                            Navigator.pop(context);
                            if (accion == 'editar') {
                              _mostrarModalEditarProducto(item);
                            } else if (accion == 'entrada') {
                              _mostrarModalMovimientoStock(item, esEntrada: true);
                            } else if (accion == 'salida') {
                              _mostrarModalMovimientoStock(item, esEntrada: false);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // 3. EDITAR PRODUCTO
  // ===========================================================================
  void _mostrarModalEditarProducto(Map<String, dynamic> item) {
    final nombreController = TextEditingController(text: item['nombre_producto']);
    String unidadSeleccionada = item['unidad_medida'] ?? 'Sacos';
    final descripcionController = TextEditingController(text: item['categoria'] == 'General' ? '' : item['categoria']);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar Producto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre del Producto *'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: unidadSeleccionada,
                      decoration: const InputDecoration(labelText: 'Unidad de Medida'),
                      items: ['Sacos', 'Kilos', 'Litros', 'Unidades', 'Frascos', 'Dosis']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) => setStateDialog(() => unidadSeleccionada = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descripcionController,
                      decoration: const InputDecoration(labelText: 'Descripción / Ubicación'),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (nombreController.text.trim().isNotEmpty) {
                      final db = await _dbHelper.database;
                      await db.update(
                        'inventario',
                        {
                          'nombre_producto': nombreController.text.trim(),
                          'unidad_medida': unidadSeleccionada,
                          'categoria': descripcionController.text.trim().isEmpty ? 'General' : descripcionController.text.trim(),
                        },
                        where: 'id = ?',
                        whereArgs: [item['id']],
                      );

                      if (!mounted) return;
                      Navigator.pop(context);
                      _cargarInventario();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Producto actualizado exitosamente.')),
                      );
                    }
                  },
                  child: const Text('Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 4. ENTRADA O SALIDA DE STOCK
  // ===========================================================================
  void _mostrarModalMovimientoStock(Map<String, dynamic> item, {required bool esEntrada}) {
    final cantidadController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(esEntrada ? 'Entrada: ${item['nombre_producto']}' : 'Salida / Uso: ${item['nombre_producto']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stock actual: ${item['stock_actual']} ${item['unidad_medida']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 16),
              TextField(
                controller: cantidadController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: esEntrada ? 'Cantidad a sumar (+)' : 'Cantidad a descontar (-)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: esEntrada ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                double valor = double.tryParse(cantidadController.text.trim()) ?? 0.0;
                if (valor > 0) {
                  double stockActual = (item['stock_actual'] ?? 0.0).toDouble();
                  double nuevoStock = esEntrada ? (stockActual + valor) : (stockActual - valor);
                  if (nuevoStock < 0) nuevoStock = 0;

                  final String fechaHoyISO = DateTime.now().toIso8601String().split('T')[0];

                  final db = await _dbHelper.database;
                  await db.update(
                    'inventario',
                    {
                      'stock_actual': nuevoStock,
                      'fecha_vencimiento': fechaHoyISO, // Formato ISO para la BD
                    },
                    where: 'id = ?',
                    whereArgs: [item['id']],
                  );

                  if (!mounted) return;
                  Navigator.pop(context);
                  _cargarInventario();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(esEntrada ? 'Stock sumado correctamente.' : 'Stock descontado correctamente.')),
                  );
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  // Detalle desplegable inferior (Bottom Sheet)
  void _mostrarDetalleInventario(Map<String, dynamic> item) {
    final String fechaVisual = ConfiguracionScreen.formatearFechaVisual(item['fecha_vencimiento']);

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
              Text('Producto: ${item['nombre_producto']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Stock: ${item['stock_actual']} ${item['unidad_medida']}'),
              const SizedBox(height: 6),
              Text('Última Actualización: $fechaVisual'),
              const SizedBox(height: 12),
              const Text('Descripción / Ubicación:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(item['categoria']?.isEmpty == true || item['categoria'] == 'General' ? 'Sin descripción registrada.' : item['categoria']),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Convertimos dd/mm/aaaa a YYYY-MM-DD para SQLite
  String _convertirFechaAISO(String fechaVisual) {
    try {
      final partes = fechaVisual.split('/');
      if (partes.length == 3) {
        final dia = partes[0].padLeft(2, '0');
        final mes = partes[1].padLeft(2, '0');
        final anio = partes[2];
        return '$anio-$mes-$dia';
      }
    } catch (_) {}
    return fechaVisual;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
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
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemBuilder: (context, index) {
                              final item = _listaInventario[index];
                              final String fechaVisual = ConfiguracionScreen.formatearFechaVisual(item['fecha_vencimiento']);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.primaryGreen, width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1C3540).withOpacity(0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    )
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                                    child: const Icon(AppTheme.iconoInventario, color: AppTheme.primaryGreen),
                                  ),
                                  title: Text(
                                    '${item['nombre_producto']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        'Stock: ${item['stock_actual']} ${item['unidad_medida']}',
                                        style: const TextStyle(color: Color(0xFF6C8795), fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Actualizado: $fechaVisual',
                                        style: const TextStyle(color: Color(0xFF6C8795), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5F4E8),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Disponible',
                                      style: TextStyle(color: Color(0xFF2D8235), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  onTap: () => _mostrarDetalleInventario(item),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),

          // Overlay oscuro cuando el menú del FAB está abierto
          if (_menuFabAbierto)
            GestureDetector(
              onTap: () => setState(() => _menuFabAbierto = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),

          // Menú Desplegable del FAB flotante con las 4 opciones
          if (_menuFabAbierto)
            Positioned(
              right: 20,
              bottom: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildFabOption('Registrar nuevo producto', Icons.add_box, _mostrarModalRegistrarInventario),
                  const SizedBox(height: 12),
                  _buildFabOption('Editar producto', Icons.edit, () => _mostrarModalSeleccionarProducto(accion: 'editar')),
                  const SizedBox(height: 12),
                  _buildFabOption('Entrada de producto', Icons.arrow_circle_down, () => _mostrarModalSeleccionarProducto(accion: 'entrada')),
                  const SizedBox(height: 12),
                  _buildFabOption('Salida de producto', Icons.arrow_circle_up, () => _mostrarModalSeleccionarProducto(accion: 'salida')),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryGreen,
        child: Icon(_menuFabAbierto ? Icons.close : Icons.add, color: Colors.white, size: 28),
        onPressed: () {
          setState(() {
            _menuFabAbierto = !_menuFabAbierto;
          });
        },
      ),
    );
  }

  Widget _buildFabOption(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
          ),
        ],
      ),
    );
  }
}
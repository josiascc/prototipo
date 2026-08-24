import 'dart:async';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import 'configuracion_screen.dart'; // 1. Importa la pantalla de configuración

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({Key? key}) : super(key: key);

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _listaFinanzas = [];
  bool _isLoading = true;
  String _simboloMoneda = 'Bs '; // 2. Variable para almacenar el símbolo dinámico

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  // Cargar tanto la moneda configurada como el historial financiero
  Future<void> _cargarDatosIniciales() async {
    setState(() => _isLoading = true);

    // Obtenemos el símbolo configurado
    String simbolo = await ConfiguracionScreen.obtenerSimboloMoneda();

    final db = await _dbHelper.database;
    final data = await db.query('finanzas', orderBy: 'id DESC');

    setState(() {
      _simboloMoneda = simbolo;
      _listaFinanzas = data;
      _isLoading = false;
    });
  }

  // Método para refrescar solo las finanzas si es necesario
  Future<void> _cargarFinanzas() async {
    final db = await _dbHelper.database;
    final data = await db.query('finanzas', orderBy: 'id DESC');
    setState(() {
      _listaFinanzas = data;
    });
  }

  // Modal para registrar un nuevo ingreso o gasto
  void _mostrarModalRegistrarFinanza() {
    String tipoSeleccionado = 'Ingreso';
    String categoriaSeleccionada = 'Venta de Leche';
    final montoController = TextEditingController();
    final descripcionController = TextEditingController();

    final Map<String, List<String>> categoriasPorTipo = {
      'Ingreso': ['Venta de Leche', 'Venta de Ganado', 'Venta de Queso', 'Otros Ingresos'],
      'Gasto': ['Alimento / Concentrado', 'Medicamentos / Sanidad', 'Mano de Obra', 'Mantenimiento', 'Otros Gastos'],
    };

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Registrar Movimiento Financiero'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: tipoSeleccionado,
                      decoration: const InputDecoration(labelText: 'Tipo de Movimiento'),
                      items: ['Ingreso', 'Gasto']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          tipoSeleccionado = val!;
                          categoriaSeleccionada = categoriasPorTipo[tipoSeleccionado]!.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: categoriaSeleccionada,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: categoriasPorTipo[tipoSeleccionado]!
                          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          categoriaSeleccionada = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: montoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      // 3. Mostramos el símbolo dinámico en el label del input
                      decoration: InputDecoration(labelText: 'Monto ($_simboloMoneda)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descripcionController,
                      decoration: const InputDecoration(labelText: 'Descripción / Detalle'),
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
                    double? monto = double.tryParse(montoController.text.trim());
                    if (monto != null && monto > 0) {
                      await _dbHelper.insertFinanza({
                        'tipo': tipoSeleccionado,
                        'categoria': categoriaSeleccionada,
                        'monto': monto,
                        'fecha': DateTime.now().toIso8601String().split('T')[0],
                        'descripcion': descripcionController.text.trim(),
                      });
                      Navigator.pop(context);
                      _cargarFinanzas();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor ingresa un monto válido.')),
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
  void _mostrarDetalleFinanza(Map<String, dynamic> item) {
    bool esIngreso = item['tipo'] == 'Ingreso';
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
                    'Detalle Financiero',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: esIngreso ? AppTheme.primaryGreen : Colors.red[800],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text('Tipo: ${item['tipo']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Categoría: ${item['categoria']}'),
              const SizedBox(height: 6),
              // 4. Usamos la variable de moneda aquí
              Text('Monto: $_simboloMoneda${item['monto']}'),
              const SizedBox(height: 6),
              Text('Fecha: ${item['fecha']}'),
              const SizedBox(height: 12),
              const Text('Descripción:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(item['descripcion']?.isEmpty == true ? 'Sin descripción detallada.' : item['descripcion']),
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
            : _listaFinanzas.isEmpty
                ? const Center(
                    child: Text(
                      'No hay registros financieros.\nPresiona el botón "+" para agregar ingresos o gastos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: _listaFinanzas.length,
                    padding: const EdgeInsets.all(8.0),
                    itemBuilder: (context, index) {
                      final item = _listaFinanzas[index];
                      bool esIngreso = item['tipo'] == 'Ingreso';
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: esIngreso ? AppTheme.lightGreen.withOpacity(0.2) : Colors.red[100],
                            child: Icon(
                              esIngreso ? Icons.arrow_upward : Icons.arrow_downward,
                              color: esIngreso ? AppTheme.primaryGreen : Colors.red[800],
                            ),
                          ),
                          title: Text(
                            // 5. Aplicamos el símbolo dinámico en el título de la tarjeta
                            '${item['categoria']} - $_simboloMoneda${item['monto']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Tipo: ${item['tipo']} | Fecha: ${item['fecha']}',
                          ),
                          trailing: const Icon(Icons.info_outline, color: Colors.grey),
                          onTap: () => _mostrarDetalleFinanza(item),
                        ),
                      );
                    },
                  ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () async {
              _mostrarModalRegistrarFinanza();
            },
            backgroundColor: AppTheme.primaryGreen,
            tooltip: 'Registrar Movimiento',
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'database_helper.dart';

class SanidadScreen extends StatefulWidget {
  const SanidadScreen({Key? key}) : super(key: key);

  @override
  State<SanidadScreen> createState() => _SanidadScreenState();
}

class _SanidadScreenState extends State<SanidadScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _sanidadList = [];
  List<Map<String, dynamic>> _ganadoList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // Carga el historial sanitario y la lista de ganado disponible para los aretes
  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final sanidadDatos = await _dbHelper.queryAllSanidad();
      final ganadoDatos = await _dbHelper.queryAllGanado();
      setState(() {
        _sanidadList = sanidadDatos;
        _ganadoList = ganadoDatos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _mostrarMensaje('Error al cargar datos: $e');
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  // Eliminar un registro de sanidad
  Future<void> _eliminarSanidad(int id) async {
    try {
      await _dbHelper.deleteSanidad(id);
      _mostrarMensaje('Registro sanitario eliminado');
      _cargarDatos();
    } catch (e) {
      _mostrarMensaje('Error al eliminar: $e');
    }
  }

  void _mostrarConfirmacionEliminar(Map<String, dynamic> registro) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Deseas eliminar este registro de sanidad (${registro['tipo_tratamiento']})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarSanidad(registro['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Opciones al tocar un registro (Editar o Eliminar)
  void _mostrarOpcionesSanidad(Map<String, dynamic> registro) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.medical_services, color: Colors.green),
                title: Text('Tratamiento: ${registro['tipo_tratamiento']}'),
                subtitle: Text('Arete: ${registro['arete_asociado']} - Producto: ${registro['producto']}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text('Editar registro'),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarFormularioSanidad(registro: registro);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar registro'),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarConfirmacionEliminar(registro);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // Formulario para Registrar o Editar Sanidad
  void _mostrarFormularioSanidad({Map<String, dynamic>? registro}) {
    if (_ganadoList.isEmpty) {
      _mostrarMensaje('Primero debes registrar al menos un animal en la sección de Ganado.');
      return;
    }

    final bool esEdicion = registro != null;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final TextEditingController productoController = TextEditingController(
      text: esEdicion ? registro['producto'] : '',
    );
    final TextEditingController observacionesController = TextEditingController(
      text: esEdicion ? registro['observaciones'] : '',
    );
    final TextEditingController fechaController = TextEditingController(
      text: esEdicion ? registro['fecha'] : DateTime.now().toString().split(' ')[0],
    );

    // Arete asociado seleccionado
    String? areteSeleccionado = esEdicion 
        ? registro['arete_asociado'] 
        : _ganadoList.first['arete'];

    // Tipo de tratamiento seleccionado
    String? tratamientoSeleccionado = esEdicion 
        ? registro['tipo_tratamiento'] 
        : 'Vacunación';

    final List<String> tiposTratamiento = [
      'Vacunación',
      'Desparasitación',
      'Curación de Herida',
      'Vitaminas / Minerales',
      'Antibiótico',
      'Otro'
    ];

    if (esEdicion && !tiposTratamiento.contains(tratamientoSeleccionado)) {
      tiposTratamiento.add(tratamientoSeleccionado!);
    }

    // Obtener lista única de aretes disponibles
    final List<String> aretesDisponibles = _ganadoList
        .map((animal) => animal['arete'].toString())
        .toList();

    if (esEdicion && !aretesDisponibles.contains(areteSeleccionado)) {
      aretesDisponibles.add(areteSeleccionado!);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(esEdicion ? 'Editar Sanidad' : 'Registrar Sanidad'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dropdown para seleccionar Arete
                      DropdownButtonFormField<String>(
                        value: areteSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Arete del Animal',
                          prefixIcon: Icon(Icons.tag),
                          border: OutlineInputBorder(),
                        ),
                        items: aretesDisponibles.map((String arete) {
                          return DropdownMenuItem<String>(
                            value: arete,
                            child: Text(arete),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setDialogState(() {
                            areteSeleccionado = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dropdown para Tipo de Tratamiento
                      DropdownButtonFormField<String>(
                        value: tratamientoSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Tratamiento',
                          prefixIcon: Icon(Icons.medical_services_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: tiposTratamiento.map((String tipo) {
                          return DropdownMenuItem<String>(
                            value: tipo,
                            child: Text(tipo),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setDialogState(() {
                            tratamientoSeleccionado = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Campo Producto (Texto)
                      TextFormField(
                        controller: productoController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Producto / Medicamento',
                          prefixIcon: Icon(Icons.medication),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa el nombre del producto';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Campo Fecha
                      TextFormField(
                        controller: fechaController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha del Tratamiento',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        onTap: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setDialogState(() {
                              fechaController.text = pickedDate.toString().split(' ')[0];
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Campo Observaciones
                      TextFormField(
                        controller: observacionesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones o Dosis (Opcional)',
                          prefixIcon: Icon(Icons.note),
                          border: OutlineInputBorder(),
                        ),
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
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final Map<String, dynamic> datosSanidad = {
                        'arete_asociado': areteSeleccionado,
                        'tipo_tratamiento': tratamientoSeleccionado,
                        'producto': productoController.text.trim(),
                        'fecha': fechaController.text,
                        'observaciones': observacionesController.text.trim(),
                      };

                      try {
                        if (esEdicion) {
                          datosSanidad['id'] = registro['id'];
                          await _dbHelper.updateSanidad(datosSanidad);
                          _mostrarMensaje('Sanidad actualizada con éxito');
                        } else {
                          await _dbHelper.insertSanidad(datosSanidad);
                          _mostrarMensaje('Sanidad registrada con éxito');
                        }
                        Navigator.pop(context);
                        _cargarDatos();
                      } catch (e) {
                        _mostrarMensaje('Error al guardar: $e');
                      }
                    }
                  },
                  child: Text(esEdicion ? 'Actualizar' : 'Guardar'),
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
      appBar: AppBar(
        title: const Text('Historial Sanitario'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: _cargarDatos,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sanidadList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.healing_outlined, size: 72, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay registros sanitarios',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Presiona el botón (+) para registrar un tratamiento.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _sanidadList.length,
                  itemBuilder: (context, index) {
                    final item = _sanidadList[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: const Icon(Icons.medical_services, color: Colors.green),
                        ),
                        title: Text(
                          '${item['tipo_tratamiento']} (${item['arete_asociado']})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Producto: ${item['producto']}'),
                              if (item['observaciones'] != null && item['observaciones'].toString().isNotEmpty)
                                Text('Obs: ${item['observaciones']}', style: TextStyle(color: Colors.grey[700])),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text('Fecha: ${item['fecha']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.more_vert),
                        onTap: () => _mostrarOpcionesSanidad(item),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioSanidad(),
        tooltip: 'Registrar Sanidad',
        child: const Icon(Icons.add),
      ),
    );
  }
}
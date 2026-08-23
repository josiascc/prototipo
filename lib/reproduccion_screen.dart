import 'package:flutter/material.dart';
import 'database_helper.dart';

class ReproduccionScreen extends StatefulWidget {
  const ReproduccionScreen({Key? key}) : super(key: key);

  @override
  State<ReproduccionScreen> createState() => _ReproduccionScreenState();
}

class _ReproduccionScreenState extends State<ReproduccionScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _reproduccionList = [];
  List<Map<String, dynamic>> _ganadoList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // Carga el historial reproductivo y la lista de ganado disponible
  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final reproDatos = await _dbHelper.queryAllReproduccion();
      final ganadoDatos = await _dbHelper.queryAllGanado();
      setState(() {
        _reproduccionList = reproDatos;
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

  // Eliminar un registro reproductivo
  Future<void> _eliminarReproduccion(int id) async {
    try {
      await _dbHelper.deleteReproduccion(id);
      _mostrarMensaje('Registro reproductivo eliminado');
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
        content: Text('¿Deseas eliminar este registro de reproducción (${registro['tipo_evento']})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarReproduccion(registro['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Opciones al tocar un registro (Editar o Eliminar)
  void _mostrarOpcionesReproduccion(Map<String, dynamic> registro) {
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
                leading: const Icon(Icons.favorite, color: Colors.pink),
                title: Text('Evento: ${registro['tipo_evento']}'),
                subtitle: Text('Arete: ${registro['arete_asociado']} - Fecha: ${registro['fecha']}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text('Editar registro'),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarFormularioReproduccion(registro: registro);
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

  // Formulario para Registrar o Editar Reproducción
  void _mostrarFormularioReproduccion({Map<String, dynamic>? registro}) {
    if (_ganadoList.isEmpty) {
      _mostrarMensaje('Primero debes registrar al menos un animal en la sección de Ganado.');
      return;
    }

    final bool esEdicion = registro != null;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final TextEditingController notasController = TextEditingController(
      text: esEdicion ? registro['notas'] : '',
    );
    final TextEditingController fechaController = TextEditingController(
      text: esEdicion ? registro['fecha'] : DateTime.now().toString().split(' ')[0],
    );

    String? areteSeleccionado = esEdicion 
        ? registro['arete_asociado'] 
        : _ganadoList.first['arete'];

    String? eventoSeleccionado = esEdicion 
        ? registro['tipo_evento'] 
        : 'Inseminación';

    final List<String> tiposEventos = [
      'Celo',
      'Inseminación',
      'Monta Natural',
      'Diagnóstico de Preñez',
      'Parto',
      'Aborto',
      'Otro'
    ];

    if (esEdicion && !tiposEventos.contains(eventoSeleccionado)) {
      tiposEventos.add(eventoSeleccionado!);
    }

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
              title: Text(esEdicion ? 'Editar Reproducción' : 'Registrar Evento Reproductivo'),
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

                      // Dropdown para Tipo de Evento
                      DropdownButtonFormField<String>(
                        value: eventoSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Evento',
                          prefixIcon: Icon(Icons.favorite_outline),
                          border: OutlineInputBorder(),
                        ),
                        items: tiposEventos.map((String evento) {
                          return DropdownMenuItem<String>(
                            value: evento,
                            child: Text(evento),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setDialogState(() {
                            eventoSeleccionado = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Campo Fecha
                      TextFormField(
                        controller: fechaController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha del Evento',
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

                      // Campo Notas
                      TextFormField(
                        controller: notasController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notas o Observaciones (Opcional)',
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
                      final Map<String, dynamic> datosRepro = {
                        'arete_asociado': areteSeleccionado,
                        'tipo_evento': eventoSeleccionado,
                        'fecha': fechaController.text,
                        'notas': notasController.text.trim(),
                      };

                      try {
                        if (esEdicion) {
                          datosRepro['id'] = registro['id'];
                          await _dbHelper.updateReproduccion(datosRepro);
                          _mostrarMensaje('Reproducción actualizada con éxito');
                        } else {
                          await _dbHelper.insertReproduccion(datosRepro);
                          _mostrarMensaje('Reproducción registrada con éxito');
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
        title: const Text('Control Reproductivo'),
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
          : _reproduccionList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pets, size: 72, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay registros reproductivos',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Presiona el botón (+) para registrar un evento.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _reproduccionList.length,
                  itemBuilder: (context, index) {
                    final item = _reproduccionList[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.pink[100],
                          child: const Icon(Icons.favorite, color: Colors.pink),
                        ),
                        title: Text(
                          '${item['tipo_evento']} (Arete: ${item['arete_asociado']})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item['notas'] != null && item['notas'].toString().isNotEmpty)
                                Text('Notas: ${item['notas']}', style: TextStyle(color: Colors.grey[700])),
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
                        onTap: () => _mostrarOpcionesReproduccion(item),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioReproduccion(),
        tooltip: 'Registrar Evento',
        child: const Icon(Icons.add),
      ),
    );
  }
}
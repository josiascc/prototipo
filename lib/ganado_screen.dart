import 'package:flutter/material.dart';
import 'database_helper.dart';

class GanadoScreen extends StatefulWidget {
  const GanadoScreen({Key? key}) : super(key: key);

  @override
  State<GanadoScreen> createState() => _GanadoScreenState();
}

class _GanadoScreenState extends State<GanadoScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _ganadoList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarGanado();
  }

  // Carga todos los animales de la base de datos
  Future<void> _cargarGanado() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final datos = await _dbHelper.queryAllGanado();
      setState(() {
        _ganadoList = datos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _mostrarMensaje('Error al cargar ganado: $e');
    }
  }

  // Muestra un mensaje rápido en la parte inferior (SnackBar)
  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  // Elimina un animal de la base de datos
  Future<void> _eliminarGanado(int id) async {
    try {
      await _dbHelper.deleteGanado(id);
      _mostrarMensaje('Animal eliminado correctamente');
      _cargarGanado();
    } catch (e) {
      _mostrarMensaje('Error al eliminar: $e');
    }
  }

  // Diálogo para confirmar la eliminación de un animal
  void _mostrarConfirmacionEliminar(Map<String, dynamic> animal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar el animal con arete "${animal['arete']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarGanado(animal['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Diálogo de opciones al presionar un elemento de la lista (Editar o Eliminar)
  void _mostrarOpcionesAnimal(Map<String, dynamic> animal) {
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
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: Text(
                  'Arete: ${animal['arete']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${animal['categoria']} - ${animal['raza']}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text('Editar datos'),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarFormularioGanado(animal: animal);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar de la base de datos'),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarConfirmacionEliminar(animal);
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

  // Abre el formulario en un diálogo para agregar o editar un animal
  void _mostrarFormularioGanado({Map<String, dynamic>? animal}) {
    final bool esEdicion = animal != null;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    // Controladores de texto para los campos
    final TextEditingController areteController = TextEditingController(
      text: esEdicion ? animal['arete'] : '',
    );
    final TextEditingController razaController = TextEditingController(
      text: esEdicion ? animal['raza'] : '',
    );
    final TextEditingController fechaController = TextEditingController(
      text: esEdicion ? animal['fecha_ingreso'] : DateTime.now().toString().split(' ')[0],
    );

    // Valores por defecto para dropdowns
    String? categoriaSeleccionada = esEdicion ? animal['categoria'] : 'Vaca';
    String? sexoSeleccionado = esEdicion ? animal['sexo'] : 'Hembra';

    // Listas de opciones
    final List<String> categorias = ['Vaca', 'Toro', 'Novilla', 'Novillo', 'Ternera', 'Ternero'];
    final List<String> sexos = ['Hembra', 'Macho'];

    // Asegurar que si el valor de la edición no está en la lista estándar, se agregue temporalmente o se ajuste
    if (esEdicion && !categorias.contains(categoriaSeleccionada)) {
      categorias.add(categoriaSeleccionada!);
    }
    if (esEdicion && !sexos.contains(sexoSeleccionado)) {
      sexos.add(sexoSeleccionado!);
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
              title: Text(esEdicion ? 'Editar Animal' : 'Registrar Nuevo Animal'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Campo Arete (Código único de identificación)
                      TextFormField(
                        controller: areteController,
                        decoration: const InputDecoration(
                          labelText: 'Número de Arete (ID)',
                          prefixIcon: Icon(Icons.tag),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa el número de arete';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Campo Categoría (Dropdown)
                      DropdownButtonFormField<String>(
                        value: categoriaSeleccionada,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                        ),
                        items: categorias.map((String cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setDialogState(() {
                            categoriaSeleccionada = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Campo Raza (Texto)
                      TextFormField(
                        controller: razaController,
                        decoration: const InputDecoration(
                          labelText: 'Raza / Cruce',
                          prefixIcon: Icon(Icons.pets),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa la raza';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Campo Sexo (Dropdown)
                      DropdownButtonFormField<String>(
                        value: sexoSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Sexo',
                          prefixIcon: Icon(Icons.transgender),
                          border: OutlineInputBorder(),
                        ),
                        items: sexos.map((String sexo) {
                          return DropdownMenuItem<String>(
                            value: sexo,
                            child: Text(sexo),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setDialogState(() {
                            sexoSeleccionado = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Campo Fecha de Ingreso
                      TextFormField(
                        controller: fechaController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha de Ingreso',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        onTap: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: esEdicion 
                                ? (DateTime.tryParse(animal['fecha_ingreso']) ?? DateTime.now())
                                : DateTime.now(),
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
                      final Map<String, dynamic> datosAnimal = {
                        'arete': areteController.text.trim(),
                        'categoria': categoriaSeleccionada,
                        'raza': razaController.text.trim(),
                        'sexo': sexoSeleccionado,
                        'fecha_ingreso': fechaController.text,
                      };

                      try {
                        if (esEdicion) {
                          datosAnimal['id'] = animal['id'];
                          await _dbHelper.updateGanado(datosAnimal);
                          _mostrarMensaje('Animal actualizado con éxito');
                        } else {
                          await _dbHelper.insertGanado(datosAnimal);
                          _mostrarMensaje('Animal registrado con éxito');
                        }
                        Navigator.pop(context); // Cerrar diálogo del formulario
                        _cargarGanado(); // Refrescar lista
                      } catch (e) {
                        // Manejo específico si el arete ya existe (restricción UNIQUE)
                        if (e.toString().contains('UNIQUE constraint failed')) {
                          _mostrarMensaje('Error: Ya existe un animal registrado con el arete "${areteController.text.trim()}"');
                        } else {
                          _mostrarMensaje('Error al guardar datos: $e');
                        }
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
        title: const Text('Control de Ganado'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar Lista',
            onPressed: _cargarGanado,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ganadoList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pets_outlined,
                          size: 72,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay ganado registrado',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Presiona el botón flotante (+) para registrar tu primer animal.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _ganadoList.length,
                  itemBuilder: (context, index) {
                    final animal = _ganadoList[index];
                    final String sexo = animal['sexo'] ?? 'Hembra';
                    final bool esHembra = sexo.toLowerCase() == 'hembra';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: esHembra ? Colors.pink[100] : Colors.blue[100],
                          child: Icon(
                            esHembra ? Icons.female : Icons.male,
                            color: esHembra ? Colors.pink[700] : Colors.blue[700],
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              'Arete: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${animal['arete']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Categoría: ${animal['categoria']}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text('Raza: ${animal['raza']}'),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Ingreso: ${animal['fecha_ingreso']}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.more_vert),
                        onTap: () => _mostrarOpcionesAnimal(animal),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioGanado(),
        tooltip: 'Agregar Animal',
        child: const Icon(Icons.add),
      ),
    );
  }
}

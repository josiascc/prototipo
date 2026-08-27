import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_date_field.dart';
import '../widgets/animal_selector_dropdown.dart'; // <--- Añade esta línea
import 'configuracion_screen.dart';

class GanadoDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> animal;

  const GanadoDetalleScreen({Key? key, required this.animal}) : super(key: key);

  @override
  State<GanadoDetalleScreen> createState() => _GanadoDetalleScreenState();
}

class _GanadoDetalleScreenState extends State<GanadoDetalleScreen> {
  late Map<String, dynamic> _datosAnimal;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _datosAnimal = widget.animal;
  }

  // Método auxiliar para convertir fecha ISO (yyyy-mm-dd) a visual (dd/mm/aaaa) para los campos de texto
  String _convertirISOaVisual(String? fechaIso) {
    if (fechaIso == null || fechaIso.isEmpty) return '';
    try {
      final partes = fechaIso.split('T')[0].split('-');
      if (partes.length == 3) {
        return '${partes[2]}/${partes[1]}/${partes[0]}';
      }
    } catch (_) {}
    return fechaIso;
  }

  // Método auxiliar para convertir fecha visual (dd/mm/aaaa) a ISO (yyyy-mm-dd) para la BD
  String _convertirFechaAISO(String fechaVisual) {
    try {
      final partes = fechaVisual.trim().split('/');
      if (partes.length == 3) {
        return '${partes[2]}-${partes[1]}-${partes[0]}';
      }
    } catch (_) {}
    return fechaVisual;
  }

  String _obtenerSexoPorCategoria(String categoria) {
    if (categoria == 'Vaca' || categoria == 'Novilla') {
      return 'Hembra';
    } else if (categoria == 'Toro') {
      return 'Macho';
    }
    return 'Hembra'; // Predeterminado
  }

  Future<String> _guardarFotoEnCarpetaFotos(File imagenOriginal, String arete) async {
    final fotosDir = Directory(await DatabaseHelper.getFotosDirectoryPath());
    final extension = imagenOriginal.path.split('.').last;
    final nombreArchivo = 'ganado_${arete.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final nuevaRuta = '${fotosDir.path}/$nombreArchivo';
    final imagenGuardada = await imagenOriginal.copy(nuevaRuta);
    return imagenGuardada.path;
  }

  void _confirmarEliminacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Animal'),
        content: Text('¿Estás seguro de eliminar el registro del arete ${_datosAnimal['arete']}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final dbHelper = DatabaseHelper();
              await dbHelper.deleteGanado(_datosAnimal['id']);
              Navigator.pop(context); // Cierra diálogo
              Navigator.pop(context, true); // Vuelve a la lista indicando cambio
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ==================== DIÁLOGO DE EDICIÓN ====================
  void _mostrarModalEditarGanado() {
    final _areteController = TextEditingController(text: _datosAnimal['arete'] ?? '');
    final _nombreController = TextEditingController(text: _datosAnimal['nombre'] ?? '');
    final _fechaNacimientoController = TextEditingController(text: _convertirISOaVisual(_datosAnimal['fecha_nacimiento']));
    
    bool _incluirFechaIngreso = _datosAnimal['fecha_ingreso'] != null && _datosAnimal['fecha_ingreso'].toString().isNotEmpty;
    final _fechaIngresoController = TextEditingController(text: _convertirISOaVisual(_datosAnimal['fecha_ingreso']));

    String _razaSeleccionada = _datosAnimal['raza'] ?? 'Mestizo / Cruce';
    
    bool _registrarPadres = (_datosAnimal['madre_arete'] != null || _datosAnimal['padre_arete'] != null);
    int? _madreIdSeleccionada = _datosAnimal['madre_id'];
    String? _madreAreteStr = _datosAnimal['madre_arete'];
    int? _padreIdSeleccionado = _datosAnimal['padre_id'];
    String? _padreAreteStr = _datosAnimal['padre_arete'];
    
    File? _imagenSeleccionadaNueva;

    final List<String> _razasDisponibles = [
      'Nelore', 'Nelore Mocho', 'Brahman', 'Gyr', 'Girolando',
      'Holstein', 'Pardo Suizo (Brown Swiss)', 'Pardo x Gyr (Gyropar)',
      'Brangus', 'Criollo', 'Mestizo / Cruce',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Editar Ganado: Arete ${_datosAnimal['arete']}'),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _areteController,
                        decoration: const InputDecoration(labelText: 'Número de Arete *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre (Opcional)'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _razasDisponibles.contains(_razaSeleccionada) ? _razaSeleccionada : _razasDisponibles.first,
                        decoration: const InputDecoration(labelText: 'Raza'),
                        isExpanded: true,
                        items: _razasDisponibles
                            .map((raza) => DropdownMenuItem(value: raza, child: Text(raza)))
                            .toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            _razaSeleccionada = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomDateField(
                        controller: _fechaNacimientoController,
                        labelText: 'Fecha de Nacimiento (dd/mm/aaaa)',
                        hintText: 'Ej: 15/01/2024',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _incluirFechaIngreso,
                            onChanged: (val) {
                              setStateDialog(() {
                                _incluirFechaIngreso = val ?? false;
                              });
                            },
                          ),
                          const Text('Registrar Fecha de Ingreso'),
                        ],
                      ),
                      if (_incluirFechaIngreso) ... [
                        CustomDateField(
                          controller: _fechaIngresoController,
                          labelText: 'Fecha de Ingreso (dd/mm/aaaa)',
                          hintText: 'Ej: 26/08/2026',
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Imagen
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final XFile? fotoXFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 800);
                                  if (fotoXFile != null) {
                                    setStateDialog(() => _imagenSeleccionadaNueva = File(fotoXFile.path));
                                  }
                                },
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text('Cambiar Foto'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                              ),
                            ],
                          ),
                          Container(
                            width: 65,
                            height: 65,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8.0),
                              color: Colors.grey.shade100,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: _imagenSeleccionadaNueva != null
                                  ? Image.file(_imagenSeleccionadaNueva!, fit: BoxFit.cover)
                                  : (_datosAnimal['foto'] != null && File(_datosAnimal['foto']).existsSync())
                                      ? Image.file(File(_datosAnimal['foto']), fit: BoxFit.cover)
                                      : const Center(child: Text('Sin foto', style: TextStyle(fontSize: 10))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _registrarPadres,
                            onChanged: (val) {
                              setStateDialog(() {
                                _registrarPadres = val ?? false;
                                if (!_registrarPadres) {
                                  _madreIdSeleccionada = null;
                                  _madreAreteStr = null;
                                  _padreIdSeleccionado = null;
                                  _padreAreteStr = null;
                                }
                              });
                            },
                          ),
                          const Text('Modificar Madre y Padre'),
                        ],
                      ),
                      if (_registrarPadres) ... [
                        const SizedBox(height: 8),
                        AnimalSelectorDropdown(
                          label: 'Arete Madre',
                          filtroSexo: 'Hembra',
                          initialId: _madreIdSeleccionada,
                          initialArete: _madreAreteStr,
                          onChanged: (id, arete) {
                            _madreIdSeleccionada = id;
                            _madreAreteStr = arete;
                          },
                        ),
                        const SizedBox(height: 12),
                        AnimalSelectorDropdown(
                          label: 'Arete Padre',
                          filtroSexo: 'Macho',
                          initialId: _padreIdSeleccionado,
                          initialArete: _padreAreteStr,
                          onChanged: (id, arete) {
                            _padreIdSeleccionado = id;
                            _padreAreteStr = arete;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (_areteController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El número de arete es obligatorio.')),
                      );
                      return;
                    }

                    String? rutaFotoFinal = _datosAnimal['foto'];
                    if (_imagenSeleccionadaNueva != null) {
                      rutaFotoFinal = await _guardarFotoEnCarpetaFotos(_imagenSeleccionadaNueva!, _areteController.text);
                    }

                    final datosActualizados = {
                      'arete': _areteController.text.trim(),
                      'nombre': _nombreController.text.trim().isEmpty ? null : _nombreController.text.trim(),
                      'raza': _razaSeleccionada,
                      'sexo': _obtenerSexoPorCategoria(_datosAnimal['categoria'] ?? 'Vaca'),
                      'fecha_nacimiento': _fechaNacimientoController.text.trim().isEmpty ? null : _convertirFechaAISO(_fechaNacimientoController.text.trim()),
                      'fecha_ingreso': _incluirFechaIngreso && _fechaIngresoController.text.trim().isNotEmpty ? _convertirFechaAISO(_fechaIngresoController.text.trim()) : null,
                      'madre_id': _madreIdSeleccionada,
                      'padre_id': _padreIdSeleccionado,
                      'madre_arete': _madreAreteStr,
                      'padre_arete': _padreAreteStr,
                      'foto': rutaFotoFinal,
                    };

                    final dbHelper = DatabaseHelper();
                    await dbHelper.updateGanado(_datosAnimal['id'], datosActualizados);

                    // Actualizamos el estado local para que refleje los cambios instantáneamente al cerrar el modal
                    setState(() {
                      _datosAnimal = {
                        ..._datosAnimal,
                        ...datosActualizados,
                      };
                    });

                    Navigator.pop(context); // Cierra modal
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('¡Datos del animal actualizados con éxito!')),
                    );
                  },
                  child: const Text('Guardar Cambios'),
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
    final String? fotoPath = _datosAnimal['foto'];
    final bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();
    final String? nombre = _datosAnimal['nombre'];
    final String arete = _datosAnimal['arete'] ?? 'Sin arete';
    final String categoria = _datosAnimal['categoria'] ?? 'No especificada';
    final String raza = _datosAnimal['raza'] ?? 'No especificada';
    final String sexo = _datosAnimal['sexo'] ?? 'No especificado';
    
    final String fechaNacimiento = ConfiguracionScreen.formatearFechaVisual(_datosAnimal['fecha_nacimiento']);
    final String fechaIngreso = ConfiguracionScreen.formatearFechaVisual(_datosAnimal['fecha_ingreso']);
    
    final String estado = _datosAnimal['estado'] ?? 'Activo';
    final String? madreArete = _datosAnimal['madre_arete'];
    final String? padreArete = _datosAnimal['padre_arete'];

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true); // Notifica a la pantalla anterior que hubo cambios o visualización
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Detalle: Arete $arete'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, true),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Editar animal',
              onPressed: _mostrarModalEditarGanado,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Eliminar animal',
              onPressed: () => _confirmarEliminacion(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryGreen, width: 2),
                    color: Colors.grey.shade200,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: esArchivoLocal
                        ? Image.file(
                            File(fotoPath),
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            sexo == 'Hembra' ? Icons.female : Icons.male,
                            size: 70,
                            color: AppTheme.primaryGreen,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                nombre != null && nombre.isNotEmpty ? 'Arete: $arete ($nombre)' : 'Arete: $arete',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  'Estado: $estado',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: estado == 'Activo' ? AppTheme.primaryGreen : Colors.grey,
              ),
              const SizedBox(height: 20),
              CustomCard(
                title: 'Información General',
                items: [
                  DetailItem(icon: Icons.category, label: 'Categoría', value: categoria),
                  DetailItem(icon: Icons.pets, label: 'Raza', value: raza),
                  DetailItem(icon: sexo == 'Hembra' ? Icons.female : Icons.male, label: 'Sexo', value: sexo),
                  DetailItem(icon: Icons.cake, label: 'Fecha de Nacimiento', value: fechaNacimiento),
                  DetailItem(icon: Icons.login, label: 'Fecha de Ingreso', value: fechaIngreso),
                  DetailItem(icon: Icons.family_restroom, label: 'Madre', value: madreArete ?? 'No registrada'),
                  DetailItem(icon: Icons.family_restroom, label: 'Padre', value: padreArete ?? 'No registrado'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
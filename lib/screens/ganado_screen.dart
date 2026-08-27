import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/animal_selector_dropdown.dart';
import 'ganado_detalle_screen.dart';
import '../widgets/custom_date_field.dart';
import 'configuracion_screen.dart'; // <--- 1. Importa configuracion_screen.dart

class GanadoScreen extends StatefulWidget {
  const GanadoScreen({Key? key}) : super(key: key);

  @override
  State<GanadoScreen> createState() => _GanadoScreenState();
}

class _GanadoScreenState extends State<GanadoScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _listaGanado = [];
  bool _isLoading = true;
  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargarGanado();
  }

  // Consultar animales activos
  Future<void> _cargarGanado() async {
    setState(() => _isLoading = true);
    final data = await _dbHelper.queryAllGanadoActivo();
    setState(() {
      _listaGanado = data;
      _isLoading = false;
    });
  }

  // Diálogo rápido para registrar un nuevo animal (alta)
  void _mostrarModalRegistrarGanado() {
    final _areteController = TextEditingController();
    final _nombreController = TextEditingController();
    final _fechaNacimientoController = TextEditingController();
    
    // 2. Aplicamos formatearFechaVisual a la fecha actual por defecto
    final String fechaHoyISO = DateTime.now().toIso8601String().split('T')[0];
    final _fechaIngresoController = TextEditingController(
      text: ConfiguracionScreen.formatearFechaVisual(fechaHoyISO),
    );

    String _categoriaSeleccionada = 'Vaca';
    String _razaSeleccionada = 'Mestizo / Cruce';
    bool _incluirFechaIngreso = false;
    
    // Variables para padres
    bool _registrarPadres = false;
    int? _madreIdSeleccionada;
    String? _madreAreteStr;
    int? _padreIdSeleccionado;
    String? _padreAreteStr;
    
    _imagenSeleccionada = null;

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
              title: const Text('Registrar Ganado'),
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
                      // Categoría (El sexo se determina automáticamente)
                      DropdownButtonFormField<String>(
                        value: _categoriaSeleccionada,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: ['Vaca', 'Toro', 'Ternero', 'Novilla', 'Ceba']
                            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            _categoriaSeleccionada = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _razaSeleccionada,
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
                      // Checkbox para registrar Padre y Madre
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
                          const Text('Registrar Madre y Padre'),
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
                      // Sección de Foto (Cámara / Galería y Vista previa)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _seleccionarImagen(ImageSource.camera, setStateDialog),
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text('Cámara'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(120, 36),
                                ),
                              ),
                              const SizedBox(height: 6),
                              ElevatedButton.icon(
                                onPressed: () => _seleccionarImagen(ImageSource.gallery, setStateDialog),
                                icon: const Icon(Icons.photo_library, size: 18),
                                label: const Text('Galería'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[700],
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(120, 36),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Vista previa
                          Container(
                            width: 65,
                            height: 65,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8.0),
                              color: Colors.grey.shade100,
                            ),
                            child: _imagenSeleccionada != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.file(
                                      _imagenSeleccionada!,
                                      width: 65,
                                      height: 65,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Center(
                                    child: Text(
                                      'Sin foto',
                                      style: TextStyle(color: Colors.grey, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                          ),
                        ],
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
                    if (_areteController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El número de arete es obligatorio.')),
                      );
                      return;
                    }

                    String? rutaFotoFinal;
                    if (_imagenSeleccionada != null) {
                      rutaFotoFinal = await _guardarFotoEnCarpetaFotos(
                        _imagenSeleccionada!,
                        _areteController.text,
                      );
                    }

                    await _dbHelper.insertGanado({
                      'arete': _areteController.text.trim(),
                      'nombre': _nombreController.text.trim().isEmpty ? null : _nombreController.text.trim(),
                      'categoria': _categoriaSeleccionada,
                      'raza': _razaSeleccionada,
                      'sexo': _obtenerSexoPorCategoria(_categoriaSeleccionada),
                      'fecha_nacimiento': _fechaNacimientoController.text.trim().isEmpty
                          ? null
                          : _convertirFechaAISO(_fechaNacimientoController.text.trim()),
                      'fecha_ingreso': _incluirFechaIngreso && _fechaIngresoController.text.trim().isNotEmpty
                          ? _convertirFechaAISO(_fechaIngresoController.text.trim())
                          : null,
                      'estado': 'Activo',
                      'madre_id': _madreIdSeleccionada,
                      'padre_id': _padreIdSeleccionado,
                      'madre_arete': _madreAreteStr,
                      'padre_arete': _padreAreteStr,
                      'foto': rutaFotoFinal,
                    });
                    Navigator.pop(context);
                    _cargarGanado();
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

  // Método para seleccionar desde Cámara o Galería
  Future<void> _seleccionarImagen(ImageSource source, StateSetter setStateDialog) async {
    final XFile? fotoXFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );

    if (fotoXFile != null) {
      setStateDialog(() {
        _imagenSeleccionada = File(fotoXFile.path);
      });
    }
  }

  // Método auxiliar para guardar la foto en la carpeta 'fotos' con nombre único basado en el arete
  Future<String?> _guardarFotoEnCarpetaFotos(File archivoTemporal, String areteAnimal) async {
    try {
      final String fotosPath = await DatabaseHelper.getFotosDirectoryPath();
      final String areteLimpio = areteAnimal.trim().replaceAll(RegExp(r'[^\w\s]+'), '_');
      final String extension = p.extension(archivoTemporal.path);
      final String fileName = 'ganado_${areteLimpio}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final String destinoPath = p.join(fotosPath, fileName);

      final File archivoFinal = await archivoTemporal.copy(destinoPath);
      return archivoFinal.path;
    } catch (e) {
      print('Error al guardar la foto: $e');
      return null;
    }
  }

  String _obtenerSexoPorCategoria(String categoria) {
      if (categoria == 'Vaca' || categoria == 'Novilla') {
        return 'Hembra';
      }
      return 'Macho'; // Toro, Ternero, Ceba
    }

  // Convierte '26/08/2026' a '2026-08-26' para SQLite
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listaGanado.isEmpty
              ? const Center(
                  child: Text(
                    'No hay animales registrados.\nPresiona el botón de la vaquita para agregar uno.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _listaGanado.length,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    final animal = _listaGanado[index];
                    final String? fotoPath = animal['foto'];
                    final String? nombre = animal['nombre'];

                    bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                          backgroundImage: esArchivoLocal
                              ? FileImage(File(fotoPath)) as ImageProvider
                              : null,
                          child: !esArchivoLocal
                              ? Icon(
                                  animal['sexo'] == 'Hembra' ? Icons.female : Icons.male,
                                  color: AppTheme.primaryGreen,
                                )
                              : null,
                        ),
                        title: Text(
                          nombre != null && nombre.isNotEmpty
                              ? 'Arete: ${animal['arete']} ($nombre)'
                              : 'Arete: ${animal['arete']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Categoría: ${animal['categoria']} | Raza: ${animal['raza']}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final eliminado = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GanadoDetalleScreen(animal: animal),
                            ),
                          );
                          
                          // Si se eliminó el animal, recargamos la lista
                          if (eliminado == true) {
                            _cargarGanado();
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarModalRegistrarGanado,
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Registrar Animal',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
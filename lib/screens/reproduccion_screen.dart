import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/animal_selector_dropdown.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_date_field.dart';
import 'configuracion_screen.dart';

class ReproduccionScreen extends StatefulWidget {
  const ReproduccionScreen({Key? key}) : super(key: key);

  @override
  State<ReproduccionScreen> createState() => _ReproduccionScreenState();
}

class _ReproduccionScreenState extends State<ReproduccionScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _listaReproduccion = [];
  bool _isLoading = true;

  // Variables para filtros y menú flotante (FAB)
  String _filtroActivo = 'todos';
  bool _menuFabAbierto = false;
  final TextEditingController _searchController = TextEditingController();
  double _filterTop = 88.0;
  double _filterRight = 10.0;

  // Métricas para los 3 paneles superiores
  int _totalProduccion = 0;
  int _totalGestantes = 0;
  int _totalVacias = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosReproduccion();
  }

  // Convierte '26/08/2026' a '2026-08-26' para SQLite y DateTime.parse
  String _convertirFechaAISO(String fechaVisual) {
    if (fechaVisual.isEmpty) return DateTime.now().toIso8601String().split('T')[0];
    if (fechaVisual.contains('-')) return fechaVisual;
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

  Future<void> _cargarDatosReproduccion() async {
    setState(() => _isLoading = true);

    final data = await _dbHelper.queryAllReproduccionConGanado();
    final stats = await _dbHelper.getEstadisticasReproduccion();

    if (!mounted) return;

    setState(() {
      _listaReproduccion = data;
      _totalProduccion = stats['produccion'] ?? 0;
      _totalGestantes = stats['gestantes'] ?? 0;
      _totalVacias = stats['vacias'] ?? 0;
      _isLoading = false;
    });
  }

  String _obtenerNombreFiltroCorto(String filtro) {
    switch (filtro) {
      case 'produccion': return 'Producción';
      case 'vacia': return 'Vacía';
      case 'celo': return 'Celo';
      case 'gestante': return 'Gestante';
      case 'secas': return 'Secas';
      case 'inseminada': return 'Inseminada';
      case 'monta': return 'Monta';
      case 'proximo_celo': return 'Próximo celo';
      default: return 'Todos';
    }
  }

  // Enrutador de formularios del FAB
  void _mostrarModalRegistrarReproduccion({required String tipoInicial}) {
    setState(() => _menuFabAbierto = false);

    switch (tipoInicial) {
      case 'celo':
        _mostrarFormularioCelo();
        break;
      case 'inseminacion':
        _mostrarFormularioInseminacion();
        break;
      case 'monta_natural':
        _mostrarFormularioMonta();
        break;
      case 'diagnostico_prenez':
        _mostrarFormularioControlPrenez();
        break;
      case 'parto':
        _mostrarFormularioParto();
        break;
      case 'aborto':
        _mostrarFormularioAborto();
        break;
    }
  }

  // ==================== 1. FORMULARIO CELO ====================
  Future<void> _mostrarFormularioCelo() async {
    List<Map<String, dynamic>> animalesActivos = await _dbHelper.queryAllGanadoActivo();
    List<Map<String, dynamic>> hembras = animalesActivos.where((a) => (a['sexo'] ?? '').toString() == 'Hembra').toList();

    if (hembras.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero debes registrar hembras.')));
      return;
    }

    int? animalIdSeleccionado = hembras.first['id'];
    String? areteSeleccionado = hembras.first['arete'];
    
    final String fechaHoyISO = DateTime.now().toIso8601String().split('T')[0];
    final fechaController = TextEditingController(text: ConfiguracionScreen.formatearFechaVisual(fechaHoyISO));
    final horaController = TextEditingController(text: TimeOfDay.now().format(context));
    final observadorController = TextEditingController();
    final notasController = TextEditingController();

    String intensidadSeleccionada = 'Moderado';
    List<String> signosDisponibles = ['Moco cristalino', 'Se deja montar', 'Inquietud', 'Vulva inflamada', 'Bramido frecuente'];
    List<String> signosSeleccionados = [];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Registrar Celo'),
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Seleccionar Animal *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      AnimalSelectorDropdown(
                        label: 'Hembra',
                        filtroSexo: 'Hembra',
                        initialId: animalIdSeleccionado,
                        initialArete: areteSeleccionado,
                        onChanged: (id, arete) {
                          setStateDialog(() {
                            animalIdSeleccionado = id;
                            areteSeleccionado = arete;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomDateField(
                              controller: fechaController,
                              labelText: '2. Fecha de Detección (dd/mm/aaaa)',
                              lastDate: DateTime(2100),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: horaController,
                              decoration: const InputDecoration(labelText: 'Hora Aprox', suffixIcon: Icon(Icons.access_time, size: 18)),
                              readOnly: true,
                              onTap: () async {
                                TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                if (time != null) setStateDialog(() => horaController.text = time.format(context));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('3. Signos observados del celo:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...signosDisponibles.map((signo) => CheckboxListTile(
                            title: Text(signo, style: const TextStyle(fontSize: 14)),
                            value: signosSeleccionados.contains(signo),
                            activeColor: AppTheme.primaryGreen,
                            dense: true,
                            onChanged: (bool? val) {
                              setStateDialog(() {
                                if (val == true) {
                                  signosSeleccionados.add(signo);
                                } else {
                                  signosSeleccionados.remove(signo);
                                }
                              });
                            },
                          )),
                      const SizedBox(height: 12),
                      const Text('4. Intensidad del Celo:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['Débil', 'Moderado', 'Fuerte'].map((nivel) {
                          bool seleccionado = intensidadSeleccionada == nivel;
                          return InkWell(
                            onTap: () => setStateDialog(() => intensidadSeleccionada = nivel),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: seleccionado ? AppTheme.primaryGreen : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                nivel,
                                style: TextStyle(color: seleccionado ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: observadorController, decoration: const InputDecoration(labelText: '5. Observador Responsable')),
                      const SizedBox(height: 12),
                      TextField(controller: notasController, decoration: const InputDecoration(labelText: '6. Notas Opcionales'), maxLines: 2),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (animalIdSeleccionado != null && areteSeleccionado != null) {
                      await _dbHelper.insertReproduccion({
                        'ganado_id': animalIdSeleccionado,
                        'arete_asociado': areteSeleccionado,
                        'tipo_evento': 'Celo',
                        'fecha': _convertirFechaAISO(fechaController.text.trim()),
                        'notas': 'Hora: ${horaController.text} | Intensidad: $intensidadSeleccionada | Signos: ${signosSeleccionados.join(', ')} | Obs: ${observadorController.text} ${notasController.text}',
                      });
                      if (!mounted) return;
                      Navigator.pop(context);
                      _cargarDatosReproduccion();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona o indica un animal válido.')));
                    }
                  },
                  child: const Text('Guardar Registro', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== 2. FORMULARIO INSEMINACIÓN ====================
  Future<void> _mostrarFormularioInseminacion() async {
    List<Map<String, dynamic>> animalesActivos = await _dbHelper.queryAllGanadoActivo();
    List<Map<String, dynamic>> hembras = animalesActivos.where((a) => (a['sexo'] ?? '').toString() == 'Hembra').toList();

    if (hembras.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero debes registrar hembras.')));
      return;
    }

    List<Map<String, dynamic>> animalesSeleccionados = [];
    final String fechaHoyISO = DateTime.now().toIso8601String().split('T')[0];
    final fechaController = TextEditingController(text: ConfiguracionScreen.formatearFechaVisual(fechaHoyISO));
    final horaController = TextEditingController(text: TimeOfDay.now().format(context));
    final idToroController = TextEditingController();
    final procedenciaController = TextEditingController();
    final inseminadorController = TextEditingController();
    final numInseminacionController = TextEditingController(text: '1');

    String tipoSemen = 'Congelado (pajilla)';
    String protocolo = 'Inseminación a celo visto';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            void _abrirBuscadorMultiple() async {
              String queryBusqueda = '';
              await showDialog(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setStateBuscador) {
                      final filtrados = hembras.where((a) {
                        final arete = (a['arete'] ?? '').toString().toLowerCase();
                        final nombre = (a['nombre'] ?? '').toString().toLowerCase();
                        final q = queryBusqueda.toLowerCase();
                        return arete.contains(q) || nombre.contains(q);
                      }).toList();

                      return AlertDialog(
                        title: const Text('Seleccionar Hembras (Múltiple)'),
                        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        content: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.85,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Buscar por arete o nombre',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (val) => setStateBuscador(() => queryBusqueda = val),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 400,
                                child: filtrados.isEmpty
                                    ? const Center(child: Text('No se encontraron hembras.'))
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: filtrados.length,
                                        itemBuilder: (context, index) {
                                          final animal = filtrados[index];
                                          final arete = animal['arete'] ?? '';
                                          final nombre = animal['nombre'];
                                          final categoria = animal['categoria'] ?? '';
                                          final fotoPath = animal['foto'];
                                          bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();
                                          bool seleccionado = animalesSeleccionados.any((a) => a['id'] == animal['id']);

                                          return CheckboxListTile(
                                            value: seleccionado,
                                            activeColor: AppTheme.primaryGreen,
                                            secondary: CircleAvatar(
                                              backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                                              backgroundImage: esArchivoLocal ? FileImage(File(fotoPath)) : null,
                                              child: !esArchivoLocal ? const Icon(Icons.female, color: AppTheme.primaryGreen) : null,
                                            ),
                                            title: Text('Arete: $arete ${nombre != null && nombre.isNotEmpty ? '($nombre)' : ''}'),
                                            subtitle: Text('Categoría: $categoria'),
                                            onChanged: (val) {
                                              setStateBuscador(() {
                                                if (val == true) {
                                                  animalesSeleccionados.add(animal);
                                                } else {
                                                  animalesSeleccionados.removeWhere((a) => a['id'] == animal['id']);
                                                }
                                              });
                                              setStateDialog(() {});
                                            },
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Listo'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            }

            return AlertDialog(
              title: const Text('Registrar Inseminación'),
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('1. Seleccionar Hembras *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.search, color: AppTheme.primaryGreen, size: 28),
                            tooltip: 'Buscar hembras',
                            onPressed: _abrirBuscadorMultiple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      animalesSeleccionados.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Text('Aún no se seleccionaron hembras.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: animalesSeleccionados.length,
                              itemBuilder: (context, index) {
                                final animal = animalesSeleccionados[index];
                                final fotoPath = animal['foto'];
                                bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                                      backgroundImage: esArchivoLocal ? FileImage(File(fotoPath)) : null,
                                      child: !esArchivoLocal ? const Icon(Icons.female, color: AppTheme.primaryGreen) : null,
                                    ),
                                    title: Text('Arete: ${animal['arete']} ${animal['nombre'] != null ? '(${animal['nombre']})' : ''}'),
                                    subtitle: Text('Categoría: ${animal['categoria'] ?? 'Hembra'}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => setStateDialog(() => animalesSeleccionados.removeAt(index)),
                                    ),
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CustomDateField(
                              controller: fechaController,
                              labelText: '2. Fecha Inseminación (dd/mm/aaaa)',
                              lastDate: DateTime(2100),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: horaController,
                              decoration: const InputDecoration(labelText: 'Hora', suffixIcon: Icon(Icons.access_time, size: 18)),
                              readOnly: true,
                              onTap: () async {
                                TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                if (time != null) setStateDialog(() => horaController.text = time.format(context));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tipoSemen,
                        decoration: const InputDecoration(labelText: '3. Tipo de Semen'),
                        items: ['Congelado (pajilla)', 'Fresco'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setStateDialog(() => tipoSemen = val!),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: idToroController, decoration: const InputDecoration(labelText: '4. ID de Toro o Pajilla')),
                      const SizedBox(height: 12),
                      TextField(controller: procedenciaController, decoration: const InputDecoration(labelText: '5. Procedencia del Semen')),
                      const SizedBox(height: 12),
                      TextField(controller: inseminadorController, decoration: const InputDecoration(labelText: '6. Inseminador Responsable')),
                      const SizedBox(height: 12),
                      TextField(controller: numInseminacionController, decoration: const InputDecoration(labelText: '7. Número de Inseminación en el ciclo'), keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: protocolo,
                        decoration: const InputDecoration(labelText: '8. Protocolo Utilizado'),
                        items: ['Inseminación a celo visto', 'IATF'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setStateDialog(() => protocolo = val!),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (animalesSeleccionados.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos un animal.')));
                      return;
                    }
                    for (var animal in animalesSeleccionados) {
                      await _dbHelper.insertReproduccion({
                        'ganado_id': animal['id'],
                        'arete_asociado': animal['arete'],
                        'tipo_evento': 'Inseminación',
                        'fecha': _convertirFechaAISO(fechaController.text.trim()),
                        'notas': 'Semen: $tipoSemen | ID Toro: ${idToroController.text} | Inseminador: ${inseminadorController.text} | Num: ${numInseminacionController.text} | Protocolo: $protocolo',
                      });
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    _cargarDatosReproduccion();
                  },
                  child: const Text('Guardar Registro', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== 3. FORMULARIO MONTA NATURAL ====================
  Future<void> _mostrarFormularioMonta() async {
    List<Map<String, dynamic>> animalesActivos = await _dbHelper.queryAllGanadoActivo();
    List<Map<String, dynamic>> hembras = animalesActivos.where((a) => (a['sexo'] ?? '').toString() == 'Hembra').toList();
    List<Map<String, dynamic>> machos = animalesActivos.where((a) => (a['sexo'] ?? '').toString() == 'Macho').toList();

    if (hembras.isEmpty || machos.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Se requiere al menos una hembra y un macho registrados.')));
      return;
    }

    int? vacaId = hembras.first['id'];
    String? vacaArete = hembras.first['arete'];
    int? toroId = machos.first['id'];
    String? toroArete = machos.first['arete'];

    final String fechaHoyISO = DateTime.now().toIso8601String().split('T')[0];
    final fechaController = TextEditingController(text: ConfiguracionScreen.formatearFechaVisual(fechaHoyISO));
    final obsController = TextEditingController();
    String tipoServicio = 'Dirigida';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Registrar Monta Natural'),
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Seleccionar Vaca (Hembra) *', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      AnimalSelectorDropdown(
                        label: 'Vaca',
                        filtroSexo: 'Hembra',
                        initialId: vacaId,
                        initialArete: vacaArete,
                        onChanged: (id, arete) {
                          setStateDialog(() {
                            vacaId = id;
                            vacaArete = arete;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('2. Seleccionar Toro (Macho) *', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      AnimalSelectorDropdown(
                        label: 'Toro',
                        filtroSexo: 'Macho',
                        initialId: toroId,
                        initialArete: toroArete,
                        onChanged: (id, arete) {
                          setStateDialog(() {
                            toroId = id;
                            toroArete = arete;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomDateField(
                        controller: fechaController,
                        labelText: '3. Fecha de Monta (dd/mm/aaaa)',
                        lastDate: DateTime(2100),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tipoServicio,
                        decoration: const InputDecoration(labelText: '4. Tipo de Servicio'),
                        items: ['Libre en potrero', 'Dirigida'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setStateDialog(() => tipoServicio = val!),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: obsController, decoration: const InputDecoration(labelText: '5. Observaciones'), maxLines: 2),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (vacaId != null && vacaArete != null && toroArete != null) {
                      await _dbHelper.insertReproduccion({
                        'ganado_id': vacaId,
                        'arete_asociado': vacaArete,
                        'tipo_evento': 'Monta',
                        'fecha': _convertirFechaAISO(fechaController.text.trim()),
                        'notas': 'Toro Arete: $toroArete | Tipo: $tipoServicio | Obs: ${obsController.text}',
                      });
                      if (!mounted) return;
                      Navigator.pop(context);
                      _cargarDatosReproduccion();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona la vaca y el toro correctamente.')));
                    }
                  },
                  child: const Text('Guardar Registro', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== 4. FORMULARIO CONTROL DE PREÑEZ ====================
  Future<void> _mostrarFormularioControlPrenez() async {
    List<Map<String, dynamic>> animalesActivos = await _dbHelper.queryAllGanadoActivo();
    List<Map<String, dynamic>> hembras = animalesActivos.where((a) => (a['sexo'] ?? '').toString() == 'Hembra').toList();

    if (hembras.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero debes registrar hembras.')));
      return;
    }

    List<Map<String, dynamic>> animalesSeleccionados = [];
    final String fechaHoyISO = DateTime.now().toIso8601String().split('T')[0];
    final fechaController = TextEditingController(text: ConfiguracionScreen.formatearFechaVisual(fechaHoyISO));
    String metodoDiagnostico = 'Palpación rectal';
    
    Map<int, Map<String, dynamic>> datosPrenezPorAnimal = {};

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {

            void _abrirBuscadorMultiple() async {
              String queryBusqueda = '';
              await showDialog(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setStateBuscador) {
                      final filtrados = hembras.where((a) {
                        final arete = (a['arete'] ?? '').toString().toLowerCase();
                        final nombre = (a['nombre'] ?? '').toString().toLowerCase();
                        final q = queryBusqueda.toLowerCase();
                        return arete.contains(q) || nombre.contains(q);
                      }).toList();

                      return AlertDialog(
                        title: const Text('1. Selector de animal múltiple'),
                        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        content: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: 350,
                          child: Column(
                            children: [
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Buscar por arete o nombre',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (val) => setStateBuscador(() => queryBusqueda = val),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: filtrados.isEmpty
                                    ? const Center(child: Text('No se encontraron hembras.'))
                                    : ListView.builder(
                                        itemCount: filtrados.length,
                                        itemBuilder: (context, index) {
                                          final animal = filtrados[index];
                                          final arete = animal['arete'] ?? '';
                                          final nombre = animal['nombre'];
                                          final categoria = animal['categoria'] ?? '';
                                          final fotoPath = animal['foto'];
                                          bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();
                                          bool seleccionado = animalesSeleccionados.any((a) => a['id'] == animal['id']);

                                          return CheckboxListTile(
                                            value: seleccionado,
                                            activeColor: AppTheme.primaryGreen,
                                            secondary: CircleAvatar(
                                              backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                                              backgroundImage: esArchivoLocal ? FileImage(File(fotoPath)) : null,
                                              child: !esArchivoLocal ? const Icon(Icons.female, color: AppTheme.primaryGreen) : null,
                                            ),
                                            title: Text('Arete: $arete ${nombre != null && nombre.isNotEmpty ? '($nombre)' : ''}'),
                                            subtitle: Text('Categoría: $categoria'),
                                            onChanged: (val) async {
                                              setStateBuscador(() {
                                                if (val == true) {
                                                  animalesSeleccionados.add(animal);
                                                } else {
                                                  animalesSeleccionados.removeWhere((a) => a['id'] == animal['id']);
                                                  datosPrenezPorAnimal.remove(animal['id']);
                                                }
                                              });

                                              if (val == true) {
                                                final db = await _dbHelper.database;
                                                final eventosPrevios = await db.query(
                                                  'reproduccion',
                                                  where: 'ganado_id = ?',
                                                  whereArgs: [animal['id']],
                                                  orderBy: 'id DESC',
                                                );
                                                datosPrenezPorAnimal[animal['id']] = {
                                                  'resultado': 'Positivo',
                                                  'eventos': eventosPrevios,
                                                  'evento_seleccionado': eventosPrevios.isNotEmpty ? eventosPrevios.first['fecha'] : _convertirFechaAISO(fechaController.text.trim()),
                                                  'agregar_nota': false,
                                                  'nota_controller': TextEditingController(),
                                                };
                                              }

                                              setStateDialog(() {});
                                            },
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Listo'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            }

            return AlertDialog(
              title: const Text('Control de Preñez'),
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('1. Selector de animal múltiple *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.search, color: AppTheme.primaryGreen, size: 28),
                            tooltip: 'Buscar animales',
                            onPressed: _abrirBuscadorMultiple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      animalesSeleccionados.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Text('Aún no se seleccionaron animales.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: animalesSeleccionados.length,
                              itemBuilder: (context, index) {
                                final animal = animalesSeleccionados[index];
                                final fotoPath = animal['foto'];
                                bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                                      backgroundImage: esArchivoLocal ? FileImage(File(fotoPath)) : null,
                                      child: !esArchivoLocal ? const Icon(Icons.female, color: AppTheme.primaryGreen) : null,
                                    ),
                                    title: Text('Arete: ${animal['arete']} ${animal['nombre'] != null ? '(${animal['nombre']})' : ''}'),
                                    subtitle: Text('Categoría: ${animal['categoria'] ?? 'Hembra'}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        setStateDialog(() {
                                          animalesSeleccionados.removeAt(index);
                                          datosPrenezPorAnimal.remove(animal['id']);
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 16),
                      CustomDateField(
                        controller: fechaController,
                        labelText: '2. Fecha de Evento (dd/mm/aaaa)',
                        lastDate: DateTime(2100),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: metodoDiagnostico,
                        decoration: const InputDecoration(labelText: '3. Método de Diagnóstico'),
                        items: ['Palpación rectal', 'Ecografía', 'Prueba de sangre'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setStateDialog(() => metodoDiagnostico = val!),
                      ),
                      const SizedBox(height: 16),
                      const Text('4. Resultados y Detalles por Animal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      animalesSeleccionados.isEmpty
                          ? const Text('Ningún animal seleccionado.', style: TextStyle(color: Colors.grey))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: animalesSeleccionados.length,
                              itemBuilder: (context, index) {
                                final animal = animalesSeleccionados[index];
                                final fotoPath = animal['foto'];
                                bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();
                                
                                final datosAnimal = datosPrenezPorAnimal[animal['id']] ?? {};
                                String resultadoActual = datosAnimal['resultado'] ?? 'Positivo';
                                List<Map<String, dynamic>> eventosPrevios = datosAnimal['eventos'] ?? [];
                                String? eventoSeleccionado = datosAnimal['evento_seleccionado'];
                                bool agregarNota = datosAnimal['agregar_nota'] ?? false;
                                TextEditingController notaCtrl = datosAnimal['nota_controller'] ?? TextEditingController();

                                String fechaPartoEstimada = 'N/A';
                                try {
                                  String baseStr = _convertirFechaAISO(eventoSeleccionado ?? fechaController.text.trim());
                                  DateTime baseDate = DateTime.parse(baseStr);
                                  String fppISO = baseDate.add(const Duration(days: 283)).toIso8601String().split('T')[0];
                                  fechaPartoEstimada = ConfiguracionScreen.formatearFechaVisual(fppISO);
                                } catch (_) {}

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                                              backgroundImage: esArchivoLocal ? FileImage(File(fotoPath)) : null,
                                              child: !esArchivoLocal ? const Icon(Icons.female, color: AppTheme.primaryGreen, size: 18) : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text('Arete: ${animal['arete']} ${animal['nombre'] != null ? '(${animal['nombre']})' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            ),
                                          ],
                                        ),
                                        const Divider(),
                                        const Text('Resultado de diagnóstico:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: RadioListTile<String>(
                                                title: const Text('Positivo (+)', style: TextStyle(fontSize: 13)),
                                                value: 'Positivo',
                                                groupValue: resultadoActual,
                                                activeColor: AppTheme.primaryGreen,
                                                contentPadding: EdgeInsets.zero,
                                                onChanged: (val) => setStateDialog(() => datosPrenezPorAnimal[animal['id']]!['resultado'] = val!),
                                              ),
                                            ),
                                            Expanded(
                                              child: RadioListTile<String>(
                                                title: const Text('Negativo (-)', style: TextStyle(fontSize: 13)),
                                                value: 'Negativo',
                                                groupValue: resultadoActual,
                                                activeColor: Colors.red,
                                                contentPadding: EdgeInsets.zero,
                                                onChanged: (val) => setStateDialog(() => datosPrenezPorAnimal[animal['id']]!['resultado'] = val!),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        const Text('Posible fecha de cruce / evento previo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        eventosPrevios.isEmpty
                                            ? const Text('No hay eventos previos registrados para este animal.', style: TextStyle(fontSize: 12, color: Colors.grey))
                                            : Column(
                                                children: eventosPrevios.map((ev) {
                                                  String fechaEv = ev['fecha'] ?? '';
                                                  String fechaEvVisual = ConfiguracionScreen.formatearFechaVisual(fechaEv);
                                                  String tipoEv = ev['tipo_evento'] ?? '';
                                                  return RadioListTile<String>(
                                                    title: Text('$tipoEv - Fecha: $fechaEvVisual', style: const TextStyle(fontSize: 12)),
                                                    value: fechaEv,
                                                    groupValue: eventoSeleccionado,
                                                    dense: true,
                                                    activeColor: AppTheme.primaryGreen,
                                                    contentPadding: EdgeInsets.zero,
                                                    onChanged: (val) => setStateDialog(() => datosPrenezPorAnimal[animal['id']]!['evento_seleccionado'] = val!),
                                                  );
                                                }).toList(),
                                              ),
                                        const SizedBox(height: 6),
                                        if (resultadoActual == 'Positivo')
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(color: AppTheme.lightGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.cake, color: AppTheme.primaryGreen, size: 18),
                                                const SizedBox(width: 8),
                                                Text('Fecha probable de parto: $fechaPartoEstimada', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryGreen)),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        CheckboxListTile(
                                          title: const Text('Agregar nota u observación', style: TextStyle(fontSize: 13)),
                                          value: agregarNota,
                                          activeColor: AppTheme.primaryGreen,
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          onChanged: (val) => setStateDialog(() => datosPrenezPorAnimal[animal['id']]!['agregar_nota'] = val!),
                                        ),
                                        if (agregarNota)
                                          TextField(
                                            controller: notaCtrl,
                                            decoration: const InputDecoration(labelText: 'Escribir observación'),
                                            maxLines: 2,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (animalesSeleccionados.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos un animal.')));
                      return;
                    }

                    String fechaEventoISO = _convertirFechaAISO(fechaController.text.trim());

                    for (var animal in animalesSeleccionados) {
                      final datos = datosPrenezPorAnimal[animal['id']] ?? {};
                      String res = datos['resultado'] ?? 'Positivo';
                      bool conNota = datos['agregar_nota'] ?? false;
                      String notaExtra = conNota ? (datos['nota_controller'] as TextEditingController).text : '';
                      String cruceUsadoISO = _convertirFechaAISO(datos['evento_seleccionado'] ?? fechaController.text.trim());

                      await _dbHelper.insertReproduccion({
                        'ganado_id': animal['id'],
                        'arete_asociado': animal['arete'],
                        'tipo_evento': 'Diagnóstico Preñez',
                        'diagnostico': res == 'Positivo' ? 'Gestante' : 'Vacía',
                        'fecha': fechaEventoISO,
                        'fecha_servicio': cruceUsadoISO,
                        'notas': 'Método: $metodoDiagnostico | Resultado: $res ${notaExtra.isNotEmpty ? '| Nota: $notaExtra' : ''}',
                      });
                      if (res == 'Positivo') {
                        try {
                          DateTime baseDate = DateTime.parse(cruceUsadoISO);
                          DateTime fechaParto = baseDate.add(const Duration(days: 283));
                          
                          // Calcular 15 días antes para la alerta de preparto
                          DateTime fechaAlertaPreparto = fechaParto.subtract(const Duration(days: 15));
                          String fechaProgramadaStr = fechaAlertaPreparto.toIso8601String().split('T')[0];
                          String fechaPartoStr = ConfiguracionScreen.formatearFechaVisual(fechaParto.toIso8601String().split('T')[0]);
                      
                          await _dbHelper.insertarActividad({
                            'titulo': '(FPP: $fechaPartoStr) - Arete ${animal['arete']}',
                            'tipo_lote': 'Gestante',
                            'fecha_programada': fechaProgramadaStr,
                            'completada': 0,
                          });
                        } catch (_) {}
                      }
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    _cargarDatosReproduccion();
                  },
                  child: const Text('Guardar Registro', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== 5. FORMULARIO REGISTRAR PARTO ====================
  Future<void> _mostrarFormularioParto() async {
    List<Map<String, dynamic>> animalesActivos = await _dbHelper.queryAllGanadoActivo();
    List<Map<String, dynamic>> hembras = animalesActivos.where((a) => (a['sexo'] ?? '').toString() == 'Hembra').toList();
    List<Map<String, dynamic>> machos = animalesActivos.where((a) => (a['sexo'] ?? '').toString() == 'Macho').toList();

    if (hembras.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero debes registrar hembras.')));
      return;
    }

    int? vacaId = hembras.first['id'];
    String? vacaArete = hembras.first['arete'];
    int? padreId = machos.isNotEmpty ? machos.first['id'] : null;
    String? padreArete = machos.isNotEmpty ? machos.first['arete'] : null;

    final String fechaHoyISO = DateTime.now().toIso8601String().split('T')[0];
    final fechaController = TextEditingController(text: ConfiguracionScreen.formatearFechaVisual(fechaHoyISO));
    String tipoParto = 'Natural';
    int numeroCrias = 1;

    List<Map<String, dynamic>> detallesCrias = [
      {'genero': 'Macho', 'arete': TextEditingController(), 'desc': TextEditingController()}
    ];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {

            void actualizarNumeroCrias(int nuevoNum) {
              if (nuevoNum >= 1 && nuevoNum <= 4) {
                setStateDialog(() {
                  numeroCrias = nuevoNum;
                  if (detallesCrias.length < numeroCrias) {
                    while (detallesCrias.length < numeroCrias) {
                      detallesCrias.add({'genero': 'Macho', 'arete': TextEditingController(), 'desc': TextEditingController()});
                    }
                  } else if (detallesCrias.length > numeroCrias) {
                    detallesCrias.removeRange(numeroCrias, detallesCrias.length);
                  }
                });
              }
            }

            return AlertDialog(
              title: const Text('Registrar Parto'),
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Seleccionar Vaca (Madre) *', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      AnimalSelectorDropdown(
                        label: 'Vaca',
                        filtroSexo: 'Hembra',
                        initialId: vacaId,
                        initialArete: vacaArete,
                        onChanged: (id, arete) {
                          setStateDialog(() {
                            vacaId = id;
                            vacaArete = arete;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomDateField(
                        controller: fechaController,
                        labelText: '2. Fecha de Parto (dd/mm/aaaa)',
                        lastDate: DateTime(2100),
                      ),
                      DropdownButtonFormField<String>(
                        value: tipoParto,
                        decoration: const InputDecoration(labelText: '3. Tipo de Parto'),
                        items: ['Natural', 'Distócico (asistido)', 'Cesárea'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setStateDialog(() => tipoParto = val!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('4. Número de crías:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryGreen),
                                onPressed: () => actualizarNumeroCrias(numeroCrias - 1),
                              ),
                              Text('$numeroCrias', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGreen),
                                onPressed: () => actualizarNumeroCrias(numeroCrias + 1),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('5. Padre de la Cría (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      AnimalSelectorDropdown(
                        label: 'Padre',
                        filtroSexo: 'Macho',
                        initialId: padreId,
                        initialArete: padreArete,
                        onChanged: (id, arete) {
                          setStateDialog(() {
                            padreId = id;
                            padreArete = arete;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('6. Detalles de las crías:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      ...List.generate(detallesCrias.length, (index) {
                        final cria = detallesCrias[index];
                        final String? fotoCriaPath = cria['foto'];
                        bool esFotoLocal = fotoCriaPath != null && fotoCriaPath.isNotEmpty && File(fotoCriaPath).existsSync();

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cría #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _seleccionarFotoCria(setStateDialog, cria),
                                      child: Container(
                                        width: 65,
                                        height: 65,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5)),
                                          image: esFotoLocal
                                              ? DecorationImage(image: FileImage(File(fotoCriaPath)), fit: BoxFit.cover)
                                              : null,
                                        ),
                                        child: !esFotoLocal
                                            ? const Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.camera_alt, color: AppTheme.primaryGreen, size: 22),
                                                  SizedBox(height: 2),
                                                  Text('Foto', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                ],
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          DropdownButtonFormField<String>(
                                            value: cria['genero'],
                                            decoration: const InputDecoration(labelText: 'Género'),
                                            items: ['Macho', 'Hembra'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                            onChanged: (val) => setStateDialog(() => cria['genero'] = val!),
                                          ),
                                          TextField(controller: cria['arete'], decoration: const InputDecoration(labelText: 'Arete de la cría')),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(controller: cria['desc'], decoration: const InputDecoration(labelText: 'Descripción / Color')),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (vacaId != null && vacaArete != null) {
                      List<Map<String, dynamic>> criasAInsertar = detallesCrias.map((cria) {
                        return {
                          'arete': (cria['arete'] as TextEditingController).text,
                          'genero': cria['genero'],
                          'descripcion': (cria['desc'] as TextEditingController).text,
                          'foto': cria['foto'],
                        };
                      }).toList();

                      await _dbHelper.registrarPartoConCesionDeCrias(
                        eventoParto: {
                          'ganado_id': vacaId,
                          'arete_asociado': vacaArete,
                          'tipo_evento': 'Parto',
                          'fecha': _convertirFechaAISO(fechaController.text.trim()),
                          'notas': 'Tipo: $tipoParto | Crías: $numeroCrias | Padre: ${padreArete ?? 'N/A'}',
                        },
                        listaCrias: criasAInsertar,
                      );

                      if (!mounted) return;
                      Navigator.pop(context);
                      _cargarDatosReproduccion();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona la vaca correctamente.')));
                    }
                  },
                  child: const Text('Guardar Registro', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== 6. FORMULARIO ABORTO ====================
  Future<void> _mostrarFormularioAborto() async {
    List<Map<String, dynamic>> animalesActivos = await _dbHelper.queryAllGanadoActivo();
    List<Map<String, dynamic>> hembras = animalesActivos.where((a) => (a['sexo'] ?? '').toString() == 'Hembra').toList();

    if (hembras.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero debes registrar hembras.')));
      return;
    }

    int? animalId = hembras.first['id'];
    String? areteAnimal = hembras.first['arete'];

    final String fechaHoyISO = DateTime.now().toIso8601String().split('T')[0];
    final fechaController = TextEditingController(text: ConfiguracionScreen.formatearFechaVisual(fechaHoyISO));
    final notasController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Registrar Aborto'),
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Seleccionar Animal *', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      AnimalSelectorDropdown(
                        label: 'Hembra',
                        filtroSexo: 'Hembra',
                        initialId: animalId,
                        initialArete: areteAnimal,
                        onChanged: (id, arete) {
                          setStateDialog(() {
                            animalId = id;
                            areteAnimal = arete;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomDateField(
                        controller: fechaController,
                        labelText: '2. Fecha de evento (dd/mm/aaaa)',
                        lastDate: DateTime(2100),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: notasController, decoration: const InputDecoration(labelText: '3. Nota'), maxLines: 2),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (animalId != null && areteAnimal != null) {
                      await _dbHelper.insertReproduccion({
                        'ganado_id': animalId,
                        'arete_asociado': areteAnimal,
                        'tipo_evento': 'Aborto',
                        'fecha': _convertirFechaAISO(fechaController.text.trim()),
                        'notas': notasController.text.trim().isEmpty ? 'Vacia' : notasController.text.trim(),
                      });
                      if (!mounted) return;
                      Navigator.pop(context);
                      _cargarDatosReproduccion();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un animal válido.')));
                    }
                  },
                  child: const Text('Guardar Registro', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarDetalleReproduccion(Map<String, dynamic> item) {
    final String estadoTag = _determinarEstadoItem(item);
    final String fechaVisual = ConfiguracionScreen.formatearFechaVisual(item['fecha']);
    final String? fechaServicioISO = item['fecha_servicio'];
    final String fechaServicioVisual = ConfiguracionScreen.formatearFechaVisual(fechaServicioISO);
    
    String? fechaPartoEstimada;
    if (fechaServicioISO != null && fechaServicioISO.isNotEmpty) {
      try {
        DateTime baseDate = DateTime.parse(_convertirFechaAISO(fechaServicioISO));
        String fppISO = baseDate.add(const Duration(days: 283)).toIso8601String().split('T')[0];
        fechaPartoEstimada = ConfiguracionScreen.formatearFechaVisual(fppISO);
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                  Text('Ficha Reproductiva', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text('Arete del Animal: ${item['arete_asociado']} ${item['animal_nombre'] != null ? '(${item['animal_nombre']})' : ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Evento: ${item['tipo_evento']}'),
              const SizedBox(height: 6),
              Text('Fecha: $fechaVisual'),
              if (fechaServicioISO != null && fechaServicioISO.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Fecha de Servicio: $fechaServicioVisual'),
              ],
              if (fechaPartoEstimada != null && estadoTag == 'Gestante') ...[
                const SizedBox(height: 6),
                Text('Fecha Probable de Parto: $fechaPartoEstimada', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
              ],
              const SizedBox(height: 6),
              Text('Raza: ${item['animal_raza'] ?? 'No especificada'}'),
              const SizedBox(height: 12),
              const Text('Notas / Observaciones:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(item['notas']?.isEmpty == true ? 'Sin notas adicionales.' : item['notas']),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  String _determinarEstadoItem(Map<String, dynamic> item) {
    final evento = (item['tipo_evento'] ?? '').toString().toLowerCase();
    final diagnostico = (item['diagnostico'] ?? '').toString().toLowerCase();
    final notas = (item['notas'] ?? '').toString().toLowerCase();
    
    if (diagnostico.contains('gestante')) return 'Gestante';
    if (diagnostico.contains('vacía') || diagnostico.contains('vacia')) return 'Vacia';
  
    if (evento.contains('parto') || evento.contains('producción')) return 'Produccion';
    if (evento.contains('gestante') || notas.contains('gestante') || (evento.contains('diagnóstico') && notas.contains('positivo'))) return 'Gestante';
    if (evento.contains('inseminación') || evento.contains('inseminacion')) return 'Inseminada';
    if (evento.contains('monta')) return 'Monta';
    if (evento.contains('celo')) return 'Celo';
    if (evento.contains('secado')) return 'Secas';
    if (evento.contains('aborto') || evento.contains('vacía') || evento.contains('vacia') || (evento.contains('diagnóstico') && notas.contains('negativo'))) return 'Vacia';
    
    return 'Vacia';
  }

  @override
  Widget build(BuildContext context) {
    final textoBusqueda = _searchController.text.trim().toLowerCase();

    final listaFiltrada = _listaReproduccion.where((item) {
      final estadoActual = _determinarEstadoItem(item).toLowerCase();
      bool coincideFiltro = true;

      switch (_filtroActivo) {
        case 'produccion':
          coincideFiltro = estadoActual.contains('produccion');
          break;
        case 'vacia':
          coincideFiltro = estadoActual.contains('vacia');
          break;
        case 'celo':
          coincideFiltro = estadoActual.contains('celo');
          break;
        case 'gestante':
          coincideFiltro = estadoActual.contains('gestante');
          break;
        case 'secas':
          coincideFiltro = estadoActual.contains('secas');
          break;
        case 'inseminada':
          coincideFiltro = estadoActual.contains('inseminada');
          break;
        case 'monta':
          coincideFiltro = estadoActual.contains('monta');
          break;
        case 'proximo_celo':
          coincideFiltro = estadoActual.contains('celo');
          break;
        case 'todos':
        default:
          coincideFiltro = true;
          break;
      }

      final textoCompleto = '${item['arete_asociado']} ${item['animal_nombre']} ${item['tipo_evento']} ${item['animal_raza']} ${item['notas']}'.toLowerCase();
      final coincideTexto = textoCompleto.contains(textoBusqueda);

      return coincideFiltro && coincideTexto;
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(child: _buildPanelResumen('Producción', '$_totalProduccion', Icons.opacity, const Color(0xFFE5F4E8), AppTheme.primaryGreen)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildPanelResumen('Gestantes', '$_totalGestantes', Icons.favorite, const Color(0xFFE3F2FD), Colors.blue)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildPanelResumen('Vacías', '$_totalVacias', Icons.info_outline, const Color(0xFFFFEBEE), Colors.redAccent)),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : listaFiltrada.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay registros reproductivos.\nPresiona el botón "+" para registrar un evento.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: listaFiltrada.length,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemBuilder: (context, index) {
                              final item = listaFiltrada[index];
                              final String? fotoPath = item['animal_foto'];
                              final String? sexoAnimal = item['animal_sexo'];
                              final String arete = item['arete_asociado'] ?? '';
                              final String nombre = item['animal_nombre'] ?? '';
                              final String raza = item['animal_raza'] ?? 'No especificada';
                              final String fecha = item['fecha'] ?? '';
                              final String fechaVisual = ConfiguracionScreen.formatearFechaVisual(fecha);
                              final String estadoTag = _determinarEstadoItem(item);

                              bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();

                              String infoAdicional = 'Fecha: $fechaVisual';
                              if (estadoTag == 'Gestante') {
                                try {
                                  final String fechaServicioRaw = item['fecha_servicio'] ?? item['fecha'] ?? '';
                                  if (fechaServicioRaw.isNotEmpty) {
                                    final String fechaServicioISO = _convertirFechaAISO(fechaServicioRaw);
                                    final fechaInicio = DateTime.parse(fechaServicioISO);
                                    final dias = DateTime.now().difference(fechaInicio).inDays;
                                    final String servicioVisual = ConfiguracionScreen.formatearFechaVisual(fechaServicioISO);
                                    infoAdicional = 'Gestación: $dias días | Servicio: $servicioVisual';
                                  }
                                } catch (_) {}
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.primaryGreen, width: 1),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFF1C3540).withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                                    backgroundImage: esArchivoLocal ? FileImage(File(fotoPath)) : null,
                                    child: !esArchivoLocal
                                        ? Icon(
                                            sexoAnimal == 'Hembra' ? Icons.female : Icons.male,
                                            color: AppTheme.primaryGreen,
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    'Arete: $arete ${nombre.isNotEmpty ? '($nombre)' : ''}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Raza: $raza', style: const TextStyle(color: Color(0xFF6C8795), fontSize: 14)),
                                      const SizedBox(height: 3),
                                      Text(infoAdicional, style: const TextStyle(color: Color(0xFF6C8795), fontSize: 13)),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5F4E8),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      estadoTag,
                                      style: const TextStyle(color: Color(0xFF2D8235), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  onTap: () => _mostrarDetalleReproduccion(item),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          // Positioned ACTUAL DEL FILTRO:
          Positioned(
            top: _filterTop,
            right: _filterRight,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _filterTop += details.delta.dy;
                  _filterRight -= details.delta.dx; // Restar delta.dx mueve el botón horizontalmente respecto al borde derecho

                  // Límites para evitar que el botón salga de la pantalla
                  if (_filterTop < 0) _filterTop = 0;
                  if (_filterRight < 0) _filterRight = 0;
                  final screenHeight = MediaQuery.of(context).size.height - 100;
                  if (_filterTop > screenHeight) _filterTop = screenHeight;
                  final screenWidth = MediaQuery.of(context).size.width - 100;
                  if (_filterRight > screenWidth) _filterRight = screenWidth;
                });
              },
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.primaryGreen, width: 1.2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 4),
                      Icon(Icons.filter_list, size: 16, color: AppTheme.primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        _obtenerNombreFiltroCorto(_filtroActivo),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                  offset: const Offset(0, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) => setState(() => _filtroActivo = value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'todos', child: Text('Todos')),
                    const PopupMenuItem(value: 'produccion', child: Text('Producción')),
                    const PopupMenuItem(value: 'vacia', child: Text('Vacía')),
                    const PopupMenuItem(value: 'celo', child: Text('Celo')),
                    const PopupMenuItem(value: 'gestante', child: Text('Gestante')),
                    const PopupMenuItem(value: 'secas', child: Text('Secas')),
                    const PopupMenuItem(value: 'inseminada', child: Text('Inseminada')),
                    const PopupMenuItem(value: 'monta', child: Text('Monta')),
                    const PopupMenuItem(value: 'proximo_celo', child: Text('Próximo celo')),
                  ],
                ),
              ),
            ),
          ),
          if (_menuFabAbierto)
            GestureDetector(
              onTap: () => setState(() => _menuFabAbierto = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          if (_menuFabAbierto)
            Positioned(
              right: 20,
              bottom: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildFabOption('Aborto', Icons.cancel_outlined, () => _mostrarModalRegistrarReproduccion(tipoInicial: 'aborto')),
                  const SizedBox(height: 10),
                  _buildFabOption('Registrar Parto', Icons.child_care, () => _mostrarModalRegistrarReproduccion(tipoInicial: 'parto')),
                  const SizedBox(height: 10),
                  _buildFabOption('Control de Preñez', Icons.favorite_border, () => _mostrarModalRegistrarReproduccion(tipoInicial: 'diagnostico_prenez')),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white, thickness: 1.5),
                  const SizedBox(height: 4),
                  _buildFabOption('Monta Natural', Icons.pets, () => _mostrarModalRegistrarReproduccion(tipoInicial: 'monta_natural')),
                  const SizedBox(height: 10),
                  _buildFabOption('Inseminación', Icons.science, () => _mostrarModalRegistrarReproduccion(tipoInicial: 'inseminacion')),
                  const SizedBox(height: 10),
                  _buildFabOption('Celo', Icons.local_fire_department, () => _mostrarModalRegistrarReproduccion(tipoInicial: 'celo')),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryGreen,
        child: Icon(_menuFabAbierto ? Icons.close : Icons.add, color: Colors.white, size: 28),
        onPressed: () => setState(() => _menuFabAbierto = !_menuFabAbierto),
      ),
    );
  }

  Widget _buildPanelResumen(String titulo, String valor, IconData icono, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 16, color: textColor),
              const SizedBox(width: 4),
              Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        ],
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 18),
          ),
        ],
      ),
    );
  }

  // Función para seleccionar o tomar foto de la cría
  Future<void> _seleccionarFotoCria(StateSetter setStateDialog, Map<String, dynamic> cria) async {
    final ImagePicker picker = ImagePicker();
    
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primaryGreen),
                title: const Text('Tomar foto con la cámara'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (image != null) {
                    setStateDialog(() {
                      cria['foto'] = image.path;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.primaryGreen),
                title: const Text('Elegir de la galería'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (image != null) {
                    setStateDialog(() {
                      cria['foto'] = image.path;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
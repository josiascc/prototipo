import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_date_field.dart';
import 'configuracion_screen.dart';

class SanidadScreen extends StatefulWidget {
  const SanidadScreen({Key? key}) : super(key: key);

  @override
  State<SanidadScreen> createState() => _SanidadScreenState();
}

class _SanidadScreenState extends State<SanidadScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _listaSanidad = [];
  bool _isLoading = true;

  // Variables para el diseño interactivo y filtros
  String _filtroActivo = 'todas';
  bool _menuFabAbierto = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarSanidad();
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

  // Consultar historial de sanidad con datos del ganado asociado
  Future<void> _cargarSanidad() async {
    setState(() => _isLoading = true);
    
    final db = await _dbHelper.database;
    final data = await db.rawQuery('''
      SELECT s.*, g.sexo as animal_sexo, g.foto as animal_foto 
      FROM sanidad s 
      LEFT JOIN ganado g ON s.ganado_id = g.id 
      ORDER BY s.id DESC
    ''');

    setState(() {
      _listaSanidad = data;
      _isLoading = false;
    });
  }

  // Modal para registrar un nuevo tratamiento sanitario de forma dinámica
  void _mostrarModalRegistrarSanidad({String tipoInicial = 'Vacunacion'}) async {
    setState(() => _menuFabAbierto = false);
    List<Map<String, dynamic>> animalesActivos = await _dbHelper.queryAllGanadoActivo();

    if (animalesActivos.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero debes registrar al menos un animal en el módulo Ganado.')),
      );
      return;
    }

    String tipoSeleccionado = tipoInicial.toLowerCase(); 
    if (tipoSeleccionado == 'fumigacion/baño') {
      tipoSeleccionado = 'fumigacion';
    }

    // Inicializamos la fecha actual formateada en dd/mm/aaaa
    final String fechaHoyISO = DateTime.now().toIso8601String().split('T')[0];
    final String fechaHoyFormateada = ConfiguracionScreen.formatearFechaVisual(fechaHoyISO);

    // Controladores comunes y específicos
    final fechaController = TextEditingController(text: fechaHoyFormateada);
    final productoController = TextEditingController();
    final veterinarioController = TextEditingController();
    final loteController = TextEditingController();
    final observacionesController = TextEditingController();

    // Específicos Vacunación
    final tipoVacunaController = TextEditingController(text: 'Aftosa');
    final viaVacunaController = TextEditingController();
    double dosisVacuna = 5.0;

    // Específicos Fumigación
    String tipoFumigacionSeleccionado = 'Garrapaticida';
    String metodoFumigacionSeleccionado = 'Aspersión';

    // Específicos Desparasitación
    String tipoDesparasitanteSeleccionado = 'Mixto';
    String viaDesparasitacionSeleccionado = 'Inyectable';
    double dosisDesparasitacion = 10.0;

    // Específicos Tratamiento
    final diagnosticoController = TextEditingController();
    final medicamentoController = TextEditingController();
    final dosisTratamientoController = TextEditingController();
    String tipoTratamientoSeleccionado = 'Antibiótico';
    String viaTratamientoSeleccionado = 'Intramuscular';
    int duracionDias = 5;

    // Lista de animales seleccionados para este registro
    List<Map<String, dynamic>> animalesSeleccionados = [];

    if (!mounted) return;

    String obtenerTituloFormulario() {
      switch (tipoSeleccionado) {
        case 'vacunacion': return 'Registrar Vacunación';
        case 'fumigacion': return 'Registrar Fumigación / Baño';
        case 'desparasitacion': return 'Registrar Desparasitación';
        case 'tratamiento': return 'Registrar Tratamiento Clínico';
        default: return 'Registrar Tratamiento Sanitario';
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            Future<void> _abrirBuscadorAnimales() async {
              String queryBusqueda = '';
              await showDialog(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setStateBuscador) {
                      final animalesFiltrados = animalesActivos.where((a) {
                        final arete = (a['arete'] ?? '').toString().toLowerCase();
                        final nombre = (a['nombre'] ?? '').toString().toLowerCase();
                        final q = queryBusqueda.toLowerCase();
                        return arete.contains(q) || nombre.contains(q);
                      }).toList();

                      return AlertDialog(
                        title: const Text('Seleccionar Animales'),
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
                                onChanged: (val) {
                                  setStateBuscador(() {
                                    queryBusqueda = val;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 400,
                                child: animalesFiltrados.isEmpty
                                    ? const Center(child: Text('No se encontraron animales.'))
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: animalesFiltrados.length,
                                        itemBuilder: (context, index) {
                                          final animal = animalesFiltrados[index];
                                          final arete = animal['arete'] ?? '';
                                          final nombre = animal['nombre'];
                                          final categoria = animal['categoria'] ?? '';
                                          final fotoPath = animal['foto'];
                                          final sexoAnimal = animal['sexo'];
                                          bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();
                                          final yaSeleccionado = animalesSeleccionados.any((a) => a['id'] == animal['id']);

                                          return CheckboxListTile(
                                            value: yaSeleccionado,
                                            activeColor: AppTheme.primaryGreen,
                                            secondary: CircleAvatar(
                                              backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                                              backgroundImage: esArchivoLocal ? FileImage(File(fotoPath)) : null,
                                              child: !esArchivoLocal
                                                  ? Icon(
                                                      sexoAnimal == 'Hembra' ? Icons.female : Icons.male,
                                                      color: AppTheme.primaryGreen,
                                                    )
                                                  : null,
                                            ),
                                            title: Text('Arete: $arete ${nombre != null && nombre.isNotEmpty ? '($nombre)' : ''}'),
                                            subtitle: Text('Categoría: $categoria'),
                                            onChanged: (bool? selected) {
                                              setStateBuscador(() {
                                                if (selected == true) {
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
              title: Text(obtenerTituloFormulario()),
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================== 1. VACUNACIÓN ====================
                      if (tipoSeleccionado == 'vacunacion') ... [
                        TextField(
                          controller: tipoVacunaController,
                          decoration: const InputDecoration(labelText: 'Tipo de Vacuna *'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: productoController,
                          decoration: const InputDecoration(labelText: 'Producto / Nombre Comercial *'),
                        ),
                        const SizedBox(height: 12),
                        CustomDateField(
                          controller: fechaController,
                          labelText: 'Fecha de Aplicación (dd/mm/aaaa)',
                          hintText: 'Ej: 26/08/2026',
                          lastDate: DateTime(2100),
                        ),
                        const SizedBox(height: 12),
                        _buildStepperControl('Dosis en ml', dosisVacuna, 1, 100, (val) => dosisVacuna = val, setStateDialog),
                        const SizedBox(height: 12),
                        TextField(
                          controller: viaVacunaController,
                          decoration: const InputDecoration(labelText: 'Vía de Aplicación (Ej: Subcutánea)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: loteController,
                          decoration: const InputDecoration(labelText: 'Lote del Producto'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: veterinarioController,
                          decoration: const InputDecoration(labelText: 'Veterinario Responsable'),
                        ),
                      ],

                      // ==================== 2. FUMIGACIÓN ====================
                      if (tipoSeleccionado == 'fumigacion') ... [
                        DropdownButtonFormField<String>(
                          value: tipoFumigacionSeleccionado,
                          decoration: const InputDecoration(labelText: 'Tipo de Fumigación'),
                          items: ['Garrapaticida', 'Control de moscas', 'Baño sanitario']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) => setStateDialog(() => tipoFumigacionSeleccionado = val!),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: productoController,
                          decoration: const InputDecoration(labelText: 'Producto / Nombre Comercial *'),
                        ),
                        const SizedBox(height: 12),
                        CustomDateField(
                          controller: fechaController,
                          labelText: 'Fecha de Aplicación (dd/mm/aaaa)',
                          hintText: 'Ej: 26/08/2026',
                          lastDate: DateTime(2100),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: metodoFumigacionSeleccionado,
                          decoration: const InputDecoration(labelText: 'Método de Aplicación'),
                          items: ['Aspersión', 'Baño', 'Pulverización']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) => setStateDialog(() => metodoFumigacionSeleccionado = val!),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: loteController,
                          decoration: const InputDecoration(labelText: 'Lote del Producto'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: veterinarioController,
                          decoration: const InputDecoration(labelText: 'Veterinario Responsable'),
                        ),
                      ],

                      // ==================== 3. DESPARASITACIÓN ====================
                      if (tipoSeleccionado == 'desparasitacion') ... [
                        DropdownButtonFormField<String>(
                          value: tipoDesparasitanteSeleccionado,
                          decoration: const InputDecoration(labelText: 'Tipo de Desparasitante'),
                          items: ['Mixto', 'Interno', 'Externo']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) => setStateDialog(() => tipoDesparasitanteSeleccionado = val!),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: productoController,
                          decoration: const InputDecoration(labelText: 'Producto / Nombre Comercial *'),
                        ),
                        const SizedBox(height: 12),
                        CustomDateField(
                          controller: fechaController,
                          labelText: 'Fecha de Aplicación (dd/mm/aaaa)',
                          hintText: 'Ej: 26/08/2026',
                          lastDate: DateTime(2100),
                        ),
                        const SizedBox(height: 12),
                        _buildStepperControl('Dosis en ml', dosisDesparasitacion, 1, 200, (val) => dosisDesparasitacion = val, setStateDialog),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: viaDesparasitacionSeleccionado,
                          decoration: const InputDecoration(labelText: 'Vía de Aplicación'),
                          items: ['Inyectable', 'Oral', 'Tópica']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) => setStateDialog(() => viaDesparasitacionSeleccionado = val!),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: loteController,
                          decoration: const InputDecoration(labelText: 'Lote del Producto'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: veterinarioController,
                          decoration: const InputDecoration(labelText: 'Veterinario Responsable'),
                        ),
                      ],

                      // ==================== 4. TRATAMIENTO ====================
                      if (tipoSeleccionado == 'tratamiento') ... [
                        TextField(
                          controller: diagnosticoController,
                          decoration: const InputDecoration(labelText: 'Diagnóstico / Motivo *'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: tipoTratamientoSeleccionado,
                          decoration: const InputDecoration(labelText: 'Tipo de Tratamiento'),
                          items: ['Antibiótico', 'Antiinflamatorio', 'Suplementación']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) => setStateDialog(() => tipoTratamientoSeleccionado = val!),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: medicamentoController,
                          decoration: const InputDecoration(labelText: 'Medicamento *'),
                        ),
                        const SizedBox(height: 12),
                        CustomDateField(
                          controller: fechaController,
                          labelText: 'Fecha de Inicio',
                          hintText: 'Ej: 26/08/2026',
                          lastDate: DateTime(2100),
                        ),
                        const SizedBox(height: 12),
                        _buildStepperControlInt('Duración', duracionDias, 1, 90, (val) => duracionDias = val, setStateDialog),
                        const SizedBox(height: 12),
                        TextField(
                          controller: dosisTratamientoController,
                          decoration: const InputDecoration(labelText: 'Dosis (Ej: 10 ml cada 24 horas)'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: viaTratamientoSeleccionado,
                          decoration: const InputDecoration(labelText: 'Vía de Administración'),
                          items: ['Intramuscular', 'Oral', 'Intravenosa']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) => setStateDialog(() => viaTratamientoSeleccionado = val!),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: veterinarioController,
                          decoration: const InputDecoration(labelText: 'Veterinario Responsable'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: observacionesController,
                          decoration: const InputDecoration(labelText: 'Notas / Observaciones'),
                          maxLines: 3,
                        ),
                      ],

                      const Divider(height: 30),

                      // ==================== SECCIÓN ANIMALES SELECCIONADOS ====================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Seleccionar Animales *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            onPressed: _abrirBuscadorAnimales,
                            icon: const Icon(Icons.search, color: AppTheme.primaryGreen, size: 28),
                            tooltip: 'Buscar animales',
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
                              child: const Text(
                                'Aún no se seleccionaron animales.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
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
                                      child: !esArchivoLocal
                                          ? Icon(
                                              animal['sexo'] == 'Hembra' ? Icons.female : Icons.male,
                                              color: AppTheme.primaryGreen,
                                            )
                                          : null,
                                    ),
                                    title: Text('Arete: ${animal['arete']} ${animal['nombre'] != null ? '(${animal['nombre']})' : ''}'),
                                    subtitle: Text('Categoría: ${animal['categoria']}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        setStateDialog(() {
                                          animalesSeleccionados.removeAt(index);
                                        });
                                      },
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
                    if (animalesSeleccionados.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Debe seleccionar al menos un animal.')),
                      );
                      return;
                    }

                    String productoVal = productoController.text.trim();
                    if (tipoSeleccionado == 'tratamiento') {
                      productoVal = medicamentoController.text.trim();
                    }

                    if (productoVal.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor complete el campo de Producto / Medicamento.')),
                      );
                      return;
                    }

                    String fechaISO = _convertirFechaAISO(fechaController.text.trim());

                    for (var animal in animalesSeleccionados) {
                      String tipoCategoria = tipoSeleccionado; 
                      String tipoEspecifico = '';
                      if (tipoSeleccionado == 'vacunacion') tipoEspecifico = tipoVacunaController.text.trim();
                      if (tipoSeleccionado == 'fumigacion') tipoEspecifico = tipoFumigacionSeleccionado;
                      if (tipoSeleccionado == 'desparasitacion') tipoEspecifico = tipoDesparasitanteSeleccionado;
                      if (tipoSeleccionado == 'tratamiento') tipoEspecifico = tipoTratamientoSeleccionado;

                      String dosisStr = '';
                      if (tipoSeleccionado == 'vacunacion') dosisStr = '${dosisVacuna.toStringAsFixed(0)} ml';
                      if (tipoSeleccionado == 'desparasitacion') dosisStr = '${dosisDesparasitacion.toStringAsFixed(0)} ml';
                      if (tipoSeleccionado == 'tratamiento') dosisStr = dosisTratamientoController.text.trim();

                      String viaStr = '';
                      if (tipoSeleccionado == 'vacunacion') viaStr = viaVacunaController.text.trim();
                      if (tipoSeleccionado == 'desparasitacion') viaStr = viaDesparasitacionSeleccionado;
                      if (tipoSeleccionado == 'tratamiento') viaStr = viaTratamientoSeleccionado;

                      await _dbHelper.insertSanidad({
                        'ganado_id': animal['id'],
                        'arete_asociado': animal['arete'],
                        'categoria_sanitaria': tipoCategoria,
                        'tipo_especifico': tipoEspecifico,
                        'producto': productoVal,
                        'fecha': fechaISO,
                        'dosis': dosisStr.isEmpty ? null : dosisStr,
                        'via_aplicacion': viaStr.isEmpty ? null : viaStr,
                        'lote': loteController.text.trim().isEmpty ? null : loteController.text.trim(),
                        'veterinario': veterinarioController.text.trim().isEmpty ? null : veterinarioController.text.trim(),
                        'diagnostico': tipoSeleccionado == 'tratamiento' ? diagnosticoController.text.trim() : null,
                        'duracion_dias': tipoSeleccionado == 'tratamiento' ? duracionDias : null,
                        'observaciones': observacionesController.text.trim().isEmpty ? null : observacionesController.text.trim(),
                      });
                    }

                    if (!mounted) return;
                    Navigator.pop(context);
                    _cargarSanidad();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Registro sanitario guardado exitosamente.')),
                    );
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

  Widget _buildStepperControl(String label, double valorActual, double min, double max, Function(double) onChanged, StateSetter setStateDialog) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, color: Colors.black87)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryGreen),
              onPressed: () {
                if (valorActual > min) {
                  setStateDialog(() => onChanged(valorActual - 1));
                }
              },
            ),
            Text('${valorActual.toStringAsFixed(0)} ml', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGreen),
              onPressed: () {
                if (valorActual < max) {
                  setStateDialog(() => onChanged(valorActual + 1));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepperControlInt(String label, int valorActual, int min, int max, Function(int) onChanged, StateSetter setStateDialog) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, color: Colors.black87)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryGreen),
              onPressed: () {
                if (valorActual > min) {
                  setStateDialog(() => onChanged(valorActual - 1));
                }
              },
            ),
            Text('$valorActual días', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGreen),
              onPressed: () {
                if (valorActual < max) {
                  setStateDialog(() => onChanged(valorActual + 1));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  String _obtenerNombreFiltroCorto(String filtro) {
    switch (filtro) {
      case 'vacunacion': return 'Vacunación';
      case 'fumigacion': return 'Fumigación';
      case 'desparasitacion': return 'Desparasitación';
      case 'tratamiento': return 'Tratamiento';
      default: return 'Todos';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textoBusqueda = _searchController.text.trim().toLowerCase();
    final listaFiltrada = _listaSanidad.where((item) {
      final categoriaSanitaria = (item['categoria_sanitaria'] ?? '').toString().toLowerCase();
      final tipoEspecifico = (item['tipo_especifico'] ?? '').toString().toLowerCase();
      
      bool coincideFiltro = true;
      if (_filtroActivo == 'vacunacion') {
        coincideFiltro = categoriaSanitaria.contains('vacunacion');
      } else if (_filtroActivo == 'fumigacion') {
        coincideFiltro = categoriaSanitaria.contains('fumigacion');
      } else if (_filtroActivo == 'desparasitacion') {
        coincideFiltro = categoriaSanitaria.contains('desparasitacion');
      } else if (_filtroActivo == 'tratamiento') {
        coincideFiltro = categoriaSanitaria.contains('tratamiento');
      }

      final textoCompleto = '${item['arete_asociado']} $categoriaSanitaria $tipoEspecifico ${item['producto']} ${item['observaciones']}'.toLowerCase();
      final coincideTexto = textoCompleto.contains(textoBusqueda);

      return coincideFiltro && coincideTexto;
    }).toList();

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
                    : listaFiltrada.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay registros sanitarios.\nPresiona el botón "+" para agregar uno.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: listaFiltrada.length,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemBuilder: (context, index) {
                              final item = listaFiltrada[index];
                              final String? fotoPath = item['animal_foto'];
                              final String? sexoAnimal = item['animal_sexo'];
                              bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();
                              
                              final String fechaVisual = ConfiguracionScreen.formatearFechaVisual(item['fecha']);

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
                                    backgroundImage: esArchivoLocal ? FileImage(File(fotoPath)) : null,
                                    child: !esArchivoLocal
                                        ? Icon(
                                            sexoAnimal == 'Hembra' ? Icons.female : Icons.male,
                                            color: AppTheme.primaryGreen,
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    'Arete: ${item['arete_asociado']} - ${item['tipo_especifico'] ?? item['categoria_sanitaria']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Producto: ${item['producto']}', style: const TextStyle(color: Color(0xFF6C8795), fontSize: 14)),
                                      const SizedBox(height: 3),
                                      Text('Fecha: $fechaVisual', style: const TextStyle(color: Color(0xFF6C8795), fontSize: 13)),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5F4E8),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Completado',
                                      style: TextStyle(color: Color(0xFF2D8235), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  onTap: () => _mostrarDetalleSanidad(item),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),

          Positioned(
            top: 8,
            right: 16,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.primaryGreen, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
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
                onSelected: (value) {
                  setState(() {
                    _filtroActivo = value;
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'todas', child: Text('Todos')),
                  const PopupMenuItem(value: 'vacunacion', child: Text('Vacunación')),
                  const PopupMenuItem(value: 'fumigacion', child: Text('Fumigación')),
                  const PopupMenuItem(value: 'desparasitacion', child: Text('Desparasitación')),
                  const PopupMenuItem(value: 'tratamiento', child: Text('Tratamiento')),
                ],
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
                  _buildFabOption('Vacunación', Icons.healing, () => _mostrarModalRegistrarSanidad(tipoInicial: 'Vacunacion')),
                  const SizedBox(height: 12),
                  _buildFabOption('Fumigación/Baño', Icons.bug_report, () => _mostrarModalRegistrarSanidad(tipoInicial: 'Fumigacion')),
                  const SizedBox(height: 12),
                  _buildFabOption('Desparasitación', Icons.medication, () => _mostrarModalRegistrarSanidad(tipoInicial: 'Desparasitacion')),
                  const SizedBox(height: 12),
                  _buildFabOption('Tratamiento', Icons.medical_services, () => _mostrarModalRegistrarSanidad(tipoInicial: 'Tratamiento')),
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

  void _mostrarDetalleSanidad(Map<String, dynamic> item) {
    final String fechaVisual = ConfiguracionScreen.formatearFechaVisual(item['fecha']);

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
                    'Ficha Sanitaria',
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
              Text('Arete del Animal: ${item['arete_asociado']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Tratamiento: ${item['tipo_especifico'] ?? item['categoria_sanitaria']}'),
              const SizedBox(height: 6),
              Text('Producto: ${item['producto']}'),
              const SizedBox(height: 6),
              Text('Fecha: $fechaVisual'),
              const SizedBox(height: 12),
              const Text('Observaciones:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(item['observaciones']?.isEmpty == true ? 'Sin observaciones registradas.' : item['observaciones']),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
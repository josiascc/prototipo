import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

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

  // Consultar historial de sanidad con datos del ganado asociado
  Future<void> _cargarSanidad() async {
    setState(() => _isLoading = true);
    
    final db = await _dbHelper.database;
    // Realizamos un LEFT JOIN para obtener también el sexo y la foto del animal si existe en la tabla ganado
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
    setState(() => _menuFabAbierto = false); // Cierra el menú flotante si estaba abierto
    List<Map<String, dynamic>> animalesActivos = await _dbHelper.queryAllGanadoActivo();

    if (animalesActivos.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero debes registrar al menos un animal en el módulo Ganado.')),
      );
      return;
    }

    // Estado local del modal
    String tipoSeleccionado = tipoInicial.toLowerCase(); // 'vacunacion', 'fumigacion', 'desparasitacion', 'tratamiento'
    
    // Controladores comunes y específicos
    final fechaController = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            // Función auxiliar para abrir el buscador y seleccionar animales (más ancho y alto)
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
                                height: 400, // Altura aumentada para mayor comodidad
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
                                              setStateDialog(() {}); // Refresca el modal principal
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
              title: const Text('Registrar Tratamiento Sanitario'),
              // Ventana del formulario con mayor ancho (95% de la pantalla)
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de Tipo de Registro
                      DropdownButtonFormField<String>(
                        value: tipoSeleccionado,
                        decoration: const InputDecoration(labelText: 'Categoría de Registro'),
                        items: const [
                          DropdownMenuItem(value: 'vacunacion', child: Text('Vacunación')),
                          DropdownMenuItem(value: 'fumigacion', child: Text('Fumigación / Baño')),
                          DropdownMenuItem(value: 'desparasitacion', child: Text('Desparasitación')),
                          DropdownMenuItem(value: 'tratamiento', child: Text('Tratamiento Clínico')),
                        ],
                        onChanged: (val) {
                          setStateDialog(() {
                            tipoSeleccionado = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

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
                        _buildCampoFecha(context, fechaController, 'Fecha de Aplicación', setStateDialog),
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
                        _buildCampoFecha(context, fechaController, 'Fecha de Aplicación', setStateDialog),
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
                        _buildCampoFecha(context, fechaController, 'Fecha de Aplicación', setStateDialog),
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
                        _buildCampoFecha(context, fechaController, 'Fecha de Inicio', setStateDialog),
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
              // Botones de cancelar y guardar ubicados juntos en la parte inferior
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

                    for (var animal in animalesSeleccionados) {
                      String tipoDesc = '';
                      if (tipoSeleccionado == 'vacunacion') tipoDesc = 'Vacuna: ${tipoVacunaController.text}';
                      if (tipoSeleccionado == 'fumigacion') tipoDesc = 'Fumigación: $tipoFumigacionSeleccionado';
                      if (tipoSeleccionado == 'desparasitacion') tipoDesc = 'Desparasitación: $tipoDesparasitanteSeleccionado';
                      if (tipoSeleccionado == 'tratamiento') tipoDesc = 'Tratamiento: $tipoTratamientoSeleccionado (${diagnosticoController.text})';

                      await _dbHelper.insertSanidad({
                        'ganado_id': animal['id'],
                        'arete_asociado': animal['arete'],
                        'tipo_tratamiento': tipoDesc,
                        'producto': productoVal,
                        'fecha': fechaController.text,
                        'observaciones': observacionesController.text.trim().isEmpty 
                            ? 'Vet: ${veterinarioController.text} | Lote: ${loteController.text}' 
                            : '${observacionesController.text.trim()} | Vet: ${veterinarioController.text}',
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

  // Métodos auxiliares para los campos de fecha y steppers numéricos
  Widget _buildCampoFecha(BuildContext context, TextEditingController controller, String label, StateSetter setStateDialog) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today, size: 20),
      ),
      readOnly: true,
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (pickedDate != null) {
          setStateDialog(() {
            controller.text = pickedDate.toIso8601String().split('T')[0];
          });
        }
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
      default: return 'Todas';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textoBusqueda = _searchController.text.trim().toLowerCase();
    final listaFiltrada = _listaSanidad.where((item) {
      final tipoTratamiento = (item['tipo_tratamiento'] ?? '').toString().toLowerCase();
      
      bool coincideFiltro = true;
      if (_filtroActivo == 'vacunacion') {
        coincideFiltro = tipoTratamiento.contains('vacuna');
      } else if (_filtroActivo == 'fumigacion') {
        coincideFiltro = tipoTratamiento.contains('fumigación') || tipoTratamiento.contains('baño');
      } else if (_filtroActivo == 'desparasitacion') {
        coincideFiltro = tipoTratamiento.contains('desparasitación');
      } else if (_filtroActivo == 'tratamiento') {
        coincideFiltro = tipoTratamiento.contains('tratamiento') || tipoTratamiento.contains('antibiótico');
      }

      final textoCompleto = '${item['arete_asociado']} ${item['tipo_tratamiento']} ${item['producto']} ${item['observaciones']}'.toLowerCase();
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
                                    'Arete: ${item['arete_asociado']} - ${item['tipo_tratamiento']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Producto: ${item['producto']}', style: const TextStyle(color: Color(0xFF6C8795), fontSize: 14)),
                                      const SizedBox(height: 3),
                                      Text('Fecha: ${item['fecha']}', style: const TextStyle(color: Color(0xFF6C8795), fontSize: 13)),
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

          // Botón flotante pequeño de filtros en la esquina superior derecha
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
                  const PopupMenuItem(value: 'todas', child: Text('Todas')),
                  const PopupMenuItem(value: 'vacunacion', child: Text('Vacunaciones')),
                  const PopupMenuItem(value: 'fumigacion', child: Text('Fumigaciones')),
                  const PopupMenuItem(value: 'desparasitacion', child: Text('Desparasitaciones')),
                  const PopupMenuItem(value: 'tratamiento', child: Text('Tratamientos')),
                ],
              ),
            ),
          ),
          
          // Overlay oscuro cuando el menú del FAB está abierto
          if (_menuFabAbierto)
            GestureDetector(
              onTap: () => setState(() => _menuFabAbierto = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),

          // Menú Desplegable del FAB flotante
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
              Text('Tratamiento: ${item['tipo_tratamiento']}'),
              const SizedBox(height: 6),
              Text('Producto: ${item['producto']}'),
              const SizedBox(height: 6),
              Text('Fecha: ${item['fecha']}'),
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
import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

class AnimalSelectorDropdown extends StatefulWidget {
  final String label;
  final String? filtroSexo; // 'Hembra' o 'Macho'
  final int? initialId;
  final String? initialArete;
  final Function(int? id, String? arete) onChanged;

  const AnimalSelectorDropdown({
    Key? key,
    required this.label,
    this.filtroSexo,
    this.initialId,
    this.initialArete,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<AnimalSelectorDropdown> createState() => _AnimalSelectorDropdownState();
}

class _AnimalSelectorDropdownState extends State<AnimalSelectorDropdown> {
  late TextEditingController _controller;
  int? _selectedId;
  Map<String, dynamic>? _selectedAnimal;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialId;
    _controller = TextEditingController(text: widget.initialArete ?? '');
    _cargarAnimalInicial();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

    Future<void> _cargarAnimalInicial() async {
    final dbHelper = DatabaseHelper();
    List<Map<String, dynamic>> animales = await dbHelper.queryAllGanadoActivo();

    Map<String, dynamic>? encontrado;
    if (_selectedId != null) {
      try {
        encontrado = animales.firstWhere((a) => a['id'] == _selectedId);
      } catch (_) {}
    } else if (widget.initialArete != null && widget.initialArete!.isNotEmpty) {
      try {
        encontrado = animales.firstWhere(
          (a) => a['arete'].toString().toLowerCase() == widget.initialArete!.toLowerCase(),
        );
        // CORRECCIÓN: Quitamos el 'if (encontrado != null)' redundante
        _selectedId = encontrado['id'];
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _selectedAnimal = encontrado;
        if (encontrado != null) {
          _controller.text = encontrado['arete'] ?? '';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _mostrarBuscadorAnimales(BuildContext context) async {
    final dbHelper = DatabaseHelper();
    List<Map<String, dynamic>> animales = await dbHelper.queryAllGanadoActivo();

    if (widget.filtroSexo != null) {
      animales = animales.where((a) => a['sexo'] == widget.filtroSexo).toList();
    }

    if (!context.mounted) return;

    String queryBusqueda = '';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final animalesFiltrados = animales.where((a) {
              final arete = (a['arete'] ?? '').toString().toLowerCase();
              final nombre = (a['nombre'] ?? '').toString().toLowerCase();
              final q = queryBusqueda.toLowerCase();
              return arete.contains(q) || nombre.contains(q);
            }).toList();

            return AlertDialog(
              title: Text('Seleccionar ${widget.label}'),
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
                        setStateDialog(() {
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
                                final sexoAnimal = animal['sexo'] ?? '';
                                final raza = animal['raza'] ?? '';
                                final fotoPath = animal['foto'];
                                bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();

                                return ListTile(
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
                                  title: Text('Arete: $arete ${nombre != null && nombre.isNotEmpty ? '($nombre)' : ''}'),
                                  subtitle: Text('Categoría: $categoria | Sexo: $sexoAnimal${raza.isNotEmpty ? ' | Raza: $raza' : ''}'),
                                  onTap: () {
                                    setState(() {
                                      _selectedId = animal['id'];
                                      _selectedAnimal = animal;
                                      _controller.text = arete;
                                    });
                                    widget.onChanged(_selectedId, arete);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 50,
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    // Si hay un animal registrado seleccionado, el texto desaparece y se muestra el panel
    if (_selectedAnimal != null) {
      final animal = _selectedAnimal!;
      final arete = animal['arete'] ?? '';
      final nombre = animal['nombre'];
      final categoria = animal['categoria'] ?? '';
      final sexoAnimal = animal['sexo'] ?? '';
      final raza = animal['raza'] ?? '';
      final fotoPath = animal['foto'];
      bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
              backgroundImage: esArchivoLocal ? FileImage(File(fotoPath)) : null,
              child: !esArchivoLocal
                  ? Icon(
                      sexoAnimal == 'Hembra' ? Icons.female : Icons.male,
                      color: AppTheme.primaryGreen,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.label}: Arete $arete${nombre != null && nombre.isNotEmpty ? ' ($nombre)' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cat: $categoria | Sexo: $sexoAnimal${raza.isNotEmpty ? ' | Raza: $raza' : ''}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.primaryGreen, size: 20),
              tooltip: 'Cambiar',
              onPressed: () => _mostrarBuscadorAnimales(context),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 20),
              tooltip: 'Quitar',
              onPressed: () {
                setState(() {
                  _selectedId = null;
                  _selectedAnimal = null;
                  _controller.clear();
                });
                widget.onChanged(null, null);
              },
            ),
          ],
        ),
      );
    } else {
      // Si no hay animal seleccionado del registro, se muestra el campo de texto libre para ganado externo
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: 'Escribir arete externo o buscar',
              ),
              onChanged: (val) {
                _selectedId = null;
                _selectedAnimal = null;
                widget.onChanged(_selectedId, val.trim().isEmpty ? null : val.trim());
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _mostrarBuscadorAnimales(context),
            icon: const Icon(Icons.search, color: AppTheme.primaryGreen),
            tooltip: 'Buscar en registro',
          ),
        ],
      );
    }
  }
}
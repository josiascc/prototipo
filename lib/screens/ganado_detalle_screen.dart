import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import 'configuracion_screen.dart'; // <--- 1. Importa configuracion_screen.dart

class GanadoDetalleScreen extends StatelessWidget {
  final Map<String, dynamic> animal;

  const GanadoDetalleScreen({Key? key, required this.animal}) : super(key: key);

  void _confirmarEliminacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Animal'),
        content: Text('¿Estás seguro de eliminar el registro del arete ${animal['arete']}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final dbHelper = DatabaseHelper();
              await dbHelper.deleteGanado(animal['id']);
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? fotoPath = animal['foto'];
    final bool esArchivoLocal = fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();
    final String? nombre = animal['nombre'];
    final String arete = animal['arete'] ?? 'Sin arete';
    final String categoria = animal['categoria'] ?? 'No especificada';
    final String raza = animal['raza'] ?? 'No especificada';
    final String sexo = animal['sexo'] ?? 'No especificado';
    
    // 2. Aplica formatearFechaVisual para asegurar formato dd/mm/aaaa
    final String fechaNacimiento = ConfiguracionScreen.formatearFechaVisual(animal['fecha_nacimiento']);
    final String fechaIngreso = ConfiguracionScreen.formatearFechaVisual(animal['fecha_ingreso']);
    
    final String estado = animal['estado'] ?? 'Activo';
    final String? madreArete = animal['madre_arete'];
    final String? padreArete = animal['padre_arete'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle: Arete $arete'),
        actions: [
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
    );
  }
}
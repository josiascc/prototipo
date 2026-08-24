import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  // ==================== MÉTODOS REUTILIZABLES ====================
  
  // Obtiene el símbolo de moneda listo para usar (ej. 'Bs ' o 'USD ')
  static Future<String> obtenerSimboloMoneda() async {
    final prefs = await SharedPreferences.getInstance();
    String monedaConfig = prefs.getString('moneda_finca') ?? 'Bolivianos (Bs)';
    return monedaConfig.contains('USD') ? 'USD ' : 'Bs ';
  }

  // Obtiene el nombre de la finca configurado
  static Future<String> obtenerNombreFinca() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('nombre_finca') ?? 'GanaderoPro - Finca Principal';
  }

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  bool _isLoading = false;
  String _monedaSeleccionada = 'Bolivianos (Bs)';

  @override
  void initState() {
    super.initState();
    _cargarMoneda();
  }

  // Leer la moneda guardada
  Future<void> _cargarMoneda() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monedaSeleccionada = prefs.getString('moneda_finca') ?? 'Bolivianos (Bs)';
    });
  }

  // Guardar la moneda seleccionada
  Future<void> _guardarMoneda(String nuevaMoneda) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moneda_finca', nuevaMoneda);
    setState(() {
      _monedaSeleccionada = nuevaMoneda;
    });
  }

  // ==================== 1. EXPORTAR RESPALDO (.ZIP) ====================
  Future<void> _exportarRespaldo() async {
    setState(() => _isLoading = true);
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final fechaActual = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final zipFilePath = '${tempDir.path}/respaldo_ganaderopro_$fechaActual.zip';

      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);
      encoder.addDirectory(documentsDirectory);
      encoder.close();

      setState(() => _isLoading = false);

      await Share.shareXFiles(
        [XFile(zipFilePath)],
        text: 'Respaldo completo de GanaderoPro (Base de datos y fotos de la finca)',
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar respaldo: $e')),
      );
    }
  }

  // ==================== 2. IMPORTAR / RESTAURAR RESPALDO (.ZIP) ====================
  Future<void> _importarRespaldo() async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar Respaldo'),
        content: const Text(
          'Atención: Restaurar un respaldo sobrescribirá toda la información actual y las fotos de la aplicación. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, restaurar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _isLoading = false);
        return;
      }

      File zipFile = File(result.files.single.path!);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      Directory documentsDirectory = await getApplicationDocumentsDirectory();

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File("${documentsDirectory.path}/$filename")
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory("${documentsDirectory.path}/$filename").createSync(recursive: true);
        }
      }

      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Respaldo restaurado con éxito! Reinicia la app si es necesario.')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al restaurar respaldo: $e')),
      );
    }
  }

  void _mostrarDialogoRespaldo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gestión de Respaldos'),
          content: const Text(
            'Puedes exportar un archivo comprimido (.zip) con todos tus datos y fotos para guardarlo en la nube o pasarlo a otro dispositivo, o bien restaurar un respaldo anterior.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
              onPressed: () {
                Navigator.pop(context);
                _importarRespaldo();
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Restaurar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _exportarRespaldo();
              },
              icon: const Icon(Icons.download),
              label: const Text('Exportar .zip'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  'Ajustes Generales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.store, color: AppTheme.primaryGreen),
                        title: const Text('Nombre de la Finca'),
                        subtitle: const Text('GanaderoPro - Finca Principal'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Configuración predeterminada activa.')),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.attach_money, color: AppTheme.primaryGreen),
                        title: const Text('Moneda Local'),
                        subtitle: Text(_monedaSeleccionada),
                        trailing: DropdownButton<String>(
                          value: _monedaSeleccionada,
                          underline: const SizedBox(),
                          items: <String>['Bolivianos (Bs)', 'Dólares (USD)']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              _guardarMoneda(newValue);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Datos y Seguridad',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.folder_zip, color: Colors.blue),
                        title: const Text('Respaldo y Fotos (.zip)'),
                        subtitle: const Text('Exportar o restaurar base de datos y fotos'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _mostrarDialogoRespaldo,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Información',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GanaderoPro v1.0.0',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Aplicación móvil diseñada para la gestión integral de ganado, sanidad, reproducción, producción lechera, finanzas e inventario de la finca.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
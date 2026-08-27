import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 1. Base de datos guardada directamente en el directorio principal de documentos
  Future<Database> _initDatabase() async {
    final appDir = await getApplicationDocumentsDirectory();
    String path = join(appDir.path, 'prototipoganado.db');
    return await openDatabase(
      path,
      version: 2, // <--- cambiamos y agregamos nuevo campos en tablas
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // <--- Activamos el manejador de migraciones
    );
  }

  // 2. Método estático auxiliar para asegurar y retornar la ruta de la carpeta 'fotos'
  static Future<String> getFotosDirectoryPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final fotosDir = Directory(join(appDir.path, 'fotos'));
    if (!await fotosDir.exists()) {
      await fotosDir.create(recursive: true);
    }
    return fotosDir.path;
  }

  // ===========================================================================
  // ZONA DE CICLO DE VIDA (CREACIÓN Y MIGRACIONES)
  // ===========================================================================

  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabla GANADO
    await db.execute('''
      CREATE TABLE ganado (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        arete TEXT,
        nombre TEXT,
        categoria TEXT, 
        raza TEXT,
        sexo TEXT, 
        fecha_ingreso TEXT,
        fecha_nacimiento TEXT,
        estado TEXT DEFAULT 'Activo', 
        madre_id INTEGER,
        padre_id INTEGER,
        madre_arete TEXT,
        padre_arete TEXT,
        foto TEXT,
        FOREIGN KEY (madre_id) REFERENCES ganado (id) ON DELETE SET NULL,
        FOREIGN KEY (padre_id) REFERENCES ganado (id) ON DELETE SET NULL
      )
    ''');

    // 2. Tabla SANIDAD
    await db.execute('''
      CREATE TABLE sanidad (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ganado_id INTEGER, 
        arete_asociado TEXT,
        categoria_sanitaria TEXT,  
        tipo_especifico TEXT,      
        producto TEXT,
        fecha TEXT,
        dosis TEXT,                
        via_aplicacion TEXT,       
        lote TEXT,
        veterinario TEXT,
        diagnostico TEXT,          
        duracion_dias INTEGER,     
        observaciones TEXT,
        FOREIGN KEY (ganado_id) REFERENCES ganado (id) ON DELETE CASCADE
      )
    ''');

    // 3. Tabla REPRODUCCIÓN
    await db.execute('''
      CREATE TABLE reproduccion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ganado_id INTEGER, 
        arete_asociado TEXT,
        tipo_evento TEXT, 
        diagnostico TEXT, 
        fecha TEXT,
        fecha_servicio TEXT, -- <--- NUEVA COLUMNA PARA GUARDAR LA FECHA DE CRUCE/INSEMINACIÓN
        notas TEXT,
        FOREIGN KEY (ganado_id) REFERENCES ganado (id) ON DELETE CASCADE
      )
    ''');

    // 4. Tabla PRODUCCIÓN
    await db.execute('''
      CREATE TABLE produccion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ganado_id INTEGER, 
        arete_asociado TEXT, 
        turno TEXT, 
        litros REAL,
        fecha TEXT,
        entregado INTEGER DEFAULT 1, 
        notas TEXT,
        FOREIGN KEY (ganado_id) REFERENCES ganado (id) ON DELETE CASCADE
      )
    ''');

    // 5. Tabla INVENTARIO / BODEGA
    await db.execute('''
      CREATE TABLE inventario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_producto TEXT,
        categoria TEXT, 
        stock_actual REAL,
        unidad_medida TEXT, 
        fecha_registro TEXT,
        fecha_vencimiento TEXT,
        monto REAL 
      )
    ''');

    // 6. Tabla FINANZAS
    await db.execute('''
      CREATE TABLE finanzas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT, 
        categoria TEXT,
        monto REAL,
        fecha TEXT,
        descripcion TEXT
      )
    ''');

    // 7. Tabla ACTIVIDADES
    await db.execute('''
      CREATE TABLE actividades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ganado_id INTEGER, -- <--- NUEVA COLUMNA
        titulo TEXT,
        tipo_lote TEXT,
        fecha_programada TEXT,
        completada INTEGER DEFAULT 0,
        FOREIGN KEY (ganado_id) REFERENCES ganado (id) ON DELETE CASCADE
      )
    ''');
  }

  /* 
   * ===========================================================================
   * MOTOR DE MIGRACIÓN REUTILIZABLE (COMENTADO PARA EL FUTURO)
   * ===========================================================================
   * 
   * ¿Cómo funciona este sistema reutilizable?
   * 1. Defines tus cambios por cada versión numérica en este mapa.
   * 2. El método _onUpgrade recorre de forma inteligente desde la versión vieja 
   *    del usuario hasta la nueva, aplicando los cambios paso a paso de forma limpia.
   */

  // Mapa de migraciones ordenado por versión objetivo
  final Map<int, Future<void> Function(Database db)> _migrations = {
    2: (db) async {
      // Agregamos la columna ganado_id a la tabla actividades existente
      await db.execute("ALTER TABLE actividades ADD COLUMN ganado_id INTEGER;");
    },
    /*
    3: (db) async {
      // Ejemplo Versión 3: Crear una tabla completamente nueva
      await db.execute('''
        CREATE TABLE potreros (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre_potrero TEXT,
          capacidad_maxima INTEGER
        )
      ''');
    },
    4: (db) async {
      // Ejemplo Versión 4: Agregar campo a otra tabla existente
      await db.execute("ALTER TABLE sanidad ADD COLUMN costo REAL;");
    },
    5: (db) async {
      // Ejemplo Versión 5: Modificar/añadir restricciones o lo que necesites
      await db.execute("ALTER TABLE finanzas ADD COLUMN comprobante TEXT;");
    },
    */
  };

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      if (_migrations.containsKey(version)) {
        try {
          await _migrations[version]!(db);
        } catch (e) {
          print("Error aplicando la migración para la versión $version: $e");
        }
      }
    }
  }

  // ===========================================================================
  // MÉTODOS DE NEGOCIO (CRUD Y CONSULTAS)
  // ===========================================================================

  Future<int> insertGanado(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('ganado', row);
  }

  Future<List<Map<String, dynamic>>> queryAllGanadoActivo() async {
    Database db = await database;
    return await db.query('ganado', where: "estado = 'Activo'", orderBy: 'id DESC');
  }

  Future<int> getCountGanadoActivo() async {
    Database db = await database;
    var result = await db.rawQuery("SELECT COUNT(*) as count FROM ganado WHERE estado = 'Activo'");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getConteoPorCategoria() async {
    Database db = await database;
    return await db.rawQuery(
      "SELECT categoria, COUNT(*) as total FROM ganado WHERE estado = 'Activo' GROUP BY categoria"
    );
  }

  // ==================== SANIDAD E INVENTARIO ====================
  Future<int> insertSanidad(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('sanidad', row);
  }

  Future<int> insertInventario(Map<String, dynamic> row) async {
    Database db = await database;
    int id = await db.insert('inventario', row);

    if (row['monto'] != null && (row['monto'] as num) > 0) {
      await insertFinanza({
        'tipo': 'Gasto',
        'categoria': 'Insumos / Bodega (${row['categoria'] ?? 'General'})',
        'monto': row['monto'],
        'fecha': DateTime.now().toIso8601String().split('T')[0],
        'descripcion': 'Compra de ${row['nombre_producto']} (${row['stock_actual']} ${row['unidad_medida'] ?? ''})',
      });
    }

    return id;
  }

  Future<List<Map<String, dynamic>>> getProductosStockBajo(double limiteMinimo) async {
    Database db = await database;
    return await db.query(
      'inventario',
      where: 'stock_actual <= ?',
      whereArgs: [limiteMinimo],
      orderBy: 'stock_actual ASC',
    );
  }

  // ==================== REPRODUCCIÓN ====================
  Future<int> insertReproduccion(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('reproduccion', row);
  }

  Future<List<Map<String, dynamic>>> queryAllReproduccionConGanado() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT r.*, g.nombre as animal_nombre, g.raza as animal_raza, g.sexo as animal_sexo, g.foto as animal_foto, g.categoria as animal_categoria
      FROM reproduccion r
      LEFT JOIN ganado g ON r.ganado_id = g.id
      ORDER BY r.id DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getAlertasReproduccion() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT arete_asociado, tipo_evento, fecha 
      FROM reproduccion 
      WHERE id IN (
        SELECT MAX(id) FROM reproduccion GROUP BY arete_asociado
      ) AND (tipo_evento = 'Parto' OR tipo_evento = 'Aborto')
      ORDER BY fecha ASC
    ''');
  }

  Future<void> registrarPartoConCesionDeCrias({
    required Map<String, dynamic> eventoParto,
    required List<Map<String, dynamic>> listaCrias,
  }) async {
    Database db = await database;
    await db.transaction((txn) async {
      await txn.insert('reproduccion', eventoParto);

      for (var cria in listaCrias) {
        await txn.insert('ganado', {
          'arete': cria['arete'],
          'nombre': cria['nombre'] ?? 'Cría de ${eventoParto['arete_asociado']}',
          'categoria': 'Cría / Ternero(a)',
          'raza': cria['raza'] ?? 'No especificada',
          'sexo': cria['genero'],
          'fecha_ingreso': eventoParto['fecha'],
          'fecha_nacimiento': eventoParto['fecha'],
          'estado': 'Activo',
          'madre_id': eventoParto['ganado_id'],
          'madre_arete': eventoParto['arete_asociado'],
          'padre_arete': eventoParto['padre_arete'],
          'foto': cria['foto'],
        });
      }
    });
  }

  Future<Map<String, int>> getEstadisticasReproduccion() async {
    Database db = await database;
    
    var gestantesRes = await db.rawQuery('''
      SELECT COUNT(DISTINCT arete_asociado) as total 
      FROM reproduccion 
      WHERE (tipo_evento = 'Diagnóstico Preñez' AND diagnostico = 'Gestante')
         OR id IN (SELECT MAX(id) FROM reproduccion GROUP BY arete_asociado HAVING tipo_evento = 'Diagnóstico Preñez' AND diagnostico = 'Gestante')
    ''');
    
    int gestantes = Sqflite.firstIntValue(gestantesRes) ?? 0;
    
    var animalesActivos = await queryAllGanadoActivo();
    int totalHembras = animalesActivos.where((a) => (a['sexo'] ?? '').toString() == 'Hembra').length;
    int produccion = animalesActivos.where((a) => (a['categoria'] ?? '').toString().toLowerCase().contains('lechera')).length;
    int vacias = totalHembras - gestantes;

    return {
      'produccion': produccion,
      'gestantes': gestantes,
      'vacias': vacias < 0 ? 0 : vacias,
    };
  }

  // ==================== PRODUCCIÓN Y FINANZAS ====================
  Future<int> insertProduccion(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('produccion', row);
  }

  Future<double> getTotalLecheEntregadaMes(String anioMes) async {
    Database db = await database;
    var result = await db.rawQuery(
      "SELECT SUM(litros) as total FROM produccion WHERE fecha LIKE ? AND entregado = 1",
      ['$anioMes%']
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalLecheTotalMes(String anioMes) async {
    Database db = await database;
    var result = await db.rawQuery(
      "SELECT SUM(litros) as total FROM produccion WHERE fecha LIKE ?",
      ['$anioMes%']
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> insertFinanza(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('finanzas', row);
  }

  Future<Map<String, double>> getBalanceFinancieroMes(String anioMes) async {
    Database db = await database;
    var ingresosRes = await db.rawQuery(
      "SELECT SUM(monto) as total FROM finanzas WHERE tipo = 'Ingreso' AND fecha LIKE ?",
      ['$anioMes%']
    );
    var gastosRes = await db.rawQuery(
      "SELECT SUM(monto) as total FROM finanzas WHERE tipo = 'Gasto' AND fecha LIKE ?",
      ['$anioMes%']
    );

    double ingresos = (ingresosRes.first['total'] as num?)?.toDouble() ?? 0.0;
    double gastos = (gastosRes.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'ingresos': ingresos,
      'gastos': gastos,
      'balance': ingresos - gastos,
    };
  }

  // ==================== ACTIVIDADES ====================
  Future<List<Map<String, dynamic>>> queryActividadesPendientes() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT a.*, 
             g.arete as animal_arete, 
             g.nombre as animal_nombre, 
             g.foto as animal_foto, 
             g.raza as animal_raza,
             (SELECT r.tipo_evento FROM reproduccion r WHERE r.ganado_id = a.ganado_id ORDER BY r.id DESC LIMIT 1) as ultimo_tipo_evento
      FROM actividades a
      LEFT JOIN ganado g ON a.ganado_id = g.id
      WHERE a.completada = 0
      ORDER BY CASE WHEN a.tipo_lote LIKE '%Gestante%' THEN 0 ELSE 1 END, a.fecha_programada ASC
    ''');
  }

  Future<int> insertarActividad(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('actividades', row);
  }

  Future<int> completarActividad(int id) async {
    Database db = await database;
    return await db.update('actividades', {'completada': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGanado(int id) async {
    Database db = await database;
    return await db.delete('ganado', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateGanado(int id, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.update('ganado', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateSanidad(int id, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.update('sanidad', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateReproduccion(int id, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.update('reproduccion', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateProduccion(int id, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.update('produccion', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateInventario(int id, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.update('inventario', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateFinanza(int id, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.update('finanzas', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateActividad(int id, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.update('actividades', row, where: 'id = ?', whereArgs: [id]);
  }

  // ==================== CONSULTAS POR RANGO DE FECHAS ====================
  Future<double> getTotalLecheRango(String fechaInicioISO, String fechaFinISO) async {
    Database db = await database;
    var result = await db.rawQuery(
      "SELECT SUM(litros) as total FROM produccion WHERE fecha >= ? AND fecha <= ?",
      [fechaInicioISO, fechaFinISO]
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getBalanceFinancieroRango(String fechaInicioISO, String fechaFinISO) async {
    Database db = await database;
    var ingresosRes = await db.rawQuery(
      "SELECT SUM(monto) as total FROM finanzas WHERE tipo = 'Ingreso' AND fecha >= ? AND fecha <= ?",
      [fechaInicioISO, fechaFinISO]
    );
    var gastosRes = await db.rawQuery(
      "SELECT SUM(monto) as total FROM finanzas WHERE tipo = 'Gasto' AND fecha >= ? AND fecha <= ?",
      [fechaInicioISO, fechaFinISO]
    );

    double ingresos = (ingresosRes.first['total'] as num?)?.toDouble() ?? 0.0;
    double gastos = (gastosRes.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'ingresos': ingresos,
      'gastos': gastos,
      'balance': ingresos - gastos,
    };
  }

  // ==================== BALANCE GENERAL TOTAL (HISTÓRICO) ====================
  Future<Map<String, double>> getBalanceFinancieroTotal() async {
    Database db = await database;
    var ingresosRes = await db.rawQuery(
      "SELECT SUM(monto) as total FROM finanzas WHERE tipo = 'Ingreso'"
    );
    var gastosRes = await db.rawQuery(
      "SELECT SUM(monto) as total FROM finanzas WHERE tipo = 'Gasto'"
    );

    double ingresos = (ingresosRes.first['total'] as num?)?.toDouble() ?? 0.0;
    double gastos = (gastosRes.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'ingresos': ingresos,
      'gastos': gastos,
      'balance': ingresos - gastos,
    };
  }

  /// Consulta para obtener las vacas gestantes junto con los días que faltan para su posible parto.
  /// Calcula la Fecha Probable de Parto (FPP) sumando 283 días a la fecha de servicio (o fecha del evento)
  /// y calcula los días restantes contra la fecha actual.
  Future<List<Map<String, dynamic>>> getDiasFaltantesPartoGestantes() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT r.*, g.nombre as animal_nombre, g.raza as animal_raza, g.sexo as animal_sexo, g.foto as animal_foto, g.categoria as animal_categoria,
             COALESCE(r.fecha_servicio, r.fecha) as fecha_base,
             date(COALESCE(r.fecha_servicio, r.fecha), '+283 days') as fecha_probable_parto,
             CAST(julianday(date(COALESCE(r.fecha_servicio, r.fecha), '+283 days')) - julianday('now') AS INTEGER) as dias_faltantes
      FROM reproduccion r
      LEFT JOIN ganado g ON r.ganado_id = g.id
      WHERE (r.tipo_evento = 'Diagnóstico Preñez' AND r.diagnostico = 'Gestante')
         OR r.id IN (
           SELECT MAX(id) FROM reproduccion 
           GROUP BY arete_asociado 
           HAVING tipo_evento = 'Diagnóstico Preñez' AND diagnostico = 'Gestante'
         )
      ORDER BY dias_faltantes ASC
    ''');
  }
}
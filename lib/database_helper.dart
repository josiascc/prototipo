import 'dart:async';
import 'package:path/path.dart';
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

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'prototipoganado.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla Ganado
    await db.execute('''
      CREATE TABLE ganado (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        arete TEXT UNIQUE,
        categoria TEXT,
        raza TEXT,
        sexo TEXT,
        fecha_ingreso TEXT
      )
    ''');

    // Tabla Sanidad
    await db.execute('''
      CREATE TABLE sanidad (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        arete_asociado TEXT,
        tipo_tratamiento TEXT,
        producto TEXT,
        fecha TEXT,
        observaciones TEXT,
        FOREIGN KEY (arete_asociado) REFERENCES ganado (arete) ON DELETE CASCADE
      )
    ''');

    // Tabla Reproducción
    await db.execute('''
      CREATE TABLE reproduccion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        arete_asociado TEXT,
        tipo_evento TEXT,
        fecha TEXT,
        notas TEXT,
        FOREIGN KEY (arete_asociado) REFERENCES ganado (arete) ON DELETE CASCADE
      )
    ''');
  }

  // ==================== MÉTODOS PARA GANADO ====================
  Future<int> insertGanado(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('ganado', row);
  }

  Future<List<Map<String, dynamic>>> queryAllGanado() async {
    Database db = await database;
    return await db.query('ganado', orderBy: 'id DESC');
  }

  Future<int> updateGanado(Map<String, dynamic> row) async {
    Database db = await database;
    int id = row['id'];
    return await db.update('ganado', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGanado(int id) async {
    Database db = await database;
    return await db.delete('ganado', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== MÉTODOS PARA SANIDAD ====================
  Future<int> insertSanidad(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('sanidad', row);
  }

  Future<List<Map<String, dynamic>>> queryAllSanidad() async {
    Database db = await database;
    return await db.query('sanidad', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> querySanidadPorArete(String arete) async {
    Database db = await database;
    return await db.query('sanidad', where: 'arete_asociado = ?', whereArgs: [arete]);
  }

  Future<int> updateSanidad(Map<String, dynamic> row) async {
    Database db = await database;
    int id = row['id'];
    return await db.update('sanidad', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSanidad(int id) async {
    Database db = await database;
    return await db.delete('sanidad', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== MÉTODOS PARA REPRODUCCIÓN ====================
  Future<int> insertReproduccion(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('reproduccion', row);
  }

  Future<List<Map<String, dynamic>>> queryAllReproduccion() async {
    Database db = await database;
    return await db.query('reproduccion', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> queryReproduccionPorArete(String arete) async {
    Database db = await database;
    return await db.query('reproduccion', where: 'arete_asociado = ?', whereArgs: [arete]);
  }

  Future<int> updateReproduccion(Map<String, dynamic> row) async {
    Database db = await database;
    int id = row['id'];
    return await db.update('reproduccion', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteReproduccion(int id) async {
    Database db = await database;
    return await db.delete('reproduccion', where: 'id = ?', whereArgs: [id]);
  }
}

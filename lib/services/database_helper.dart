import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'aed_mobile.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table for cached AED data (subset of main DB)
    await db.execute('''
      CREATE TABLE aed_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        address TEXT,
        floor TEXT DEFAULT '1F',
        landmarks TEXT DEFAULT '[]',
        lat REAL,
        lng REAL,
        updated_at TEXT
      )
    ''');

    // Table for pending uploads (Offline Queue)
    await db.execute('''
      CREATE TABLE pending_uploads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT,
        lat REAL,
        lng REAL,
        heading REAL,
        created_at INTEGER,
        status TEXT DEFAULT 'pending' 
      )
    ''');
  }

  // --- CRUD for Pending Uploads ---

  Future<int> insertPendingUpload(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('pending_uploads', row);
  }

  Future<List<Map<String, dynamic>>> getPendingUploads() async {
    final db = await database;
    return await db.query(
      'pending_uploads',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
  }

  // --- Read AEDs ---
  
  Future<List<Map<String, dynamic>>> getAllAeds() async {
    final db = await database;
    return await db.query('aed_points');
  }

  // Debug Helper: Seed some dummy data if empty
  Future<void> seedDummyData() async {
    final db = await database;
    var count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM aed_points'));
    if (count == 0) {
       // Seed Taipei 101 area points
       await db.insert('aed_points', {
         'name': 'Taipei 101 Mall Service',
         'address': 'No. 45, Shifu Rd, Xinyi District, Taipei City',
         'floor': '1F',
         'landmarks': '["Service Desk", "Elevator"]',
         'lat': 25.033976,
         'lng': 121.564423,
       });
       await db.insert('aed_points', {
         'name': 'MRT Taipei 101 Station',
         'address': 'Xinyi Rd Sec 5',
         'floor': 'B1',
         'landmarks': '["Ticket Gate", "Information"]',
         'lat': 25.0332,
         'lng': 121.5637,
       });
       await db.insert('aed_points', {
         'name': 'Grand Hyatt Taipei',
         'address': 'No. 2, Songshou Rd',
         'floor': 'Lobby',
         'landmarks': '["Reception"]',
         'lat': 25.0355,
         'lng': 121.5620,
       });
    }
  }

  Future<int> markAsUploaded(int id) async {
    final db = await database;
    return await db.update(
      'pending_uploads',
      {'status': 'uploaded'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

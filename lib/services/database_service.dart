import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lead_model.dart';
import 'drive_backup_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('leads_crm.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'leads_crm.db');
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE leads (
        id TEXT PRIMARY KEY,
        business_name TEXT NOT NULL,
        category TEXT,
        phone TEXT,
        email TEXT,
        website TEXT,
        rating REAL,
        review_count INTEGER,
        address TEXT,
        latitude REAL,
        longitude REAL,
        keyword TEXT,
        location TEXT,
        lead_status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL,
        location TEXT NOT NULL,
        leads_generated INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> _triggerAutoSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('auto_sync_drive') == true) {
        // Fire and forget
        DriveBackupService().backupDatabaseToDrive(null, silent: true);
      }
    } catch (_) {}
  }

  Future<void> insertLead(Lead lead) async {
    final db = await instance.database;
    
    // Prevent duplicates by checking phone or name and address
    final existing = await db.query(
      'leads',
      where: 'phone = ? OR (business_name = ? AND address = ?)',
      whereArgs: [lead.phone, lead.businessName, lead.address],
    );

    if (existing.isEmpty) {
      await db.insert('leads', lead.toMap());
      _triggerAutoSync();
    }
  }

  Future<void> insertSearchHistory(String keyword, String location, int count) async {
    final db = await instance.database;
    await db.insert('search_history', {
      'keyword': keyword,
      'location': location,
      'leads_generated': count,
      'created_at': DateTime.now().toIso8601String(),
    });
    _triggerAutoSync();
  }

  Future<List<Lead>> getAllLeads() async {
    final db = await instance.database;
    final result = await db.query('leads', orderBy: 'created_at DESC');
    return result.map((json) => Lead.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getSearchHistory() async {
    final db = await instance.database;
    return await db.query('search_history', orderBy: 'created_at DESC');
  }

  Future<void> updateLeadStatus(String id, String status) async {
    final db = await instance.database;
    await db.update(
      'leads',
      {'lead_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
    _triggerAutoSync();
  }

  Future<void> updateLead(Lead lead) async {
    final db = await instance.database;
    await db.update(
      'leads',
      lead.toMap(),
      where: 'id = ?',
      whereArgs: [lead.id],
    );
    _triggerAutoSync();
  }

  Future<void> deleteLead(String id) async {
    final db = await instance.database;
    await db.delete(
      'leads',
      where: 'id = ?',
      whereArgs: [id],
    );
    _triggerAutoSync();
  }

  Future<void> clearMyData() async {
    final db = await instance.database;
    await db.delete('leads');
    await db.delete('search_history');
    _triggerAutoSync();
  }
}

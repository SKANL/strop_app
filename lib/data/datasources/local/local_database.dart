import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._init();
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('strop_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE incidents ADD COLUMN status TEXT DEFAULT "pending"',
      );
    }
    if (oldVersion < 3) {
      // Add columns for Online Schema alignment
      await db.execute('ALTER TABLE incidents ADD COLUMN project_id TEXT');
      await db.execute('ALTER TABLE incidents ADD COLUMN category TEXT');
      await db.execute('ALTER TABLE incidents ADD COLUMN location_tag TEXT');
      await db.execute('ALTER TABLE incidents ADD COLUMN gps_lat REAL');
      await db.execute('ALTER TABLE incidents ADD COLUMN gps_lng REAL');
      await db.execute('ALTER TABLE incidents ADD COLUMN created_by TEXT');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL';
    const autoIdType = 'INTEGER PRIMARY KEY AUTOINCREMENT';

    // Incidents Table
    await db.execute('''
CREATE TABLE incidents ( 
  id $idType, 
  title $textTypeNullable,
  description $textTypeNullable,
  priority $textType,
  status $textType,
  project_id $textTypeNullable,
  category $textTypeNullable,
  location_tag $textTypeNullable,
  audio_path $textTypeNullable,
  gps_lat $realType,
  gps_lng $realType,
  created_by $textTypeNullable,
  created_at $textType,
  sync_status $integerType
  )
''');

    // Photos Table
    await db.execute('''
CREATE TABLE photos ( 
  id $idType, 
  incident_id $textType,
  local_path $textType,
  annotations_json $textTypeNullable,
  created_at $textType,
  sync_status $integerType,
  FOREIGN KEY (incident_id) REFERENCES incidents (id) ON DELETE CASCADE
  )
''');

    // Sync Queue Table (Optional if we query by sync_status,
    // but good for tracking attempts)
    await db.execute('''
CREATE TABLE sync_queue (
  id $autoIdType,
  entity_type $textType, -- 'incident', 'photo'
  entity_id $textType,
  status $textType, -- 'pending', 'in_progress', 'failed'
  retry_count $integerType,
  last_error $textTypeNullable,
  created_at $textType
)
''');
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }

  // CRUD Operations

  Future<void> insertIncident(Map<String, dynamic> incident) async {
    final db = await instance.database;
    await db.insert(
      'incidents',
      incident,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllIncidents() async {
    final db = await instance.database;
    return db.query('incidents', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getPendingIncidents() async {
    final db = await instance.database;
    // Assuming sync_status 0 = pending, 1 = synced
    return db.query('incidents', where: 'sync_status = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getIncidentsByStatus(String status) async {
    final db = await instance.database;
    return db.query(
      'incidents',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, int>> getIncidentCounts() async {
    final db = await instance.database;
    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM incidents'),
    );
    final pending = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM incidents WHERE sync_status = 0',
      ),
    );
    return {
      'total': total ?? 0,
      'pending': pending ?? 0,
    };
  }

  Future<void> updateIncidentSyncStatus(String id, int status) async {
    final db = await instance.database;
    await db.update(
      'incidents',
      {'sync_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertPhoto(Map<String, dynamic> photo) async {
    final db = await instance.database;
    await db.insert(
      'photos',
      photo,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPhotosForIncident(
    String incidentId,
  ) async {
    final db = await instance.database;
    return db.query(
      'photos',
      where: 'incident_id = ?',
      whereArgs: [incidentId],
    );
  }
}

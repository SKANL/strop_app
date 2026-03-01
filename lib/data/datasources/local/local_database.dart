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
      version: 7,
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
    if (oldVersion < 4) {
      // Offline project metadata cache
      await db.execute('''
CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  phase TEXT,
  cover_photo_url TEXT,
  gps_lat REAL,
  gps_lng REAL,
  contingency_budget REAL,
  geofence_radius_meters INTEGER,
  is_active INTEGER NOT NULL DEFAULT 1,
  cached_at TEXT NOT NULL
)
''');
    }
    if (oldVersion < 5) {
      // Add public_token and rejection_reason to support Expediente features
      await db.execute(
        'ALTER TABLE incidents ADD COLUMN public_token TEXT',
      );
      await db.execute(
        'ALTER TABLE incidents ADD COLUMN rejection_reason TEXT',
      );
    }
    if (oldVersion < 6) {
      // Add assigned_to (display name) so fetched incidents show who is responsible
      await db.execute(
        'ALTER TABLE incidents ADD COLUMN assigned_to TEXT',
      );
    }
    if (oldVersion < 7) {
      // Add folio_number to store the server-assigned folio after sync
      await db.execute(
        'ALTER TABLE incidents ADD COLUMN folio_number INTEGER',
      );
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
  sync_status $integerType,
  folio_number INTEGER,
  public_token $textTypeNullable,
  rejection_reason $textTypeNullable,
  assigned_to $textTypeNullable
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

    // Project cache table (offline metadata)
    await db.execute('''
CREATE TABLE projects (
  id $idType,
  name $textType,
  phase $textTypeNullable,
  cover_photo_url $textTypeNullable,
  gps_lat $realType,
  gps_lng $realType,
  contingency_budget $realType,
  geofence_radius_meters INTEGER,
  is_active INTEGER NOT NULL DEFAULT 1,
  cached_at $textType
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
    // sync_status 0 = pending, 1 = synced, 2 = error
    return db.query('incidents', where: 'sync_status = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getErrorIncidents() async {
    final db = await instance.database;
    return db.query('incidents', where: 'sync_status = ?', whereArgs: [2]);
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

  /// Updates the sync_status of a single photo row.
  Future<void> updatePhotoSyncStatus(String photoId, int status) async {
    final db = await instance.database;
    await db.update(
      'photos',
      {'sync_status': status},
      where: 'id = ?',
      whereArgs: [photoId],
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

  /// Upsert an incident - insert or replace if ID already exists
  Future<void> upsertIncident(Map<String, dynamic> incident) async {
    final db = await database;
    await db.insert(
      'incidents',
      incident,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update existing incident fields
  Future<void> updateIncident(Map<String, dynamic> data) async {
    final db = await database;
    final id = data['id'] as String;
    final updateMap = Map<String, dynamic>.from(data)..remove('id');
    await db.update('incidents', updateMap, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteIncident(String incidentId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'photos',
        where: 'incident_id = ?',
        whereArgs: [incidentId],
      );
      await txn.delete(
        'incidents',
        where: 'id = ?',
        whereArgs: [incidentId],
      );
    });
  }

  // ── Project Cache ─────────────────────────────────────────────────────────

  /// Replaces all cached projects with the latest fetch from Supabase.
  Future<void> cacheProjects(List<Map<String, dynamic>> projects) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('projects');
      for (final p in projects) {
        await txn.insert(
          'projects',
          {
            'id': p['id'],
            'name': p['name'],
            'phase': p['phase'],
            'cover_photo_url': p['cover_photo_url'],
            'gps_lat': p['gps_lat'],
            'gps_lng': p['gps_lng'],
            'contingency_budget': p['contingency_budget'],
            'geofence_radius_meters': p['geofence_radius_meters'],
            'is_active': (p['is_active'] as bool? ?? true) ? 1 : 0,
            'cached_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Returns all projects from the local cache, empty list if none stored.
  Future<List<Map<String, dynamic>>> getCachedProjects() async {
    final db = await database;
    return db.query('projects', where: 'is_active = 1');
  }
}

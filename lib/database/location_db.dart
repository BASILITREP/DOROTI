import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocationDB {
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;

    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, "location_points.db");

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute("""
        CREATE TABLE IF NOT EXISTS points (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          latitude REAL,
          longitude REAL,
          speed REAL,
          accuracy REAL,
          timestamp TEXT
        )
        """);
      },
    );

    return _db!;
  }

  static Future<void> insertPoint(Map<String, dynamic> point) async {
    final db = await instance();
    await db.insert("points", point);
  }

  static Future<List<Map<String, dynamic>>> getAllPoints() async {
    final db = await instance();
    return await db.query("points", orderBy: "id ASC");
  }

  static Future<void> deletePoints(List<int> ids) async {
    final db = await instance();
    final batch = db.batch();
    for (var id in ids) {
      batch.delete("points", where: "id = ?", whereArgs: [id]);
    }
    await batch.commit();
  }
}

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class DatabaseService {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'sermon_app.db');
    final factory = getDatabaseFactorySqflite(sqflite.databaseFactory);
    _db = await factory.openDatabase(dbPath);
    return _db!;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "MyDatabase.db";
  static const _databaseVersion = 2;

  static const foldersTable = 'folders';
  static const foldersColId = 'id';
  static const foldersColName = 'name';
  static const foldersColCreatedAt = 'created_at';

  static const cardsTable = 'cards';
  static const cardsColId = 'id';
  static const cardsColName = 'name';
  static const cardsColSuit = 'suit';
  static const cardsColImageUrl = 'image_url';
  static const cardsColFolderId = 'folder_id';
  static const cardsColCreatedAt = 'created_at';

  late Database _db;

  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $foldersTable (
        $foldersColId INTEGER PRIMARY KEY AUTOINCREMENT,
        $foldersColName TEXT UNIQUE NOT NULL,
        $foldersColCreatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $cardsTable (
        $cardsColId INTEGER PRIMARY KEY AUTOINCREMENT,
        $cardsColName TEXT NOT NULL,
        $cardsColSuit TEXT NOT NULL,
        $cardsColImageUrl TEXT,
        $cardsColFolderId INTEGER NOT NULL,
        $cardsColCreatedAt TEXT NOT NULL,
        FOREIGN KEY($cardsColFolderId) REFERENCES $foldersTable($foldersColId) ON DELETE CASCADE
      )
    ''');

    final now = DateTime.now().toIso8601String();
    final folderIds = <String, int>{};
    for (final suit in ['Hearts', 'Spades', 'Diamonds', 'Clubs']) {
      final id = await db.insert(foldersTable, {
        foldersColName: suit,
        foldersColCreatedAt: now,
      });
      folderIds[suit] = id;
    }

    final ranks = ['Ace','2','3','4','5','6','7','8','9','10','Jack','Queen','King'];
    for (final suit in folderIds.keys) {
      final folderId = folderIds[suit]!;
      for (final rank in ranks) {
        await db.insert(cardsTable, {
          cardsColName: '$rank of $suit',
          cardsColSuit: suit,
          cardsColImageUrl: '',
          cardsColFolderId: folderId,
          cardsColCreatedAt: now,
        });
      }
    }
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS my_table');
      await _onCreate(db, newVersion);
    }
  }

  Future<List<Map<String, dynamic>>> fetchFolders() async {
    return await _db.query(foldersTable, orderBy: '$foldersColName ASC');
  }

  Future<int> countCardsInFolder(int folderId) async {
    final res = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $cardsTable WHERE $cardsColFolderId = ?',
      [folderId],
    );
    return (res.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> fetchCardsForFolder(int folderId) async {
    return await _db.query(
      cardsTable,
      where: '$cardsColFolderId = ?',
      whereArgs: [folderId],
      orderBy: '$cardsColCreatedAt DESC, $cardsColName ASC',
    );
  }

  Future<int> addCard({
    required String name,
    required String suit,
    required int folderId,
    String imageUrl = '',
  }) async {
    return await _db.insert(cardsTable, {
      cardsColName: name,
      cardsColSuit: suit,
      cardsColImageUrl: imageUrl,
      cardsColFolderId: folderId,
      cardsColCreatedAt: DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateCard({
    required int id,
    required String name,
    required String suit,
    required int folderId,
    String imageUrl = '',
  }) async {
    return await _db.update(
      cardsTable,
      {
        cardsColName: name,
        cardsColSuit: suit,
        cardsColImageUrl: imageUrl,
        cardsColFolderId: folderId,
      },
      where: '$cardsColId = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCard(int id) async {
    return await _db.delete(
      cardsTable,
      where: '$cardsColId = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getFolderByName(String name) async {
    final rows = await _db.query(
      foldersTable,
      where: '$foldersColName = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>?> getFolderById(int id) async {
    final rows = await _db.query(
      foldersTable,
      where: '$foldersColId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }
}

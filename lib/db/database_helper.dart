import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Isar? _isar;

  DatabaseHelper._init();

  Future<Isar> get database async {
    if (_isar != null) return _isar!;
    _isar = await _initDB();
    return _isar!;
  }

  Future<Isar> _initDB() async {
    if (kIsWeb) {
      throw UnsupportedError('Isar not supported on Web in this version');
    }
    final dirPath = (await getApplicationDocumentsDirectory()).path;
    final isar = await Isar.open(
      [NoteSchema],
      directory: dirPath,
    );
    return isar;
  }

  Future<List<Note>> getNotes() async {
    final db = await database;
    return await db.notes.where().findAll();
  }

  Future<void> add(Note note) async {
    final db = await database;
    await db.writeTxn(() async {
      await db.notes.put(note);
    });
  }

  Future<void> update(Note note) async {
    final db = await database;
    await db.writeTxn(() async {
      await db.notes.put(note);
    });
  }

  Future<void> remove(int id) async {
    final db = await database;
    await db.writeTxn(() async {
      await db.notes.delete(id);
    });
  }
}

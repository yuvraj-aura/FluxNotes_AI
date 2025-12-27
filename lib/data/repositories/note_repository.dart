// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flux_notes/data/models/note_model.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'note_repository.g.dart';

@riverpod
NoteRepository noteRepository(NoteRepositoryRef ref) => NoteRepository();

@riverpod
Stream<List<Note>> notesStream(NotesStreamRef ref) {
  final repository = ref.watch(noteRepositoryProvider);
  return repository.getAllNotes();
}

class NoteRepository {
  late Future<Isar> db;

  NoteRepository() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [NoteSchema],
        directory: dir.path,
        inspector: true,
      );
    }
    return Future.value(Isar.getInstance());
  }

  Future<Note> createNote() async {
    final note = Note()
      ..uuid = const Uuid().v4()
      ..title = ''
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..blocks = [
        ContentBlock()
          ..id = const Uuid().v4()
          ..type = BlockType.paragraph
          ..content = ''
      ]
      ..tags = [];

    // We don't save it initially, just return a blank object.
    // Or we can save it if that's the desired flow.
    // Given the prompt "Returns a new blank note", let's just return the object.
    return note;
  }

  Future<void> saveNote(Note note) async {
    final isar = await db;
    note.updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.notes.put(note);
    });
  }

  Stream<List<Note>> getAllNotes() async* {
    final isar = await db;
    yield* isar.notes
        .where()
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<void> deleteNote(int id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.notes.delete(id);
    });
  }

  Future<void> checkAndSeedDemoNote() async {
    final isar = await db;
    final count = await isar.notes.count();
    if (count == 0) {
      final note = Note()
        ..uuid = const Uuid().v4()
        ..title = 'How to enable AI 🧠'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now()
        ..isPinned = true
        ..summary = 'Guide to enabling AI features'
        ..tags = ['#guide', '#fluxnotes']
        ..blocks = [
          ContentBlock()
            ..id = const Uuid().v4()
            ..type = BlockType.paragraph
            ..content =
                'FluxNotes is local-first and privacy-focused. To enable the AI features (Auto-tagging, Chat), go to Settings > Brain Connection and enter your free Google Gemini Key.',
          ContentBlock()
            ..id = const Uuid().v4()
            ..type = BlockType.paragraph
            ..content =
                '1. Go to Settings tab\n2. Tap "Brain Connection"\n3. Click "Get a Free Gemini Key"\n4. Paste it and save!',
        ];

      await isar.writeTxn(() async {
        await isar.notes.put(note);
      });
    }
  }
}

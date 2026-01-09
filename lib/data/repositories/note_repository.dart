import 'dart:async';
import 'package:flutter/foundation.dart';
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
  // In-memory storage for Web
  static final List<Note> _webNotes = [];
  static final _webStreamController = StreamController<List<Note>>.broadcast();

  NoteRepository() {
    if (!kIsWeb) {
      db = openDB();
    } else {
      // Initialize with error to prevent hanging if await db is hit by mistake
      db = Future.error('Isar not supported on Web');
      // Seed demo data for Web so graph isn't empty
      checkAndSeedDemoNote();
    }
  }

  Future<Isar> openDB() async {
    if (kIsWeb) {
      // Should not be called on Web ideally, or returns dummy
      return Future.error('Isar not supported on Web in this version');
    }
    if (Isar.instanceNames.isEmpty) {
      final dirPath = (await getApplicationDocumentsDirectory()).path;
      return await Isar.open(
        [NoteSchema],
        directory: dirPath,
        inspector: false,
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
    // 1. Extract hashtags from content blocks
    final tags = <String>{};
    final regex = RegExp(r'#([a-zA-Z0-9_]+)');
    for (var block in note.blocks) {
      final matches = regex.allMatches(block.content);
      for (var match in matches) {
        tags.add(match.group(0)!); // Add the full tag including #
      }
    }
    // REPLACEMENT: We replace the tags list entirely with what is found in the text.
    // This prevents "partial tags" (e.g. #flux -> #fluxnote) from accumulating
    // as separate tags due to debounce saving while typing.
    note.tags = tags.toList();

    if (kIsWeb) {
      final index = _webNotes.indexWhere((n) => n.uuid == note.uuid);
      if (index >= 0) {
        _webNotes[index] = note;
      } else {
        // Assign a temp ID for Web since Isar isn't doing it
        if (note.id == Isar.autoIncrement) {
          note.id = DateTime.now().millisecondsSinceEpoch;
        }
        _webNotes.add(note);
      }
      _webStreamController.add(List.from(_webNotes));
      return;
    }

    final isar = await db;
    note.updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.notes.put(note);
    });
  }

  Future<Note?> getNote(int id) async {
    if (kIsWeb) {
      debugPrint(
          '[NoteRepo] getNote($id) for Web. Total notes: ${_webNotes.length}');
      try {
        final note = _webNotes.firstWhere((n) => n.id == id);
        debugPrint('[NoteRepo] Found note: ${note.uuid}');
        return note;
      } catch (_) {
        debugPrint('[NoteRepo] Note not found with id: $id');
        return null;
      }
    }
    final isar = await db;
    return await isar.notes.get(id);
  }

  Stream<List<Note>> getAllNotes() async* {
    if (kIsWeb) {
      // Emit initial value FIRST, then listen to stream
      yield List.from(_webNotes);
      yield* _webStreamController.stream;
      return;
    }

    final isar = await db;
    yield* isar.notes
        .where()
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<void> deleteNote(int id) async {
    if (kIsWeb) {
      // For Web, id might not be reliable if not set manually, but let's assume filtering by internal logic if needed
      // Actually NoteRepository.deleteNote takes int id (Isar ID).
      // On Web we might not have valid integer IDs if we default to -1 or similar.
      // But typically we should use UUID for robust deletion across systems.
      // For now, let's try to find by ID if we simulate auto-increment, or just ignore.
      // Better: Use UUID to delete if possible, but the signature matches Isar.
      // Let's iterate and find the note with this 'id' if we assigned one, or just re-map.
      _webNotes.removeWhere((n) => n.id == id);
      _webStreamController.add(List.from(_webNotes));
      return;
    }

    final isar = await db;
    await isar.writeTxn(() async {
      await isar.notes.delete(id);
    });
  }

  Future<void> checkAndSeedDemoNote() async {
    if (kIsWeb) {
      if (_webNotes.isEmpty) {
        final note = Note()
          ..id = 1 // Explicit ID for demo note on Web
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
                  'FluxNotes is local-first. On Web, data is currently ephemeral (cleared on refresh).',
          ];
        _webNotes.add(note);
        _webStreamController.add(List.from(_webNotes));
      }
      return;
    }

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
            ..type = BlockType.heading1
            ..content = 'Welcome to FluxNotes AI! 🌌',
          ContentBlock()
            ..id = const Uuid().v4()
            ..type = BlockType.paragraph
            ..content =
                'FluxNotes is your local-first, privacy-focused second brain. It combines fast note-taking with powerful AI intelligence.',
          ContentBlock()
            ..id = const Uuid().v4()
            ..type = BlockType.heading2
            ..content = '🚀 Key Features',
          ContentBlock()
            ..id = const Uuid().v4()
            ..type = BlockType.bullet
            ..content =
                '🧠 AI Search: Type "What is..." in the Search tab to ask your notes directly.',
          ContentBlock()
            ..id = const Uuid().v4()
            ..type = BlockType.bullet
            ..content =
                '🏷️ Auto-Tagging: Just write #hashtags, and they are instantly saved.',
          ContentBlock()
            ..id = const Uuid().v4()
            ..type = BlockType.bullet
            ..content =
                '🔍 Real-Time Filter: The Home search bar instantly finds what you need.',
          ContentBlock()
            ..id = const Uuid().v4()
            ..type = BlockType.bullet
            ..content =
                '📶 Sorting: Arrange notes by Updated, Created, or Title.',
          ContentBlock()
            ..id = const Uuid().v4()
            ..type = BlockType.bullet
            ..content =
                '🔒 Data Vault: Export backups and keep your data safe.',
          ContentBlock()
            ..id = const Uuid().v4()
            ..type = BlockType.heading2
            ..content = '⚡ How to Enable AI',
          ContentBlock()
            ..id = const Uuid().v4()
            ..type = BlockType.paragraph
            ..content =
                '1. Go to Settings > Brain Connection.\n2. Tap "Get a Free Gemini Key" (free from Google).\n3. Paste the key and save.\n4. Select your preferred model (Gemini 2.5 Flash recommended).',
        ];

      await isar.writeTxn(() async {
        await isar.notes.put(note);
      });
    }
  }

  Future<void> deleteAllNotes() async {
    if (kIsWeb) {
      _webNotes.clear();
      _webStreamController.add(List.from(_webNotes));
      return;
    }

    final isar = await db;
    await isar.writeTxn(() async {
      await isar.notes.clear();
    });
  }

  Future<void> saveNotes(List<Note> notes) async {
    if (kIsWeb) {
      for (var note in notes) {
        final index = _webNotes.indexWhere((n) => n.uuid == note.uuid);
        if (index >= 0) {
          _webNotes[index] = note;
        } else {
          _webNotes.add(note);
        }
      }
      _webStreamController.add(List.from(_webNotes));
      return;
    }

    final isar = await db;
    await isar.writeTxn(() async {
      await isar.notes.putAll(notes);
    });
  }

  Future<List<Note>> getAllNotesList() async {
    if (kIsWeb) {
      return List.from(_webNotes);
    }
    final isar = await db;
    return isar.notes.where().sortByUpdatedAtDesc().findAll();
  }
}

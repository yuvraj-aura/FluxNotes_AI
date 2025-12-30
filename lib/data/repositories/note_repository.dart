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
      // Initialize with non-terminating future or error to satisfy type system
      // We cannot use Future.value(null) as it's not a Future<Isar>
      db = Completer<Isar>().future;
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
    // Update tags if any found, otherwise keep existing (or clear? usually we want to sync with content)
    // If we want auto-tagging to be the ONLY source of tags, we overwrite.
    // If manual tags exist, we might want to merge.
    // For now, let's merge with existing tags to preserve manual ones, or overwrite if we assume tags come from text.
    // Let's merge for safety.
    final existingTags = Set<String>.from(note.tags);
    existingTags.addAll(tags);
    note.tags = existingTags.toList();

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
      try {
        return _webNotes.firstWhere((n) => n.id == id);
      } catch (_) {
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

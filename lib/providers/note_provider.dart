import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../db/database_helper.dart';

class NotesNotifier extends StateNotifier<List<Note>> {
  NotesNotifier() : super([]);

  Future<void> loadNotes() async {
    final notes = await DatabaseHelper.instance.getNotes();
    state = notes;
  }

  Future<void> addNote(Note note) async {
    await DatabaseHelper.instance.add(note);
    await loadNotes();
  }

  Future<void> updateNote(Note note) async {
    await DatabaseHelper.instance.update(note);
    await loadNotes();
  }

  Future<void> deleteNote(int id) async {
    await DatabaseHelper.instance.remove(id);
    await loadNotes();
  }
}

final notesProvider = StateNotifierProvider<NotesNotifier, List<Note>>((ref) {
  return NotesNotifier()..loadNotes();
});

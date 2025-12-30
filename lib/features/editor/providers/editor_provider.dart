import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:uuid/uuid.dart';

class NoteEditorNotifier extends StateNotifier<AsyncValue<Note>> {
  final NoteRepository _noteRepository;

  NoteEditorNotifier(this._noteRepository) : super(const AsyncLoading());

  Future<void> loadNote(int id) async {
    state = const AsyncLoading();
    try {
      final note = await _noteRepository.getNote(id);
      if (note != null) {
        state = AsyncData(note);
      } else {
        state = AsyncError('Note not found', StackTrace.current);
      }
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  void updateBlockType(String blockId, BlockType newType) {
    state.whenData((note) {
      final blockIndex = note.blocks.indexWhere((b) => b.id == blockId);
      if (blockIndex != -1) {
        final updatedBlocks = List<ContentBlock>.from(note.blocks);
        updatedBlocks[blockIndex].type = newType;
        note.blocks = updatedBlocks;
        state = AsyncData(note);
      }
    });
  }

  void updateBlockText(String blockId, String newText) {
    state.whenData((note) {
      final blockIndex = note.blocks.indexWhere((b) => b.id == blockId);
      if (blockIndex != -1) {
        // Isar embedded objects are immutable in the sense that we should replace the list
        // or re-assign. But we can modify properties if we save the parent.
        // However, to trigger state change in riverpod, we should copy.
        final updatedBlocks = List<ContentBlock>.from(note.blocks);
        updatedBlocks[blockIndex].content = newText;
        // Optimization: modify current list directly if assuming mutable,
        // but for safety in StateNotifier:
        note.blocks = updatedBlocks;
        state = AsyncData(note);
      }
    });
  }

  void updateTitle(String newTitle) {
    state.whenData((note) {
      note.title = newTitle;
      state = AsyncData(note);
    });
  }

  void updateBlockStyle(String blockId,
      {String? textColor, String? backgroundColor}) {
    state.whenData((note) {
      final blockIndex = note.blocks.indexWhere((b) => b.id == blockId);
      if (blockIndex != -1) {
        final updatedBlocks = List<ContentBlock>.from(note.blocks);
        if (textColor != null) {
          updatedBlocks[blockIndex].textColor = textColor;
        }
        if (backgroundColor != null) {
          updatedBlocks[blockIndex].backgroundColor = backgroundColor;
        }
        note.blocks = updatedBlocks;
        state = AsyncData(note);
      }
    });
  }

  void addBlock(int index, BlockType type) {
    state.whenData((note) {
      final newBlock = ContentBlock()
        ..id = const Uuid().v4()
        ..type = type
        ..content = '';

      final updatedBlocks = List<ContentBlock>.from(note.blocks)
        ..insert(index, newBlock);

      note.blocks = updatedBlocks;
      state = AsyncData(note);
    });
  }

  void deleteBlock(String blockId) {
    state.whenData((note) {
      final updatedBlocks = List<ContentBlock>.from(note.blocks)
        ..removeWhere((b) => b.id == blockId);
      note.blocks = updatedBlocks;
      state = AsyncData(note);
    });
  }

  void updateBlockMetadata(String blockId, String? metadata) {
    state.whenData((note) {
      final blockIndex = note.blocks.indexWhere((b) => b.id == blockId);
      if (blockIndex != -1) {
        final updatedBlocks = List<ContentBlock>.from(note.blocks);
        updatedBlocks[blockIndex].metadata = metadata;
        note.blocks = updatedBlocks;
        state = AsyncData(note);
      }
    });
  }

  Future<void> saveNote() async {
    if (state.hasValue) {
      await _noteRepository.saveNote(state.value!);
    }
  }
}

final noteEditorProvider =
    StateNotifierProvider.autoDispose<NoteEditorNotifier, AsyncValue<Note>>(
        (ref) {
  return NoteEditorNotifier(ref.watch(noteRepositoryProvider));
});

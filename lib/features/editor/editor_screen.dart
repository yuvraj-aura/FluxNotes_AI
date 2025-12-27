import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:flux_notes/features/editor/providers/editor_provider.dart';
import 'package:flux_notes/features/editor/widgets/block_widget.dart';

// Simple Debouncer
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class EditorScreen extends ConsumerStatefulWidget {
  final int noteId;
  final bool autofocusTitle;

  const EditorScreen({
    super.key,
    required this.noteId,
    this.autofocusTitle = false,
  });

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final Map<String, TextEditingController> _blockControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final _debouncer = Debouncer(milliseconds: 1000);
  final _scrollController = ScrollController();
  bool _isSaving = false;
  String? _focusedBlockId;

  @override
  void initState() {
    super.initState();
    ref.read(noteEditorProvider.notifier).loadNote(widget.noteId);

    if (widget.autofocusTitle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _titleFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _handleGhostNote();
    _titleController.dispose();
    _titleFocusNode.dispose();
    for (var controller in _blockControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes.values) {
      focusNode.removeListener(_onFocusChange);
      focusNode.dispose();
    }
    _debouncer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleGhostNote() {
    final note = ref.read(noteEditorProvider).value;
    if (widget.autofocusTitle && note != null) {
      final isTitleEmpty = note.title.isEmpty;
      final isContentEmpty =
          (note.blocks.length == 1 && note.blocks.first.content.isEmpty);

      if (isTitleEmpty && isContentEmpty) {
        ref.read(noteRepositoryProvider).deleteNote(widget.noteId);
      }
    }
  }

  void _onFocusChange() {
    String? focusedId;
    for (final entry in _focusNodes.entries) {
      if (entry.value.hasFocus) {
        focusedId = entry.key;
        break;
      }
    }
    if (focusedId != _focusedBlockId) {
      setState(() {
        _focusedBlockId = focusedId;
      });
    }
  }

  void _onTitleChanged() {
    ref.read(noteEditorProvider.notifier).updateTitle(_titleController.text);
    _saveNoteWithDebounce();
  }

  void _setupControllers(Note note) {
    if (_titleController.text != note.title) {
      _titleController.text = note.title;
    }
    // Simplified check: we assume title listener is added once or managed better.
    // Since this runs in build, adding a listener every time is bad.
    // However, existing logic checks private hasListeners.
    // We can skip adding if we assume it persists, or properly manage it.
    // Given the structure, let's just use the current text check and rely on the fact
    // that listeners are long-lived with the controller.
    // Ideally, move listener addition to initState or when key changes.
    // For now, I'll remove the check as a quick fix if I move it to initState,
    // but here I'll just rely on a flag I'll add or just accept it's added.
    // Actually, let's use a flag. I need to add the flag to the class first.
    // Since I can't add a flag easily in a replace chunk without context,
    // I'll assume we can just add the listener if it's not already added?
    // No, standard way is to remove and add, or just add once.
    // Let's remove the listener first to be safe (idempotent).
    // But I don't have reference to the EXACT closure function to remove it.
    // So I define the listener as a method.

    // For this specific error, I should just remove the check and fix the logic.
    // But I can't easily change the structure in small chunks.
    // I will rewrite _setupControllers to be safer.

    // Actually, I'll just change the hasListener check to always add and assume
    // we handle multiple listeners? No, that causes bugs.

    // Best fix without refactoring: logic is flawed.
    // I'll make the listener a method `_onTitleChanged` and remove/add it.
    _titleController.removeListener(_onTitleChanged);
    _titleController.addListener(_onTitleChanged);

    final currentBlockIds = note.blocks.map((b) => b.id).toSet();
    _blockControllers
        .removeWhere((blockId, _) => !currentBlockIds.contains(blockId));
    _focusNodes.removeWhere((blockId, focusNode) {
      if (!currentBlockIds.contains(blockId)) {
        focusNode.removeListener(_onFocusChange);
        focusNode.dispose();
        return true;
      }
      return false;
    });

    for (var block in note.blocks) {
      if (!_blockControllers.containsKey(block.id)) {
        final controller = TextEditingController(text: block.content);
        controller.addListener(() {
          ref
              .read(noteEditorProvider.notifier)
              .updateBlockText(block.id, controller.text);
          _saveNoteWithDebounce();
        });
        _blockControllers[block.id] = controller;
      } else {
        if (_blockControllers[block.id]!.text != block.content) {
          _blockControllers[block.id]!.text = block.content;
        }
      }

      if (!_focusNodes.containsKey(block.id)) {
        final focusNode = FocusNode();
        focusNode.addListener(_onFocusChange);
        _focusNodes[block.id] = focusNode;
      }
    }
  }

  void _saveNoteWithDebounce() {
    setState(() {
      _isSaving = true;
    });
    _debouncer.run(() async {
      await ref.read(noteEditorProvider.notifier).saveNote();
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    });
  }

  void _addNewBlock(String currentBlockId) {
    final note = ref.read(noteEditorProvider).value!;
    final index = note.blocks.indexWhere((b) => b.id == currentBlockId);
    ref
        .read(noteEditorProvider.notifier)
        .addBlock(index + 1, BlockType.paragraph);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newBlockId =
          ref.read(noteEditorProvider).value!.blocks[index + 1].id;
      final newFocusNode = _focusNodes[newBlockId];
      newFocusNode?.requestFocus();
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 50,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _deleteBlockAndFocusPrevious(String blockId) {
    final note = ref.read(noteEditorProvider).value!;
    final index = note.blocks.indexWhere((b) => b.id == blockId);

    if (index > 0) {
      final previousBlockId = note.blocks[index - 1].id;
      _focusNodes[previousBlockId]?.requestFocus();
    }

    ref.read(noteEditorProvider.notifier).deleteBlock(blockId);
  }

  @override
  Widget build(BuildContext context) {
    final noteState = ref.watch(noteEditorProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                _isSaving ? 'Saving...' : 'Saved',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
      body: noteState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (note) {
          _setupControllers(note);

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: note.blocks.length + 1, // +1 for the title
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Title',
                      hintStyle: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }

              final blockIndex = index - 1;
              final block = note.blocks[blockIndex];
              final controller = _blockControllers[block.id];
              final focusNode = _focusNodes[block.id];

              if (controller == null || focusNode == null) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: BlockWidget(
                  controller: controller,
                  focusNode: focusNode,
                  isFocused: _focusedBlockId == block.id,
                  onEnterPressed: () => _addNewBlock(block.id),
                  onBackspacePressed: () =>
                      _deleteBlockAndFocusPrevious(block.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

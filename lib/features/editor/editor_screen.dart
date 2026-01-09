import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:flux_notes/features/editor/providers/editor_provider.dart';
import 'package:flux_notes/features/editor/widgets/block_widget.dart';
import 'package:flux_notes/features/editor/widgets/editor_toolbar.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:flux_notes/features/editor/controllers/rich_text_controller.dart';

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
  // Use RichTextController for title to support partial styling in title
  final _titleRichController = RichTextController();
  final _titleFocusNode = FocusNode();

  // Use RichTextController for blocks
  final Map<String, RichTextController> _blockRichControllers = {};
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

    _titleFocusNode.addListener(() {
      if (_titleFocusNode.hasFocus) {
        setState(() {
          _focusedBlockId = null; // Title focused
        });
      }
    });

    // Listener for Title spans update (serialization)
    _titleRichController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _handleGhostNote();
    _titleRichController.dispose();
    _titleFocusNode.dispose();
    for (var controller in _blockRichControllers.values) {
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
    if (focusedId != _focusedBlockId && focusedId != null) {
      setState(() {
        _focusedBlockId = focusedId;
      });
    }
  }

  void _onTitleChanged() {
    // Check if text changed
    final note = ref.read(noteEditorProvider).value;
    if (note != null && note.title != _titleRichController.text) {
      ref
          .read(noteEditorProvider.notifier)
          .updateTitle(_titleRichController.text);
    }
    // We should also look into saving metadata if we had a way to update it in model.
    // For now, let's just trigger save.
    _saveNoteWithDebounce();
  }

  void _setupControllers(Note note) {
    if (_titleRichController.text != note.title) {
      // Restore text and metadata if first load or external change
      // Note: RichTextController needs a way to set spawns if we want to load them.
      // But currently we don't have a clean way to load 'titleMetadata' into _titleController
      // because we initialized it empty.
      // We should ideally re-create it or add a method.
      // For now, simple text setting (spans lost on reload until we fix this).
      // However, the user flow is usually staying in editor.

      // Basic text sync
      _titleRichController.text = note.title;
      _titleRichController.setMetadata(note.titleMetadata);
    }

    final currentBlockIds = note.blocks.map((b) => b.id).toSet();
    _blockRichControllers
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
      if (!_blockRichControllers.containsKey(block.id)) {
        final controller =
            RichTextController(text: block.content, metadata: block.metadata);
        controller.addListener(() {
          if (controller.text != block.content) {
            ref
                .read(noteEditorProvider.notifier)
                .updateBlockText(block.id, controller.text);
          }
          // Debounce save for metadata/text changes
          _saveNoteWithDebounce();
        });
        _blockRichControllers[block.id] = controller;
      } else {
        // We generally trust the controller over the model while editing to avoid cursor jumping
        // But if model changed externally (e.g. undo/redo?), we might need sync.
        // For now, simpler is better.
      }

      if (!_focusNodes.containsKey(block.id)) {
        final focusNode = FocusNode();
        focusNode.addListener(_onFocusChange);
        _focusNodes[block.id] = focusNode;
      }
    }
  }

  void _saveNoteWithDebounce() {
    if (!mounted) return;
    setState(() {
      _isSaving = true;
    });
    _debouncer.run(() async {
      if (!mounted) return; // Guard before use
      try {
        await ref.read(noteEditorProvider.notifier).saveNote();
      } catch (e) {
        debugPrint('Save Error: $e');
      }
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    });
  }

  void _addNewBlock(String currentBlockId) {
    if (!mounted) return;
    final note = ref.read(noteEditorProvider).value!;
    final index = note.blocks.indexWhere((b) => b.id == currentBlockId);
    ref
        .read(noteEditorProvider.notifier)
        .addBlock(index + 1, BlockType.paragraph);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Guard ref access
      // Wait for rebuild so controller exists
      final newNote = ref.read(noteEditorProvider).value!;
      if (index + 1 < newNote.blocks.length) {
        final newBlockId = newNote.blocks[index + 1].id;
        final newFocusNode = _focusNodes[newBlockId];
        newFocusNode?.requestFocus();

        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 50,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
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
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                _isSaving ? 'Saving...' : 'Saved',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white70,
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

          return GestureDetector(
            onTap: () {
              // Dismiss focus and toolbar when tapping outside blocks
              FocusScope.of(context).unfocus();
              setState(() {
                _focusedBlockId = null;
              });
            },
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 100.0),
                    itemCount: note.blocks.length + 1, // +1 for the title
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: TextField(
                            controller: _titleRichController,
                            focusNode: _titleFocusNode,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration.collapsed(
                              hintText: 'Title',
                              hintStyle: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }

                      final blockIndex = index - 1;
                      final block = note.blocks[blockIndex];
                      final controller = _blockRichControllers[block.id];
                      final focusNode = _focusNodes[block.id];

                      if (controller == null || focusNode == null) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: BlockWidget(
                          controller: controller,
                          focusNode: focusNode,
                          block: block, // Pass the full block
                          isFocused: _focusedBlockId == block.id,
                          onEnterPressed: () => _addNewBlock(block.id),
                          onBackspacePressed: () =>
                              _deleteBlockAndFocusPrevious(block.id),
                          onTypeChanged: (newType) {
                            ref
                                .read(noteEditorProvider.notifier)
                                .updateBlockType(block.id, newType);
                          },
                          onStyleChanged: (textColor, backgroundColor) {
                            ref
                                .read(noteEditorProvider.notifier)
                                .updateBlockStyle(
                                  block.id,
                                  textColor: textColor,
                                  backgroundColor: backgroundColor,
                                );
                          },
                        ),
                      );
                    },
                  ),
                ),
                // Show Toolbar if a block is focused
                if (_focusedBlockId != null) ...[
                  Builder(builder: (context) {
                    final focusedBlock = note.blocks
                        .where((b) => b.id == _focusedBlockId)
                        .firstOrNull;

                    if (focusedBlock == null) return const SizedBox.shrink();
                    final controller = _blockRichControllers[_focusedBlockId];

                    return Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.cardDark,
                        border: Border(
                          top: BorderSide(color: Colors.white12, width: 0.5),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: controller != null
                            ? AnimatedBuilder(
                                animation: controller,
                                builder: (context, _) {
                                  return EditorToolbar(
                                    blockId: _focusedBlockId!,
                                    block: focusedBlock,
                                    controller: controller,
                                  );
                                })
                            : EditorToolbar(
                                blockId: _focusedBlockId!,
                                block: focusedBlock,
                              ),
                      ),
                    );
                  }),
                ] else if (_titleFocusNode.hasFocus) ...[
                  // Show Toolbar for Title
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.cardDark,
                      border: Border(
                        top: BorderSide(color: Colors.white12, width: 0.5),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: AnimatedBuilder(
                        animation: _titleRichController,
                        builder: (context, _) => EditorToolbar(
                          blockId: 'title',
                          block: ContentBlock(
                              id: 'title', type: BlockType.heading1),
                          controller: _titleRichController,
                        ),
                      ),
                    ),
                  )
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

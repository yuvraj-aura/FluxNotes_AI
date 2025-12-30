import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/features/editor/providers/editor_provider.dart';
import 'package:flux_notes/theme/app_theme.dart';

import 'package:flux_notes/features/editor/controllers/rich_text_controller.dart';

class EditorToolbar extends ConsumerWidget {
  final String blockId;
  final ContentBlock block;
  final RichTextController? controller;

  const EditorToolbar({
    super.key,
    required this.blockId,
    required this.block,
    this.controller,
  });

  Map<String, dynamic> _getMetadata() {
    if (block.metadata == null || block.metadata!.isEmpty) return {};
    try {
      return jsonDecode(block.metadata!) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  void _updateMetadata(WidgetRef ref, Map<String, dynamic> changes) {
    if (controller != null) {
      // If controller exists, rely on it to update internal spans and sync later.
      // Actually, controller updates UI. We need to persist changes.
      // Controller.metadata getter returns the JSON span string.
      // We should update the block's metadata with controller's metadata.
      // But here we are toggling style.
      return;
    }

    final currentMeta = _getMetadata();
    final newMeta = {...currentMeta, ...changes};
    newMeta.removeWhere((key, value) => value == null);

    ref.read(noteEditorProvider.notifier).updateBlockMetadata(
          blockId,
          jsonEncode(newMeta),
        );
  }

  void _toggleStyle(WidgetRef ref, String key, bool currentValue) {
    if (controller != null) {
      controller!.toggleStyle(key, !currentValue);
      // Trigger save of metadata
      ref.read(noteEditorProvider.notifier).updateBlockMetadata(
            blockId,
            controller!.metadata,
          );
    } else {
      _updateMetadata(ref, {key: !currentValue});
    }
  }

  void _setTextColor(WidgetRef ref, int? colorValue) {
    if (controller != null) {
      controller!.setColor('color', colorValue);
      ref.read(noteEditorProvider.notifier).updateBlockMetadata(
            blockId,
            controller!.metadata,
          );
    } else {
      ref.read(noteEditorProvider.notifier).updateBlockStyle(
            blockId,
            textColor: colorValue?.toString(),
          );
    }
  }

  void _setBackgroundColor(WidgetRef ref, int? colorValue) {
    if (controller != null) {
      controller!.setColor('backgroundColor', colorValue);
      ref.read(noteEditorProvider.notifier).updateBlockMetadata(
            blockId,
            controller!.metadata,
          );
    } else {
      ref.read(noteEditorProvider.notifier).updateBlockStyle(
            blockId,
            backgroundColor: colorValue?.toString(),
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool isBold = false;
    bool isItalic = false;
    bool isUnderline = false;
    int? currentColor;
    int? currentBgColor;

    if (controller != null) {
      isBold = controller!.isSelectionBold;
      isItalic = controller!.isSelectionItalic;
      isUnderline = controller!.isSelectionUnderline;
      currentColor = controller!.selectionColor;
      currentBgColor = controller!.selectionBackgroundColor;
    } else {
      final meta = _getMetadata();
      isBold = meta['bold'] == true;
      isItalic = meta['italic'] == true;
      isUnderline = meta['underline'] == true;

      // Also check block properties for colors if using old model
      currentColor = block.textColor != null
          ? int.tryParse(block.textColor!)
          : (meta['color'] as int?);
      currentBgColor = block.backgroundColor != null
          ? int.tryParse(block.backgroundColor!)
          : (meta['backgroundColor'] as int?);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        border: const Border(
          top: BorderSide(color: Colors.white12, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Block Type Selector
              _BlockTypeSelector(
                currentType: block.type,
                onTypeChanged: (type) {
                  ref
                      .read(noteEditorProvider.notifier)
                      .updateBlockType(blockId, type);
                },
              ),
              const VerticalDivider(width: 24, color: Colors.white24),

              // Formatting Actions
              _ToolbarButton(
                icon: Icons.format_bold,
                isActive: isBold,
                onTap: () => _toggleStyle(ref, 'bold', isBold),
              ),
              _ToolbarButton(
                icon: Icons.format_italic,
                isActive: isItalic,
                onTap: () => _toggleStyle(ref, 'italic', isItalic),
              ),
              _ToolbarButton(
                icon: Icons.format_underline,
                isActive: isUnderline,
                onTap: () => _toggleStyle(ref, 'underline', isUnderline),
              ),
              const SizedBox(width: 8),

              // Color Pickers
              _ColorButton(
                icon: Icons.format_color_text,
                color:
                    currentColor != null ? Color(currentColor) : Colors.white,
                onColorSelected: (color) => _setTextColor(ref, color?.value),
              ),
              const SizedBox(width: 8),
              _ColorButton(
                icon: Icons.format_color_fill,
                color: currentBgColor != null
                    ? Color(currentBgColor)
                    : Colors.transparent,
                isBackground: true,
                onColorSelected: (color) =>
                    _setBackgroundColor(ref, color?.value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockTypeSelector extends StatelessWidget {
  final BlockType currentType;
  final ValueChanged<BlockType> onTypeChanged;

  const _BlockTypeSelector({
    required this.currentType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<BlockType>(
        value: currentType,
        dropdownColor: AppTheme.cardDark,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
        style: const TextStyle(color: Colors.white),
        items: BlockType.values.map((type) {
          String label;
          switch (type) {
            case BlockType.paragraph:
              label = 'Text';
              break;
            case BlockType.heading1:
              label = 'Heading 1';
              break;
            case BlockType.heading2:
              label = 'Heading 2';
              break;
            case BlockType.todo:
              label = 'To-do';
              break;
            case BlockType.bullet:
              label = 'Bullet List';
              break;
            default:
              label = type.name;
          }

          return DropdownMenuItem(
            value: type,
            child: Text(label),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) onTypeChanged(val);
        },
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? Colors.white : Colors.white70,
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isBackground;
  final ValueChanged<Color?> onColorSelected;

  const _ColorButton({
    required this.icon,
    required this.color,
    this.isBackground = false,
    required this.onColorSelected,
  });

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBackground ? 'Background Color' : 'Text Color',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ColorOption(
                    color: null,
                    isNull: true,
                    onSelect: onColorSelected), // Reset
                _ColorOption(color: Colors.white, onSelect: onColorSelected),
                _ColorOption(
                    color: Colors.redAccent, onSelect: onColorSelected),
                _ColorOption(
                    color: Colors.orangeAccent, onSelect: onColorSelected),
                _ColorOption(
                    color: Colors.amberAccent,
                    onSelect: onColorSelected), // Yellow-ish
                _ColorOption(
                    color: Colors.greenAccent, onSelect: onColorSelected),
                _ColorOption(
                    color: Colors.lightBlueAccent,
                    onSelect: onColorSelected), // Cyan/Light Blue
                _ColorOption(
                    color: Colors.blueAccent, onSelect: onColorSelected),
                _ColorOption(
                    color: Colors.purpleAccent, onSelect: onColorSelected),
                _ColorOption(
                    color: Colors.pinkAccent, onSelect: onColorSelected),
                if (isBackground)
                  _ColorOption(
                      color: Colors.grey[800]!, onSelect: onColorSelected),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showColorPicker(context),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white70),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color == Colors.transparent ? Colors.white10 : color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color? color;
  final bool isNull;
  final ValueChanged<Color?> onSelect;

  const _ColorOption({
    this.color,
    this.isNull = false,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onSelect(color);
        Navigator.pop(context);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isNull ? Colors.transparent : color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        child: isNull
            ? const Icon(Icons.format_clear, size: 18, color: Colors.white70)
            : null,
      ),
    );
  }
}

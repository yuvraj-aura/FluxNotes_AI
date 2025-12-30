import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/features/editor/providers/editor_provider.dart';
import 'package:flux_notes/theme/app_theme.dart';

class EditorToolbar extends ConsumerWidget {
  final String blockId;
  final ContentBlock block;

  const EditorToolbar({
    super.key,
    required this.blockId,
    required this.block,
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
    final currentMeta = _getMetadata();
    final newMeta = {...currentMeta, ...changes};

    // Remove keys with null values to clean up
    newMeta.removeWhere((key, value) => value == null);

    ref.read(noteEditorProvider.notifier).updateBlockMetadata(
          blockId,
          jsonEncode(newMeta),
        );
  }

  void _toggleStyle(WidgetRef ref, String key, bool currentValue) {
    _updateMetadata(ref, {key: !currentValue});
  }

  void _setColor(WidgetRef ref, String key, int? colorValue) {
    _updateMetadata(ref, {key: colorValue});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = _getMetadata();
    final isBold = meta['bold'] == true;
    final isItalic = meta['italic'] == true;
    final isUnderline = meta['underline'] == true;
    final currentColor = meta['color'] as int?;
    final currentBgColor = meta['backgroundColor'] as int?;

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
                onColorSelected: (color) =>
                    _setColor(ref, 'color', color?.value),
              ),
              const SizedBox(width: 8),
              _ColorButton(
                icon: Icons.format_color_fill,
                color: currentBgColor != null
                    ? Color(currentBgColor)
                    : Colors.transparent,
                isBackground: true,
                onColorSelected: (color) =>
                    _setColor(ref, 'backgroundColor', color?.value),
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
                    color: Colors.blueAccent, onSelect: onColorSelected),
                _ColorOption(
                    color: Colors.greenAccent, onSelect: onColorSelected),
                _ColorOption(
                    color: Colors.amberAccent, onSelect: onColorSelected),
                _ColorOption(
                    color: Colors.purpleAccent, onSelect: onColorSelected),
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

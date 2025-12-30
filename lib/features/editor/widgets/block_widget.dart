import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class BlockWidget extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final ContentBlock block;
  final VoidCallback onEnterPressed;
  final VoidCallback onBackspacePressed;
  final ValueChanged<BlockType> onTypeChanged;
  final Function(String? textColor, String? backgroundColor) onStyleChanged;
  final bool isFocused;

  const BlockWidget({
    super.key,
    required this.focusNode,
    required this.controller,
    required this.block,
    required this.onEnterPressed,
    required this.onBackspacePressed,
    required this.onTypeChanged,
    required this.onStyleChanged,
    required this.isFocused,
  });

  @override
  State<BlockWidget> createState() => _BlockWidgetState();
}

class _BlockWidgetState extends State<BlockWidget> {
  // Regex to detect URLs
  final _urlRegex = RegExp(r"(https?:\/\/[^\s]+)");
  String? _detectedUrl;
  bool _showSlashMenu = false;

  @override
  void initState() {
    super.initState();
    // Attach key listener to the focus node
    widget.focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          if (_showSlashMenu) {
            setState(() {
              _showSlashMenu = false;
            });
          }
          widget.onEnterPressed();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.backspace &&
            widget.controller.text.isEmpty) {
          widget.onBackspacePressed();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    widget.controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  @override
  void didUpdateWidget(BlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    _checkForUrl();
    _checkForSlashCommand();
  }

  void _checkForSlashCommand() {
    final text = widget.controller.text;
    if (text.startsWith('/') && widget.isFocused) {
      if (!_showSlashMenu) {
        setState(() {
          _showSlashMenu = true;
        });
      }
    } else {
      if (_showSlashMenu) {
        setState(() {
          _showSlashMenu = false;
        });
      }
    }
  }

  void _checkForUrl() {
    final text = widget.controller.text;
    final match = _urlRegex.firstMatch(text);
    if (match != null) {
      final url = match.group(0);
      if (url != _detectedUrl) {
        setState(() {
          _detectedUrl = url;
        });
      }
    } else {
      if (_detectedUrl != null) {
        setState(() {
          _detectedUrl = null;
        });
      }
    }
  }

  void _selectType(BlockType type) {
    widget.onTypeChanged(type);
    setState(() {
      _showSlashMenu = false;
    });
    widget.controller.clear();
    widget.focusNode.requestFocus();
  }

  void _applyColor(String color, {bool isBackground = false}) {
    widget.onStyleChanged(
      isBackground ? null : color,
      isBackground ? color : null,
    );
    setState(() {
      _showSlashMenu = false;
    });
    widget.controller.clear();
    widget.focusNode.requestFocus();
  }

  TextStyle _getTextStyle() {
    double fontSize = 16;
    FontWeight fontWeight = FontWeight.normal;
    Color color = Colors.white;
    FontStyle fontStyle = FontStyle.normal;
    List<TextDecoration> decorations = [];

    // Parse metadata
    try {
      if (widget.block.metadata != null && widget.block.metadata!.isNotEmpty) {
        final meta = jsonDecode(widget.block.metadata!);
        if (meta['bold'] == true) fontWeight = FontWeight.bold;
        if (meta['italic'] == true) fontStyle = FontStyle.italic;
        if (meta['underline'] == true)
          decorations.add(TextDecoration.underline);
      }
    } catch (_) {}

    if (widget.block.textColor != null) {
      try {
        color = Color(int.parse(widget.block.textColor!));
      } catch (_) {}
    }

    switch (widget.block.type) {
      case BlockType.heading1:
        fontSize = 24;
        if (fontWeight != FontWeight.bold) fontWeight = FontWeight.bold;
        break;
      case BlockType.heading2:
        fontSize = 20;
        if (fontWeight != FontWeight.bold) fontWeight = FontWeight.w600;
        break;
      default:
        fontSize = 16;
        break;
    }

    if (widget.block.type == BlockType.todo && widget.block.isChecked == true) {
      decorations.add(TextDecoration.lineThrough);
    }

    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      decoration:
          decorations.isNotEmpty ? TextDecoration.combine(decorations) : null,
      decorationColor: color,
    );
  }

  Color? _getBackgroundColor() {
    if (widget.block.backgroundColor != null) {
      try {
        return Color(int.parse(widget.block.backgroundColor!));
      } catch (_) {}
    }
    return null;
  }

  List<SlashMenuItem> _getFilteredMenuItems() {
    final text = widget.controller.text;
    if (!text.startsWith('/')) return [];

    final query = text.substring(1).toLowerCase();

    final allItems = [
      SlashMenuItem(
        icon: Icons.title,
        label: 'Heading 1',
        type: BlockType.heading1,
      ),
      SlashMenuItem(
        icon: Icons.title,
        label: 'Heading 2',
        type: BlockType.heading2,
      ),
      SlashMenuItem(
        icon: Icons.text_fields,
        label: 'Text',
        type: BlockType.paragraph,
      ),
      SlashMenuItem(
        icon: Icons.format_list_bulleted,
        label: 'Bullet List',
        type: BlockType.bullet,
        keywords: ['list', 'ul'], // explicit keywords
      ),
      // Colors
      SlashMenuItem(
          icon: Icons.format_paint, label: 'Red', color: '0xFFFF5252'),
      SlashMenuItem(
          icon: Icons.format_paint, label: 'Orange', color: '0xFFFFAB40'),
      SlashMenuItem(
          icon: Icons.format_paint, label: 'Yellow', color: '0xFFFFD740'),
      SlashMenuItem(
          icon: Icons.format_paint, label: 'Green', color: '0xFF69F0AE'),
      SlashMenuItem(
          icon: Icons.format_paint, label: 'Blue', color: '0xFF448AFF'),
      SlashMenuItem(
          icon: Icons.format_paint, label: 'Purple', color: '0xFFE040FB'),
      SlashMenuItem(
          icon: Icons.highlight,
          label: 'Highlight',
          color: '0xFF3E2723',
          isBackground: true),
    ];

    if (query.isEmpty) return allItems;

    return allItems.where((item) {
      if (item.label.toLowerCase().contains(query)) return true;
      if (item.keywords != null) {
        return item.keywords!.any((k) => k.startsWith(query));
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = _getFilteredMenuItems();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle logic...
              if (widget.block.type == BlockType.bullet)
                Padding(
                  padding:
                      const EdgeInsets.only(top: 8.0, right: 8.0, left: 4.0),
                  child: const Icon(Icons.circle, size: 6, color: Colors.white),
                )
              else
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: widget.isFocused ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0, right: 8.0),
                    child: Icon(
                      Icons.drag_indicator,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.4),
                      size: 20,
                    ),
                  ),
                ),

              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: _getTextStyle(),
                  decoration: InputDecoration.collapsed(
                    hintText: widget.block.type == BlockType.heading1
                        ? 'Heading 1'
                        : 'Type "/" for commands',
                    hintStyle: _getTextStyle()
                        .copyWith(color: Colors.grey.withOpacity(0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Slash Command Menu
        if (_showSlashMenu && menuItems.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8, left: 32),
            width: 250,
            constraints:
                const BoxConstraints(maxHeight: 250), // prevent too tall
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: menuItems.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Colors.white10),
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return _buildMenuItem(
                  icon: item.icon,
                  label: item.label,
                  onTap: () {
                    if (item.type != null) {
                      _selectType(item.type!);
                    } else if (item.color != null) {
                      _applyColor(item.color!, isBackground: item.isBackground);
                    }
                  },
                );
              },
            ),
          ),

        if (false && _detectedUrl != null)
          // ... (Url preview existing logic)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 32.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: LinkPreview(
                  enableAnimation: true,
                  onPreviewDataFetched: (data) {},
                  previewData: null,
                  text: _detectedUrl!,
                  width: MediaQuery.of(context).size.width,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.white10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SlashMenuItem {
  final IconData icon;
  final String label;
  final BlockType? type;
  final String? color;
  final bool isBackground;
  final List<String>? keywords;

  SlashMenuItem({
    required this.icon,
    required this.label,
    this.type,
    this.color,
    this.isBackground = false,
    this.keywords,
  });
}

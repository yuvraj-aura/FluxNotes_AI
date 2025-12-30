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
  final bool isFocused;

  const BlockWidget({
    super.key,
    required this.focusNode,
    required this.controller,
    required this.block,
    required this.onEnterPressed,
    required this.onBackspacePressed,
    required this.onTypeChanged,
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
          return KeyEventResult.handled; // Prevent newline in TextField
        } else if (event.logicalKey == LogicalKeyboardKey.backspace &&
            widget.controller.text.isEmpty) {
          widget.onBackspacePressed();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // Listen for text changes
    widget.controller.addListener(_onTextChanged);
    // Initial check
    _onTextChanged();
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
    // Show menu if text is exactly "/"
    final text = widget.controller.text;
    if (text == '/' && widget.isFocused) {
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
    final url = match?.group(0);

    if (url != _detectedUrl) {
      setState(() {
        _detectedUrl = url;
      });
    }
  }

  void _selectType(BlockType type) {
    widget.controller.clear(); // Remove the slash
    widget.onTypeChanged(type);
    setState(() {
      _showSlashMenu = false;
    });
    // Request focus again just in case
    widget.focusNode.requestFocus();
  }

  TextStyle _getTextStyle() {
    TextStyle baseStyle;

    switch (widget.block.type) {
      case BlockType.heading1:
        baseStyle = GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        );
        break;
      case BlockType.heading2:
        baseStyle = GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        );
        break;
      case BlockType.bullet:
        baseStyle = GoogleFonts.inter(fontSize: 16, color: Colors.white);
        break;
      case BlockType.paragraph:
      default:
        baseStyle = GoogleFonts.inter(fontSize: 16, color: Colors.white);
        break;
    }

    // Apply metadata styles
    if (widget.block.metadata != null && widget.block.metadata!.isNotEmpty) {
      try {
        final meta = jsonDecode(widget.block.metadata!) as Map<String, dynamic>;

        if (meta['bold'] == true) {
          baseStyle = baseStyle.copyWith(fontWeight: FontWeight.bold);
        }
        if (meta['italic'] == true) {
          baseStyle = baseStyle.copyWith(fontStyle: FontStyle.italic);
        }
        if (meta['underline'] == true) {
          baseStyle = baseStyle.copyWith(decoration: TextDecoration.underline);
        }
        if (meta['color'] != null) {
          baseStyle = baseStyle.copyWith(color: Color(meta['color'] as int));
        }
        if (meta['backgroundColor'] != null) {
          baseStyle = baseStyle.copyWith(
              backgroundColor: Color(meta['backgroundColor'] as int));
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    return baseStyle;
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.title, color: Colors.white),
                title: const Text('Heading 1',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onTypeChanged(BlockType.heading1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_fields, color: Colors.white),
                title:
                    const Text('Text', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onTypeChanged(BlockType.paragraph);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.format_list_bulleted, color: Colors.white),
                title: const Text('Bullet List',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onTypeChanged(BlockType.bullet);
                },
              ),
              // Add more as needed
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle or Bullet
            if (widget.block.type == BlockType.bullet)
              Padding(
                padding: const EdgeInsets.only(
                    top: 8.0, right: 8.0, left: 4.0), // Adjust for bullet align
                child: GestureDetector(
                  onTap: _showOptionsSheet, // Allow tapping bullet too
                  child: const Icon(Icons.circle, size: 6, color: Colors.white),
                ),
              )
            else
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: widget.isFocused ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 0.0, right: 4.0),
                  child: IconButton(
                    icon: Icon(
                      Icons.drag_indicator,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    onPressed: _showOptionsSheet, // Explicit options button
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ),

            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: _getTextStyle(),
                    decoration: InputDecoration.collapsed(
                      hintText: widget.block.type == BlockType.heading1
                          ? 'Heading 1'
                          : 'Type something... ("/" for commands)',
                      hintStyle: _getTextStyle()
                          .copyWith(color: Colors.grey.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Slash Command Menu
        if (_showSlashMenu)
          Container(
            margin: const EdgeInsets.only(top: 8, left: 32),
            width: 200,
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuItem(
                  icon: Icons.title,
                  label: 'Heading 1',
                  onTap: () => _selectType(BlockType.heading1),
                ),
                _buildMenuItem(
                  icon: Icons.text_fields,
                  label: 'Text',
                  onTap: () => _selectType(BlockType.paragraph),
                ),
                _buildMenuItem(
                  icon: Icons.format_list_bulleted,
                  label: 'Bullet List',
                  onTap: () => _selectType(BlockType.bullet),
                ),
              ],
            ),
          ),

        if (_detectedUrl != null)
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
                  previewData:
                      null, // We handle data internally by the widget for now
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

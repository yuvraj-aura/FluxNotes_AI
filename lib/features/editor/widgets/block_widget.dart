import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_link_previewer/flutter_link_previewer.dart';

class BlockWidget extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final VoidCallback onEnterPressed;
  final VoidCallback onBackspacePressed;
  final bool isFocused;

  const BlockWidget({
    super.key,
    required this.focusNode,
    required this.controller,
    required this.onEnterPressed,
    required this.onBackspacePressed,
    required this.isFocused,
  });

  @override
  State<BlockWidget> createState() => _BlockWidgetState();
}

class _BlockWidgetState extends State<BlockWidget> {
  // Regex to detect URLs
  final _urlRegex = RegExp(r"(https?:\/\/[^\s]+)");
  String? _detectedUrl;

  @override
  void initState() {
    super.initState();
    // Attach key listener to the focus node
    widget.focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
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

    // Listen for URL changes
    widget.controller.addListener(_checkForUrl);
    // Initial check
    _checkForUrl();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkForUrl);
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show a drag handle icon when the block is focused
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
                      ?.withValues(alpha: 0.4),
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
                decoration: const InputDecoration.collapsed(
                  hintText: 'Type something...',
                ),
              ),
            ),
          ],
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
                  // Custom styling if needed, but default is usually fine
                  // We rely on the package to fetch and show data based on 'text'
                ),
              ),
            ),
          ),
      ],
    );
  }
}

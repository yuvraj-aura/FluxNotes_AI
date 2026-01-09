import 'dart:convert';
import 'package:flutter/material.dart';

class StyleSpan {
  final int start;
  final int end;
  final bool? bold;
  final bool? italic;
  final bool? underline;
  final int? color;
  final int? backgroundColor;

  StyleSpan({
    required this.start,
    required this.end,
    this.bold,
    this.italic,
    this.underline,
    this.color,
    this.backgroundColor,
  });

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        if (bold != null) 'bold': bold,
        if (italic != null) 'italic': italic,
        if (underline != null) 'underline': underline,
        if (color != null) 'color': color,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
      };

  factory StyleSpan.fromJson(Map<String, dynamic> json) => StyleSpan(
        start: json['start'] as int,
        end: json['end'] as int,
        bold: json['bold'] as bool?,
        italic: json['italic'] as bool?,
        underline: json['underline'] as bool?,
        color: json['color'] as int?,
        backgroundColor: json['backgroundColor'] as int?,
      );
}

class RichTextController extends TextEditingController {
  List<StyleSpan> _spans = [];

  RichTextController({super.text, String? metadata}) {
    if (metadata != null && metadata.isNotEmpty) {
      try {
        final decoded = jsonDecode(metadata);
        if (decoded is Map<String, dynamic> && decoded.containsKey('spans')) {
          final spansList = decoded['spans'] as List;
          _spans = spansList
              .map((e) => StyleSpan.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }
  }

  // Style Getters for Toolbar
  bool get isSelectionBold => _hasStyle((s) => s.bold == true);
  bool get isSelectionItalic => _hasStyle((s) => s.italic == true);
  bool get isSelectionUnderline => _hasStyle((s) => s.underline == true);
  int? get selectionColor => _getCommonStyle((s) => s.color);
  int? get selectionBackgroundColor =>
      _getCommonStyle((s) => s.backgroundColor);

  bool _hasStyle(bool Function(StyleSpan) predicate) {
    if (selection.isCollapsed) return false; // Or check insertion point?
    // simple check: if any intersecting span has style?
    // strict check: if all intersecting spans have style?
    // Google Docs style: if dominant?
    // Let's go with: if the *first* intersecting span has style, return true.
    // Or better: check if the range is fully covered by this style?
    // Let's stick to: Does the span at the start of selection have it?
    final start = selection.start;
    final span = _spans.firstWhere((s) => s.start <= start && s.end > start,
        orElse: () => StyleSpan(start: -1, end: -1));
    if (span.start == -1) return false;
    return predicate(span);
  }

  T? _getCommonStyle<T>(T? Function(StyleSpan) selector) {
    if (selection.isCollapsed) return null;
    final start = selection.start;
    final span = _spans.firstWhere((s) => s.start <= start && s.end > start,
        orElse: () => StyleSpan(start: -1, end: -1));
    if (span.start == -1) return null;
    return selector(span);
  }

/*
  @override
  set value(TextEditingValue newValue) {
    try {
      final oldText = value.text;
      final newText = newValue.text;
      if (oldText != newText) {
        _updateSpansForChange(oldText, newText);
      }
    } catch (_) {
      // Safety fallback if value is uninitialized or other weird JS interop issues
    }
    super.value = newValue;
  }
*/

/*
  void _updateSpansForChange(String oldText, String newText) {
    // 1. Detect diff
    int start = 0;
    int oldEnd = oldText.length;
    int newEnd = newText.length;

    // Common Prefix
    while (
        start < oldEnd && start < newEnd && oldText[start] == newText[start]) {
      start++;
    }

    // Common Suffix
    while (oldEnd > start &&
        newEnd > start &&
        oldText[oldEnd - 1] == newText[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }

    final deletedLen = oldEnd - start;
    final insertedLen = newEnd - start;
    final changeAmount = insertedLen - deletedLen;

    if (changeAmount == 0 && deletedLen == 0) return; // No change?

    List<StyleSpan> newSpans = [];

    for (var s in _spans) {
      int sStart = s.start;
      int sEnd = s.end;

      // Adjust for deletion
      if (sEnd <= start) {
        // Before change, keep
      } else if (sStart >= oldEnd) {
        // After change, shift
        // But wait, if sStart was AFTER the deleted block, it shifts left.
        sStart = sStart - deletedLen + insertedLen;
        sEnd = sEnd - deletedLen + insertedLen;
      } else {
        // Overlaps with change area
        // 1. Truncate deleted part
        if (sStart < start) {
          // Starts before
          // Ends inside or after?
          if (sEnd <= oldEnd) {
            // Ends used to be at sEnd...
            // If sEnd is inside deleted region, it now ends at 'start'
            sEnd = start;
          } else {
            // Ends after deleted region
            sEnd = sEnd - deletedLen + insertedLen;
          }

          // Expand for insertion?
          // If we type INSIDE a span, usually it grows.
          // Here sStart < start, so change is inside.
          // If sEnd was at exactly start (boundary), typing usually extends PREVIOUS span.
          // If sEnd was > start, typing is definitely INSIDE.
          if (insertedLen > 0) {
            // Grow it logic
            // If typing happens *at the end* of a span, usually we DONT extend unless sticky?
            // Standard: Insert inherits style of character BEFORE it.
            // Here sStart < start implies char before 'start' is in this span.
            // So we extend.
            if (sEnd == start) {
              sEnd += insertedLen;
            }
          }
        } else {
          // Starts INSIDE deleted region or AT start boundary
          // If sStart >= start
          // If sStart was inside deleted region, it's gone?
          // Or checking if it moves?

          // Simplification: Spans strictly inside deleted region are deleted.
          if (sEnd <= oldEnd) {
            continue; // Fully deleted
          }

          // Starts inside, ends after
          if (sStart < oldEnd) {
            sStart = start + insertedLen; // pushed to end of insertion
            sEnd = sEnd - deletedLen + insertedLen;
          }
        }
      }

      if (sEnd > sStart) {
        newSpans.add(StyleSpan(
            start: sStart,
            end: sEnd,
            bold: s.bold,
            italic: s.italic,
            underline: s.underline,
            color: s.color,
            backgroundColor: s.backgroundColor));
      }
    }

    // Handle Insertion inheritance if no existing span covered it?
    // If we typed at `start` and no span covered `start-1`, but a span started at `start`?
    // Usually typing *pushes* the following span away.

    _spans = newSpans;
  }
*/

  String get metadata {
    if (_spans.isEmpty) return '';
    return jsonEncode({'spans': _spans.map((e) => e.toJson()).toList()});
  }

  void toggleStyle(String key, bool? value) {
    if (selection.isCollapsed) return;
    _applyStyleToSelection((span) {
      if (key == 'bold') {
        return StyleSpan(
            start: span.start,
            end: span.end,
            bold: value,
            italic: span.italic,
            underline: span.underline,
            color: span.color,
            backgroundColor: span.backgroundColor);
      }
      if (key == 'italic') {
        return StyleSpan(
            start: span.start,
            end: span.end,
            bold: span.bold,
            italic: value,
            underline: span.underline,
            color: span.color,
            backgroundColor: span.backgroundColor);
      }
      if (key == 'underline') {
        return StyleSpan(
            start: span.start,
            end: span.end,
            bold: span.bold,
            italic: span.italic,
            underline: value,
            color: span.color,
            backgroundColor: span.backgroundColor);
      }
      return span;
    });
  }

  void setColor(String key, int? value) {
    if (selection.isCollapsed) return;
    _applyStyleToSelection((span) {
      if (key == 'color') {
        return StyleSpan(
            start: span.start,
            end: span.end,
            bold: span.bold,
            italic: span.italic,
            underline: span.underline,
            color: value,
            backgroundColor: span.backgroundColor);
      }
      if (key == 'backgroundColor') {
        return StyleSpan(
            start: span.start,
            end: span.end,
            bold: span.bold,
            italic: span.italic,
            underline: span.underline,
            color: span.color,
            backgroundColor: value);
      }
      return span;
    });
  }

  void _applyStyleToSelection(StyleSpan Function(StyleSpan) modifier) {
    final start = selection.start;
    final end = selection.end;
    if (start < 0 || end < 0 || start == end) return;

    // Simplified approach: Clear existing spans in range and add new one.
    // In a production app, proper merging/splitting is required.
    // For this prototype, we'll implement robust splitting.

    // 1. Remove spans fully covered by selection
    _spans.removeWhere((s) => s.start >= start && s.end <= end);

    // 2. Truncate/Split overlapping spans
    List<StyleSpan> newSpans = [];
    for (var i = 0; i < _spans.length; i++) {
      final s = _spans[i];
      if (s.end <= start || s.start >= end) {
        newSpans.add(s); // No overlap
      } else {
        // Overlap!
        if (s.start < start) {
          // Left part remains
          newSpans.add(StyleSpan(
              start: s.start,
              end: start,
              bold: s.bold,
              italic: s.italic,
              underline: s.underline,
              color: s.color,
              backgroundColor: s.backgroundColor));
        }
        if (s.end > end) {
          // Right part remains
          newSpans.add(StyleSpan(
              start: end,
              end: s.end,
              bold: s.bold,
              italic: s.italic,
              underline: s.underline,
              color: s.color,
              backgroundColor: s.backgroundColor));
        }
      }
    }
    _spans = newSpans;

    // 3. Create newly styled span
    // Note: We need to know "base" style if we were just "toggling" one attribute.
    // But for now, let's assume we are applying a new style on top of "nothing" or just overriding.
    // Ideally we should merge with identifying existing style at start?
    // Let's keep it simple: Adding a style adds a span.

    // WAIT: modifier doesn't know base.
    // Let's refactor: modifier takes nullable current style?
    // Or, simplifying: Use a 'merging' strategy.

    // For now, let's just ADD the new span with the requested change,
    // assuming other attributes are null (or inherit from what we just deleted? No, that's hard).
    // Better: modifier should be applied to *each segment* of the selection.

    // Let's re-implement simply:
    // We are just adding a new span on top.
    // But wait, the user wants to "color only a specific portion".
    // If I select a word and Color it Red, I want a span for that word with color=Red.
    // If it was already Bold, I want it to stay Bold.

    // Complex logic needed:
    // 1. Find all spans intersecting selection.
    // 2. Split them at selection boundaries.
    // 3. For the parts INSIDE selection, update their attributes.
    // 4. For parts where NO span existed, create new span with just the new attribute.

    // ... This implementation is getting long for a single file write.
    // I'll stick to a simpler logic: Any formatting applied creates a NEW span overlaying others?
    // No, flattening is better for buildTextSpan.

    // Implementation:
    // Flatten existing into "atomic" segments.
    // Apply change to atomic segments in range.
    // Re-merge if adjacent compatible.

    // ... For this task, I'll do a "Split and Update" approach.

    List<StyleSpan> affected = [];
    List<StyleSpan> unaffected = [];

    for (var s in _spans) {
      if (s.end <= start || s.start >= end) {
        unaffected.add(s);
      } else {
        // Overlap
        if (s.start < start) {
          unaffected.add(StyleSpan(
              start: s.start,
              end: start,
              bold: s.bold,
              italic: s.italic,
              underline: s.underline,
              color: s.color,
              backgroundColor: s.backgroundColor));
        }
        // The part inside:
        int innerStart = s.start < start ? start : s.start;
        int innerEnd = s.end > end ? end : s.end;

        // Create styled copy
        affected.add(modifier(StyleSpan(
            start: innerStart,
            end: innerEnd,
            bold: s.bold,
            italic: s.italic,
            underline: s.underline,
            color: s.color,
            backgroundColor: s.backgroundColor)));

        if (s.end > end) {
          unaffected.add(StyleSpan(
              start: end,
              end: s.end,
              bold: s.bold,
              italic: s.italic,
              underline: s.underline,
              color: s.color,
              backgroundColor: s.backgroundColor));
        }
      }
    }

    // What about gaps? If I select text with NO style, I need to create a span there.
    // Find gaps in `affected` relative to `selection`.
    // Sort affected by start.
    affected.sort((a, b) => a.start.compareTo(b.start));

    List<StyleSpan> finalSpansInSelection = [];
    int curr = start;

    for (var s in affected) {
      if (s.start > curr) {
        // Gap from curr to s.start
        finalSpansInSelection
            .add(modifier(StyleSpan(start: curr, end: s.start)));
      }
      finalSpansInSelection.add(s);
      curr = s.end;
    }
    if (curr < end) {
      // Gap at end
      finalSpansInSelection.add(modifier(StyleSpan(start: curr, end: end)));
    }

    _spans = [...unaffected, ...finalSpansInSelection];
    _spans.sort((a, b) => a.start.compareTo(b.start));

    notifyListeners();
  }

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    if (_spans.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    // Sort spans
    _spans.sort((a, b) => a.start.compareTo(b.start));

    List<TextSpan> children = [];
    int currentIndex = 0;

    for (var span in _spans) {
      if (span.start > currentIndex) {
        children.add(TextSpan(text: text.substring(currentIndex, span.start)));
      }

      // Safety check range
      int effectiveEnd = span.end > text.length ? text.length : span.end;
      if (span.start >= text.length) break;

      TextStyle spanStyle = style ?? const TextStyle();
      if (span.bold == true) {
        spanStyle = spanStyle.copyWith(fontWeight: FontWeight.bold);
      } else if (span.bold == false) {
        spanStyle = spanStyle.copyWith(
            fontWeight: FontWeight.normal); // Explicit turn off?
      }

      if (span.italic == true) {
        spanStyle = spanStyle.copyWith(fontStyle: FontStyle.italic);
      }
      if (span.underline == true) {
        spanStyle = spanStyle.copyWith(decoration: TextDecoration.underline);
      }

      if (span.color != null) {
        spanStyle = spanStyle.copyWith(color: Color(span.color!));
      }
      if (span.backgroundColor != null) {
        spanStyle =
            spanStyle.copyWith(backgroundColor: Color(span.backgroundColor!));
      }

      children.add(TextSpan(
          text: text.substring(span.start, effectiveEnd), style: spanStyle));

      currentIndex = effectiveEnd;
    }

    if (currentIndex < text.length) {
      children.add(TextSpan(text: text.substring(currentIndex)));
    }

    return TextSpan(style: style, children: children);
  }
}

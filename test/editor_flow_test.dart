import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:flux_notes/features/editor/widgets/block_widget.dart';
import 'package:flux_notes/main.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'editor_flow_test.mocks.dart';

@GenerateMocks([NoteRepository])
void main() {
  group('Editor Screen Flow & Visual Logic', () {
    late MockNoteRepository mockNoteRepository;
    late Note testNote;

    // Helper function to find the drag handle opacity for a given block text
    double getDragHandleOpacity(WidgetTester tester, String blockText) {
      // Find the specific BlockWidget that contains the target TextField
      final blockWidgetFinder = find.ancestor(
        of: find.widgetWithText(TextField, blockText),
        matching: find.byType(BlockWidget),
      );

      // Within that BlockWidget, find the drag handle icon
      final iconFinder = find.descendant(
        of: blockWidgetFinder,
        matching: find.byIcon(Icons.drag_indicator),
      );

      // Now find the AnimatedOpacity that is an ancestor of that specific icon
      final opacityFinder =
          find.ancestor(of: iconFinder, matching: find.byType(AnimatedOpacity));

      // Ensure we only found the one we care about
      expect(opacityFinder, findsOneWidget);

      final opacityWidget = tester.widget<AnimatedOpacity>(opacityFinder);
      return opacityWidget.opacity;
    }

    setUp(() {
      mockNoteRepository = MockNoteRepository();
      testNote = Note()
        ..id = 1
        ..uuid = 'test-uuid'
        ..title = 'Test Note'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now()
        ..blocks = [
          ContentBlock(
              id: 'block1', type: BlockType.paragraph, content: 'First block'),
          ContentBlock(
              id: 'block2', type: BlockType.paragraph, content: 'Second block'),
        ];

      when(mockNoteRepository.getAllNotes())
          .thenAnswer((_) => Stream.value([testNote]));
      when(mockNoteRepository.saveNote(any))
          .thenAnswer((_) async => testNote.id);
    });

    Future<void> pumpEditorScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            noteRepositoryProvider.overrideWithValue(mockNoteRepository)
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Note'));
      await tester.pumpAndSettle();
    }

    testWidgets('Drag handle is only visible for the focused block',
        (WidgetTester tester) async {
      await pumpEditorScreen(tester);

      // Initially, no block should be focused, so all handles are invisible
      expect(getDragHandleOpacity(tester, 'First block'), 0.0);
      expect(getDragHandleOpacity(tester, 'Second block'), 0.0);

      // Tap the first block to focus it
      await tester.tap(find.widgetWithText(TextField, 'First block'));
      await tester.pumpAndSettle(); // Let the animation finish

      // Verify first block's handle is visible, second is not
      expect(getDragHandleOpacity(tester, 'First block'), 1.0);
      expect(getDragHandleOpacity(tester, 'Second block'), 0.0);

      // Tap the second block to focus it
      await tester.tap(find.widgetWithText(TextField, 'Second block'));
      await tester.pumpAndSettle();

      // Verify second block's handle is visible, first is not
      expect(getDragHandleOpacity(tester, 'First block'), 0.0);
      expect(getDragHandleOpacity(tester, 'Second block'), 1.0);
    });

    testWidgets(
        'Pressing Enter creates a new block and focuses it, showing its handle',
        (WidgetTester tester) async {
      await pumpEditorScreen(tester);

      // 1. Focus the second block
      await tester.tap(find.widgetWithText(TextField, 'Second block'));
      await tester.pumpAndSettle();

      // Verify initial focus state
      expect(getDragHandleOpacity(tester, 'Second block'), 1.0);

      // 2. Simulate pressing 'Enter'
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // 3. Verify the old block is no longer focused and the new empty block is
      expect(getDragHandleOpacity(tester, 'Second block'), 0.0);
      // The new block is created after the second one, it will be empty.
      expect(getDragHandleOpacity(tester, ''), 1.0);
    });

    testWidgets(
        'Pressing Backspace on empty block deletes it and focuses previous, showing its handle',
        (WidgetTester tester) async {
      testNote.blocks = [
        ContentBlock(
            id: 'block1', type: BlockType.paragraph, content: 'First block'),
        ContentBlock(
            id: 'block2',
            type: BlockType.paragraph,
            content: ''), // Empty block
      ];
      when(mockNoteRepository.getAllNotes())
          .thenAnswer((_) => Stream.value([testNote]));

      await pumpEditorScreen(tester);

      // 1. Tap the empty block to focus it
      await tester.tap(find.widgetWithText(TextField, ''));
      await tester.pumpAndSettle();
      expect(getDragHandleOpacity(tester, ''), 1.0);
      expect(getDragHandleOpacity(tester, 'First block'), 0.0);

      // 2. Simulate pressing 'Backspace'
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      // 3. Verify the empty block is gone and the previous block is focused
      expect(find.widgetWithText(TextField, ''), findsNothing);
      expect(getDragHandleOpacity(tester, 'First block'), 1.0);
    });
  });
}

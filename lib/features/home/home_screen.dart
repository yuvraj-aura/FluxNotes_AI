import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:flux_notes/features/editor/editor_screen.dart';
import 'package:flux_notes/features/search/search_screen.dart';
import 'package:flux_notes/features/settings/settings_screen.dart';
import 'package:flux_notes/features/tags/tags_screen.dart';
import 'package:flux_notes/features/voice/voice_recorder_sheet.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:flux_notes/widgets/custom_bottom_nav.dart';
import 'package:flux_notes/widgets/note_card.dart';
import 'package:flux_notes/widgets/search_bar.dart';
import 'package:google_fonts/google_fonts.dart';

enum SortOrder { updatedNewest, updatedOldest, createdNewest, titleAZ }

final sortOrderProvider =
    StateProvider<SortOrder>((ref) => SortOrder.updatedNewest);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeView(onSearchTap: () {
        setState(() {
          _currentIndex = 1;
        });
      }),
      const SearchScreen(),
      const TagsScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: _currentIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'mic_fab',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => const VoiceRecorderSheet(),
                    );
                  },
                  backgroundColor: const Color(0xFF1F2937),
                  child: const Icon(Icons.mic, color: Colors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton.extended(
                  heroTag: 'add_note_fab',
                  onPressed: () async {
                    final note =
                        await ref.read(noteRepositoryProvider).createNote();
                    await ref.read(noteRepositoryProvider).saveNote(note);

                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditorScreen(
                            noteId: note.id,
                            autofocusTitle: true,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Note'),
                ),
              ],
            )
          : null,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class HomeView extends ConsumerWidget {
  final VoidCallback? onSearchTap;

  const HomeView({super.key, this.onSearchTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Custom Approx AppBar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FluxNotes',
                      style: AppTheme.darkTheme.appBarTheme.titleTextStyle,
                    ),
                  ],
                ),
                // Sort Button acting as a Popup/Dropdown
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppTheme.cardDark,
                    shape: BoxShape.circle,
                  ),
                  child: PopupMenuButton<SortOrder>(
                    icon: const Icon(Icons.sort, color: Colors.white, size: 20),
                    color: AppTheme.cardDark,
                    onSelected: (value) {
                      ref.read(sortOrderProvider.notifier).state = value;
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: SortOrder.updatedNewest,
                        child: Text("Updated: Newest",
                            style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem(
                        value: SortOrder.updatedOldest,
                        child: Text("Updated: Oldest",
                            style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem(
                        value: SortOrder.createdNewest,
                        child: Text("Created: Newest",
                            style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem(
                        value: SortOrder.titleAZ,
                        child: Text("Title: A-Z",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Search Bar
            GestureDetector(
              onTap: onSearchTap,
              child: const CustomSearchBar(),
            ),
            const SizedBox(height: 24),
            // Notes List
            Expanded(
              child: notesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (notes) {
                  if (notes.isEmpty) {
                    return Center(
                      child: Text(
                        'No notes yet. Create one!',
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                    );
                  }
                  final sortOrder = ref.watch(sortOrderProvider);
                  // Create a modifiable copy to sort
                  final sortedNotes = List<Note>.from(notes);

                  switch (sortOrder) {
                    case SortOrder.updatedNewest:
                      sortedNotes
                          .sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                      break;
                    case SortOrder.updatedOldest:
                      sortedNotes
                          .sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
                      break;
                    case SortOrder.createdNewest:
                      sortedNotes
                          .sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      break;
                    case SortOrder.titleAZ:
                      sortedNotes.sort((a, b) => a.title
                          .toLowerCase()
                          .compareTo(b.title.toLowerCase()));
                      break;
                  }

                  return MasonryGridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    itemCount: sortedNotes.length,
                    itemBuilder: (context, index) {
                      final note = sortedNotes[index];
                      return NoteCard(
                        title: note.title.isEmpty ? 'Untitled' : note.title,
                        preview: _buildPreviewText(note),
                        date: '${note.updatedAt.day}/${note.updatedAt.month}',
                        tags: note.tags,
                        hasBlueDot: note.isPinned,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditorScreen(noteId: note.id),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildPreviewText(Note note) {
    if (note.blocks.isEmpty) return 'No content';
    // Get the first few blocks that are text
    final textBlocks = note.blocks
        .where((b) =>
            b.type == BlockType.paragraph ||
            b.type == BlockType.heading1 ||
            b.type == BlockType.heading2 ||
            b.type == BlockType.bullet)
        .take(3);

    if (textBlocks.isEmpty) {
      if (note.blocks.any((b) => b.type == BlockType.image)) {
        return '[Image]';
      }
      return 'No text content';
    }

    return textBlocks.map((b) => b.content).join('\n');
  }
}

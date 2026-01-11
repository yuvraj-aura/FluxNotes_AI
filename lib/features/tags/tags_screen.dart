import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

final tagsSearchQueryProvider = StateProvider<String>((ref) => '');

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(
                  left: 20, right: 20, top: 24, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tags',
                    style: GoogleFonts.inter(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Icon(Icons.search,
                          color: Color(0xFF9AA6BC), size: 24),
                    ),
                    Expanded(
                      child: TextField(
                        enabled: true,
                        onChanged: (val) {
                          ref.read(tagsSearchQueryProvider.notifier).state =
                              val;
                        },
                        decoration: InputDecoration(
                          hintText: 'Search tags...',
                          hintStyle:
                              GoogleFonts.inter(color: const Color(0xFF9AA6BC)),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Divider(
                color: const Color(0xFF333333).withValues(alpha: 0.5),
                height: 1),

            const SizedBox(height: 16),

            // Content
            Expanded(
              child: notesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (notes) {
                  // Aggregate tags
                  final Map<String, int> tagCounts = {};
                  final searchQuery =
                      ref.watch(tagsSearchQueryProvider).toLowerCase();

                  for (final note in notes) {
                    for (final tag in note.tags) {
                      if (searchQuery.isNotEmpty &&
                          !tag.toLowerCase().contains(searchQuery)) {
                        continue;
                      }
                      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
                    }
                  }

                  if (tagCounts.isEmpty) {
                    if (searchQuery.isNotEmpty && notes.isNotEmpty) {
                      return Center(
                        child: Text(
                          'No tags match "$searchQuery"',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      );
                    }
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.label_outline,
                              size: 64, color: Colors.grey[800]),
                          const SizedBox(height: 16),
                          Text(
                            'No tags yet',
                            style: GoogleFonts.inter(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final sortedTags = tagCounts.entries.toList()
                    ..sort((a, b) =>
                        b.value.compareTo(a.value)); // Sort by count desc

                  return AnimationLimiter(
                    child: MasonryGridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: sortedTags.length,
                      itemBuilder: (context, index) {
                        final tagEntry = sortedTags[index];
                        return AnimationConfiguration.staggeredGrid(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          columnCount: 2,
                          child: ScaleAnimation(
                            child: FadeInAnimation(
                              child: _TagCard(
                                tagName: tagEntry.key,
                                count: tagEntry.value,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagCard extends StatelessWidget {
  final String tagName;
  final int count;

  const _TagCard({required this.tagName, required this.count});

  @override
  Widget build(BuildContext context) {
    // Format tag name: remove '##' if present for cleaner display, or keep it?
    // User image shows "##guide", so we keep it as is.
    final displayTag = tagName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayTag,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '$count notes',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/core/services/ai_service.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:flux_notes/features/editor/editor_screen.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _aiResponse;
  bool _isAiLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _askAI(List<Note> allNotes) async {
    setState(() {
      _isAiLoading = true;
      _aiResponse = null;
    });

    try {
      final response = await ref
          .read(aiServiceProvider)
          .chatWithNotes(_searchQuery, allNotes);

      if (mounted) {
        setState(() {
          _isAiLoading = false;
          _aiResponse = response;
        });
      }
    } on NoKeyException catch (e) {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                // Ideally navigate to settings, but since it's a tab, we might need a way to switch tabs.
                // For now just show message or rely on user knowing where Settings is.
                // Or we can create a temporary dialog.
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
          _aiResponse = "Error: $e";
        });
      }
    }
  }

  bool get _isQuestion {
    final q = _searchQuery.trim().toLowerCase();
    return q.isNotEmpty &&
        (q.startsWith('what') ||
            q.startsWith('how') ||
            q.startsWith('why') ||
            q.startsWith('who') ||
            q.startsWith('where') ||
            q.endsWith('?'));
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Bar / Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Search',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            Expanded(
              child: notesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                    child: Text('Error: $err',
                        style: const TextStyle(color: Colors.white))),
                data: (allNotes) {
                  final filteredNotes = _searchQuery.isEmpty
                      ? <Note>[]
                      : allNotes.where((note) {
                          final query = _searchQuery.toLowerCase();
                          final titleMatch =
                              note.title.toLowerCase().contains(query);
                          final contentMatch = note.blocks.any(
                              (b) => b.content.toLowerCase().contains(query));
                          return titleMatch || contentMatch;
                        }).toList();

                  return Column(
                    children: [
                      // Search Input Area
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.cardDark,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.0)),
                          ),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Icon(Icons.search,
                                    color: Colors.grey, size: 24),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value;
                                      if (_aiResponse != null) {
                                        _aiResponse = null;
                                      }
                                    });
                                  },
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search or Ask ("How...", "What...")',
                                    hintStyle:
                                        GoogleFonts.inter(color: Colors.grey),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                  ),
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _aiResponse = null;
                                        });
                                      },
                                      child: const Icon(Icons.close,
                                          color: Colors.grey, size: 22)),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // AI Section
                      if (_isQuestion && _searchQuery.length > 3)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF581C87), Color(0xFF1E3A8A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFA855F7)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.auto_awesome,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Flux Intelligence',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!_isAiLoading && _aiResponse == null)
                                      InkWell(
                                        onTap: () => _askAI(allNotes),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'Ask AI',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (_isAiLoading)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: LinearProgressIndicator(
                                      backgroundColor: Colors.white10,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                if (_aiResponse != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      _aiResponse!,
                                      style: GoogleFonts.inter(
                                        color: Colors.white
                                            .withValues(alpha: 0.95),
                                        height: 1.5,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Results
                      Expanded(
                        child: _searchQuery.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search,
                                        size: 64, color: Colors.grey[800]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Search for your notes',
                                      style:
                                          GoogleFonts.inter(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : filteredNotes.isEmpty
                                ? Center(
                                    child: Text(
                                      'No matching notes found',
                                      style:
                                          GoogleFonts.inter(color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    itemCount: filteredNotes.length,
                                    itemBuilder: (context, index) {
                                      final note = filteredNotes[index];
                                      final contentPreview = note.blocks
                                          .map((b) => b.content)
                                          .join(' ');

                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  EditorScreen(noteId: note.id),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cardDark,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                note.title.isNotEmpty
                                                    ? note.title
                                                    : 'Untitled',
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                contentPreview,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  color: Colors.grey,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
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

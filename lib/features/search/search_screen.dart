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

  // --- AI Interaction ---
  Future<void> _askAI(List<Note> allNotes, [String? query]) async {
    final q = query ?? _searchQuery;
    if (q.isEmpty) return;

    setState(() {
      _searchQuery = q;
      _searchController.text = q;
      _isAiLoading = true;
      _aiResponse = null;
    });

    try {
      final response =
          await ref.read(aiServiceProvider).chatWithNotes(q, allNotes);

      if (mounted) {
        setState(() {
          _isAiLoading = false;
          _aiResponse = response;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
          _aiResponse = "I couldn't process that right now. ($e)";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // Deep Slate Blue
              Color(0xFF000000), // Black
            ],
          ),
        ),
        child: SafeArea(
          child: notesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
                child: Text('Error: $err',
                    style: const TextStyle(color: Colors.white))),
            data: (allNotes) {
              return Stack(
                children: [
                  // 1. Background / Placeholder for Graph
                  if (_searchQuery.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hub,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.1)),
                          const SizedBox(height: 16),
                          Text(
                            "Knowledge Graph Disabled",
                            style: GoogleFonts.inter(color: Colors.white24),
                          ),
                        ],
                      ),
                    ),

                  // 2. "Zero-Query" Suggested Chips
                  if (_searchQuery.isEmpty &&
                      !_isAiLoading &&
                      _aiResponse == null &&
                      allNotes.isNotEmpty)
                    Positioned(
                      top: 100,
                      left: 0,
                      right: 0,
                      child: Center(
                        // Center the chips horizontally
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildGlassChip("Summarize my week",
                                () => _askAI(allNotes, "Summarize my week")),
                            _buildGlassChip(
                                "Project Status?",
                                () => _askAI(allNotes,
                                    "What is the status of my projects?")),
                            _buildGlassChip(
                                "Connect the dots",
                                () => _askAI(allNotes,
                                    "Find unexpected connections between my notes")),
                          ],
                        ),
                      ),
                    ),

                  // 3. Search Results Overlay (Related Memories)
                  // Only show AFTER AI responds, to keep the "thinking" phase clean.
                  if (_searchQuery.isNotEmpty && _aiResponse != null)
                    Positioned.fill(
                      top: 80,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.85),
                        child: _buildSearchResults(allNotes),
                      ),
                    ),

                  // 4. Floating Search Bar
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: _buildGlassSearchBar(allNotes),
                  ),

                  // 5. AI Response Card
                  if (_aiResponse != null || _isAiLoading)
                    Positioned(
                      bottom: 32,
                      left: 16,
                      right: 16,
                      child: _buildAiResponseCard(),
                    )
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildGlassSearchBar(List<Note> allNotes) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15), // Slightly more opaque
        borderRadius: BorderRadius.circular(30),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.bubble_chart, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: "Ask Flux Intelligence...",
                hintStyle: GoogleFonts.inter(color: Colors.white38),
                border: InputBorder.none,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  // Clear AI response if typing new query, but keep text field active
                  if (val.isEmpty) _aiResponse = null;
                });
              },
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  // DIRECT AI TRIGGER
                  _askAI(allNotes, val);
                  // Dismiss keyboard for cleaner UI
                  FocusScope.of(context).unfocus();
                }
              },
            ),
          ),
          // AI Passive Indicator / Trigger
          if (_searchQuery.isNotEmpty && !_isAiLoading)
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
              onPressed: () {
                // Keep as secondary trigger
                _askAI(allNotes, _searchQuery);
                FocusScope.of(context).unfocus();
              },
            ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _aiResponse = null;
                  _isAiLoading = false;
                });
              },
            )
        ],
      ),
    );
  }

  Widget _buildGlassChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1), // No blur
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSearchResults(List<Note> allNotes) {
    if (_isAiLoading) return const SizedBox.expand(); // AI Card handles loading

    final results = allNotes.where((n) {
      final q = _searchQuery.toLowerCase();
      return n.title.toLowerCase().contains(q) ||
          n.blocks.any((b) => b.content.toLowerCase().contains(q));
    }).toList();

    if (results.isEmpty && _aiResponse == null) {
      return Center(
        child: Text("No memories found.",
            style: GoogleFonts.inter(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final note = results[index];
        final preview = note.blocks.map((b) => b.content).join(" ");

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(note.title.isNotEmpty ? note.title : "Untitled",
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => EditorScreen(noteId: note.id)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAiResponseCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: const Color(0xFF3B82F6)
                .withValues(alpha: 0.3)), // Glowing Border
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 4,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: Color(0xFF3B82F6), size: 18),
              const SizedBox(width: 8),
              Text(
                "Flux Intelligence",
                style: GoogleFonts.oswald(
                  // Fallback or use standard if missing
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3B82F6),
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (!_isAiLoading)
                GestureDetector(
                  onTap: () => setState(() => _aiResponse = null),
                  child:
                      const Icon(Icons.close, color: Colors.white38, size: 18),
                )
            ],
          ),
          const SizedBox(height: 16),
          if (_isAiLoading)
            Center(
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    const LinearGradient(colors: [Colors.blue, Colors.purple])
                        .createShader(bounds),
                child: const CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            Text(
              _aiResponse!,
              style: GoogleFonts.sourceCodePro(
                // Typewriter feel
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}

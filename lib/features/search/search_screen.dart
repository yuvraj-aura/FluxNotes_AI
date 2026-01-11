import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/core/services/ai_service.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:flux_notes/features/editor/editor_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mesh_gradient/mesh_gradient.dart'; // Import mesh_gradient

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  // State
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
    final isSearchActive = _searchQuery.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Layer 0: Living Aurora Mesh Background
          SizedBox.expand(
            child: AnimatedMeshGradient(
              colors: const [
                Color(0xFF0F172A), // Deep Slate
                Color(0xFF7C3AED), // Electric Violet
                Color(0xFF06B6D4), // Neon Cyan
                Color(0xFF000000), // Void Black
              ],
              options: AnimatedMeshGradientOptions(
                speed: 2,
                frequency: 3,
                amplitude: 1,
                grain: 0.2,
              ),
            ),
          ),

          // 2. Layer 1: Dimmer Overlay
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: isSearchActive ? 0.7 : 0.0,
            child: Container(color: Colors.black),
          ),

          // 3. Layer 2: Main Content
          SafeArea(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                  child: Text('Error: $err',
                      style: const TextStyle(color: Colors.white))),
              data: (allNotes) {
                return Stack(
                  children: [
                    // A. Center Logo (Inactive State)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      top: isSearchActive
                          ? -200
                          : MediaQuery.of(context).size.height / 2 -
                              100, // Move up and out
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: isSearchActive ? 0.0 : 1.0,
                        child: _buildBreathingLogo(),
                      ),
                    ),

                    // B. Results Container (Active State)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      top: isSearchActive
                          ? 80
                          : MediaQuery.of(context)
                              .size
                              .height, // Slide up from bottom
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 500),
                        opacity: isSearchActive ? 1.0 : 0.0,
                        child: _buildResultsArea(allNotes),
                      ),
                    ),

                    // C. Floating Header (Always visible)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: _buildGlassSearchBar(allNotes, isSearchActive),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildBreathingLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Using a scale animation wrapper would be ideal, but for now simple structure
        // Enhancing with a simple TweenAnimationBuilder for "Breathing"
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 0.95, end: 1.05),
          duration: const Duration(seconds: 4),
          curve: Curves.easeInOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 112, // w-28
                height: 112, // h-28
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  color: Colors.white
                      .withValues(alpha: 0.1), // glass-panel style attempt
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.05),
                      blurRadius: 30,
                      spreadRadius: 10,
                    )
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.blur_on, size: 48, color: Colors.white70),
                ),
              ),
            );
          },
          onEnd:
              () {}, // Infinite loop requires stateful explicit animation, simplified here
        ),
        const SizedBox(height: 24),
        Text(
          "FLUX",
          style: GoogleFonts.inter(
            fontSize: 30,
            fontWeight: FontWeight.w200,
            letterSpacing: 8, // tracking-[0.5em]
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "INTELLIGENCE",
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 4, // tracking-[0.3em]
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassSearchBar(List<Note> allNotes, bool isActive) {
    return Container(
      height: 56, // h-14
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1), // glass-panel bg-white/10
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search,
              color: Colors.white.withValues(alpha: 0.5), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w300),
              decoration: InputDecoration(
                hintText: "Search Flux Intelligence...",
                hintStyle: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.4)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  if (val.isEmpty) _aiResponse = null;
                });
              },
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  _askAI(allNotes, val);
                  FocusScope.of(context).unfocus();
                }
              },
            ),
          ),
          if (isActive)
            IconButton(
              icon: Icon(Icons.close,
                  color: Colors.white.withValues(alpha: 0.5), size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _aiResponse = null;
                });
                FocusScope.of(context).unfocus();
              },
            )
          else
            Icon(Icons.mic,
                color: Colors.white.withValues(alpha: 0.6), size: 20),
        ],
      ),
    );
  }

  Widget _buildResultsArea(List<Note> allNotes) {
    // Combine filtered notes + AI interaction
    // If AI is loading or has response, show that.
    // Else show note results.

    final results = allNotes.where((n) {
      final q = _searchQuery.toLowerCase();
      return n.title.toLowerCase().contains(q) ||
          n.blocks.any((b) => b.content.toLowerCase().contains(q));
    }).toList();

    return Column(
      children: [
        // AI Response Area
        if (_isAiLoading || _aiResponse != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildAiResponseCard(),
          ),

        // Results List
        Expanded(
          child: results.isEmpty && !_isAiLoading && _aiResponse == null
              ? Center(
                  child: Text(
                    "No signals found.",
                    style: GoogleFonts.inter(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final note = results[index];
                    return _buildGlassResultCard(note);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGlassResultCard(Note note) {
    // HTML ref: .glass-panel p-6 rounded-[2rem] active:scale-[0.98]
    // Content: Date/Type label, Title, Preview text
    final preview = note.blocks.map((b) => b.content).join(" ");

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(32), // rounded-[2rem]
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (context) => EditorScreen(noteId: note.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "NOTE • ${note.updatedAt.day}/${note.updatedAt.month}",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5, // tracking-widest
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    Icon(Icons.north_east,
                        size: 18, color: Colors.white.withValues(alpha: 0.3)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  note.title.isNotEmpty ? note.title : "Untitled",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    height: 1.5, // leading-relaxed
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                style: GoogleFonts.inter(
                  fontSize: 12,
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
                child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white70),
            ))
          else
            Text(
              _aiResponse!,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w300,
              ),
            ),
        ],
      ),
    );
  }
}

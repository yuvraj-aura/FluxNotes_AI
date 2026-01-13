import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/core/services/ai_service.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:flux_notes/features/editor/editor_screen.dart';
import 'package:flux_notes/features/search/widgets/reactor_hex_grid.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _iconFloatController;
  late Animation<Offset> _iconFloatAnimation;

  String _searchQuery = '';
  String? _aiResponse;
  bool _isAiLoading = false;

  @override
  void initState() {
    super.initState();
    // Animation for Floating Icon
    _iconFloatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _iconFloatAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -0.1), // Float up slightly
    ).animate(CurvedAnimation(
      parent: _iconFloatController,
      curve: Curves.easeInOutSine,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _iconFloatController.dispose();
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

    // Theme Colors (Hexagon Hive Palette)
    const primaryBlue = Color(0xFF3C3CF6);
    const bgDark = Color(0xFF0B1121);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // 1. Living Reactor Background (Replaces Static HexagonPatternPainter)
          const Positioned.fill(
            child: ReactorHexGrid(
              baseColor: Color(0xFF161B2E),
              activeColor: Colors.white,
            ),
          ),

          // 2. Vignette Overlay (Radial Gradient)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.2, 1.0],
                ),
              ),
            ),
          ),

          // 3. Glowing Dots (Simulated Stars/Nodes)
          const Positioned(
            top: 150,
            left: 80,
            child: GlowingDot(color: primaryBlue, opacity: 0.4),
          ),
          const Positioned(
            top: 300,
            right: 40,
            child: GlowingDot(color: primaryBlue, opacity: 0.3),
          ),
          const Positioned(
            bottom: 200,
            left: 120,
            child: GlowingDot(color: primaryBlue, opacity: 0.2),
          ),
          const Positioned(
            top: 500,
            right: 100,
            child: GlowingDot(color: primaryBlue, opacity: 0.4),
          ),

          // 4. Main Content Layer
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.hub, color: primaryBlue, size: 28),
                      Expanded(
                        child: Text(
                          "Flux Intelligence",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: primaryBlue.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.memory,
                            color: primaryBlue, size: 20),
                      ),
                    ],
                  ),
                ),

                // Expanded Search Area / Content
                Expanded(
                  child: notesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(
                        child: Text('Error: $err',
                            style: const TextStyle(color: Colors.white))),
                    data: (allNotes) {
                      return Stack(
                        children: [
                          // A. Center Branding (Inactive State)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            top: isSearchActive
                                ? -200
                                : MediaQuery.of(context).size.height * 0.15,
                            left: 0,
                            right: 0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 400),
                              opacity: isSearchActive ? 0.0 : 1.0,
                              child: _buildHiveBranding(primaryBlue),
                            ),
                          ),

                          // B. Search Bar Container (Moves up when active)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            top: isSearchActive
                                ? 20
                                : MediaQuery.of(context).size.height * 0.35,
                            left: 24,
                            right: 24,
                            child: Column(
                              children: [
                                _buildGlassSearchBar(
                                    allNotes, isSearchActive, primaryBlue),
                                // System Suggestions (only when inactive)
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 300),
                                  opacity: isSearchActive ? 0.0 : 1.0,
                                  child: isSearchActive
                                      ? const SizedBox.shrink()
                                      : Padding(
                                          padding:
                                              const EdgeInsets.only(top: 32),
                                          child: _buildSystemSuggestions(
                                              allNotes, primaryBlue),
                                        ),
                                ),
                              ],
                            ),
                          ),

                          // C. Results Area (Slides up)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            top: isSearchActive
                                ? 100
                                : MediaQuery.of(context).size.height,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 500),
                              opacity: isSearchActive ? 1.0 : 0.0,
                              child: _buildResultsArea(allNotes, primaryBlue),
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
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildHiveBranding(Color primary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 0,
              )
            ],
          ),
          child: SlideTransition(
              position: _iconFloatAnimation,
              child: Icon(Icons.rocket_launch, color: primary, size: 48)),
        ),
        const SizedBox(height: 16),
        Text(
          "The Hive",
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "FluxNotes AI Engine Active",
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassSearchBar(
      List<Note> allNotes, bool isActive, Color primary) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF282839).withValues(alpha: 0.4), // glass-effect
        borderRadius: BorderRadius.circular(16), // rounded-xl
        border:
            Border.all(color: primary.withValues(alpha: 0.2)), // border color
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Center(
              child:
                  Icon(Icons.search, color: primary, size: 24), // text-primary
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.normal),
              decoration: InputDecoration(
                hintText: "Query the Hive...",
                hintStyle: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.3)),
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
          SizedBox(
            width: 48,
            child: isActive
                ? IconButton(
                    icon: Icon(Icons.close,
                        color: Colors.white.withValues(alpha: 0.4)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _aiResponse = null;
                      });
                      FocusScope.of(context).unfocus();
                    },
                  )
                : Icon(Icons.mic, color: Colors.white.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSuggestions(List<Note> allNotes, Color primary) {
    return Column(
      children: [
        Text(
          "SYSTEM SUGGESTIONS",
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: primary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _buildSuggestionChip("Neural Networks", Icons.bolt, primary,
                () => _askAI(allNotes, "Explain Neural Networks")),
            _buildSuggestionChip("Project Orion", Icons.folder_open, primary,
                () => _askAI(allNotes, "Status of Project Orion")),
            _buildSuggestionChip("Weekly Sync", Icons.schedule, primary,
                () => _askAI(allNotes, "Summarize Weekly Sync")),
            _buildSuggestionChip("Code Snippets", Icons.terminal, primary,
                () => _askAI(allNotes, "Show me recent code snippets")),
          ],
        ),
      ],
    );
  }

  Widget _buildSuggestionChip(
      String label, IconData icon, Color primary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsArea(List<Note> allNotes, Color primary) {
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: _buildAiResponseCard(primary),
          ),

        // Results List
        Expanded(
          child: results.isEmpty && !_isAiLoading && _aiResponse == null
              ? Center(
                  child: Text(
                    "No signals found.",
                    style: GoogleFonts.spaceGrotesk(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final note = results[index];
                    return _buildHiveResultCard(note, primary);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHiveResultCard(Note note, Color primary) {
    final preview = note.blocks.map((b) => b.content).join(" ");

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF282839).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (context) => EditorScreen(noteId: note.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "NOTE NODE",
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    Icon(Icons.north_east,
                        size: 16, color: Colors.white.withValues(alpha: 0.3)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  note.title.isNotEmpty ? note.title : "Untitled",
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiResponseCard(Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF282839).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: primary.withValues(alpha: 0.3)), // Glowing Primary Border
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: primary, size: 18),
              const SizedBox(width: 8),
              Text(
                "HIVE MIND",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primary,
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
                      strokeWidth: 2, color: primary)),
            )
          else
            Text(
              _aiResponse!,
              style: GoogleFonts.spaceGrotesk(
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

class GlowingDot extends StatelessWidget {
  final Color color;
  final double opacity;

  const GlowingDot({super.key, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity),
            blurRadius: 15, // glow-dot: 0 0 15px 2px
            spreadRadius: 2,
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/core/services/ai_service.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

class VoiceRecorderSheet extends ConsumerStatefulWidget {
  const VoiceRecorderSheet({super.key});

  @override
  ConsumerState<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends ConsumerState<VoiceRecorderSheet>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _lastWords = '';
  bool _isProcessing = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    await _speechToText.initialize();
  }

  Future<void> _startListening() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;

    await _speechToText.listen(onResult: (result) {
      setState(() {
        _lastWords = result.recognizedWords;
      });
    });
    setState(() {
      _isListening = true;
      _lastWords = '';
    });
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });

    if (_lastWords.isNotEmpty) {
      _processThought(_lastWords);
    }
  }

  Future<void> _processThought(String text) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
    });

    final aiService = ref.read(aiServiceProvider);

    try {
      final classification = await aiService.classifyThought(text);
      // NOTE: classifyThought might return default note if key is missing depending on implementation,
      // but if we updated it to throw or we want to be explicit, we assume it works or throws.
      // However, current implementation of classifyThought in previous step catches internally and returns default.
      // Let's re-verify ai_service.dart.
      // Looking at step 347, classifyThought does NOT throw, it returns default {'type': 'note'}.
      // So no exception handling needed here strictly, BUT if we changed it to throw we would need it.
      // Wait, step 347 shows:
      // try { final apiKey = await _getApiKey(); ... } catch(e) { return {'type': 'note'...} }
      // So it catches NoKeyException inside _getApiKey call implicitly via catch(e).
      // If _getApiKey throws NoKeyException, the catch block in classifyThought returns the default note.
      // So the voice recorder will just work as a standard note recorder if no key is present.
      // This is acceptable behavior (graceful degradation).

      _createNoteFromClassification(classification, text);
    } catch (e) {
      // Fallback
      _createNoteFromClassification({'type': 'note', 'content': text}, text);
    }
  }

  Future<void> _createNoteFromClassification(
      Map<String, dynamic> classification, String originalText) async {
    final type = classification['type'] as String? ?? 'note';
    final content = classification['content'] as String? ?? originalText;

    // Create Note
    final noteRepo = ref.read(noteRepositoryProvider);
    final newNote = await noteRepo.createNote();

    // We update the content based on type
    if (type == 'task') {
      newNote.title = 'New Task';
      newNote.blocks = [
        ContentBlock()
          ..id = const Uuid().v4()
          ..type = BlockType.todo
          ..content = content
          ..isChecked = false
      ];
      newNote.tags = ['task'];
    } else {
      newNote.title = 'Thought Note';
      newNote.blocks = [
        ContentBlock()
          ..id = const Uuid().v4()
          ..type = BlockType.paragraph
          ..content = content
      ];
    }

    await noteRepo.saveNote(newNote);

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isProcessing
                ? 'Analyzing Thought...'
                : (_isListening ? 'Listening...' : 'Hold to Record'),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_lastWords.isNotEmpty && !_isProcessing)
            Text(
              _lastWords,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
            ),
          const SizedBox(height: 32),
          GestureDetector(
            onLongPressStart: (_) => _startListening(),
            onLongPressEnd: (_) => _stopListening(),
            // Fallback tap for simulator testing if needed, though long press is desired
            // onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.redAccent
                        : const Color(0xFF3B82F6),
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                              blurRadius:
                                  10 + (_animationController.value * 20),
                              spreadRadius:
                                  2 + (_animationController.value * 10),
                            )
                          ]
                        : [],
                  ),
                  child: Icon(
                    _isProcessing ? Icons.hourglass_empty : Icons.mic,
                    color: Colors.white,
                    size: 32,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Flux AI will auto-classify tasks & notes',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/core/providers/font_scale_provider.dart';
import 'package:flux_notes/core/services/ai_service.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:flux_notes/features/settings/providers/ai_settings_provider.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:flux_notes/widgets/settings_tile.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // State for AI Section
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;
  bool _isVerifying = false;
  bool? _isKeyValid;

  @override
  void initState() {
    super.initState();
    // Sync controller with provider once loaded
    final settings = ref.read(aiSettingsProvider).value;
    if (settings != null) {
      _apiKeyController.text = settings.apiKey;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _verifyKey(String key) async {
    if (!mounted) return;
    setState(() {
      _isVerifying = true;
      _isKeyValid = null;
    });

    bool isValid = false;
    try {
      isValid = await ref.read(aiServiceProvider).validateKey(key);
    } catch (e) {
      debugPrint('Verification error: $e');
    }

    if (mounted) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _isKeyValid = isValid;
        });

        if (isValid) {
          // Save automatically if valid
          try {
            ref.read(aiSettingsProvider.notifier).setApiKey(key);
          } catch (_) {}
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch AI Settings
    final settingsAsync = ref.watch(aiSettingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'Settings',
                    style: AppTheme.darkTheme.appBarTheme.titleTextStyle,
                  ),
                  const SizedBox(height: 30),

                  // SECTION 1: Intelligence & Model
                  _buildSectionHeader('INTELLIGENCE & MODEL'),
                  const SizedBox(height: 12),
                  settingsAsync.when(
                    data: (settings) => _buildIntelligenceSection(settings),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Text('Error loading settings: $e'),
                  ),
                  const SizedBox(height: 30),

                  // SECTION 2: Data Vault
                  _buildSectionHeader('DATA VAULT'),
                  const SizedBox(height: 12),
                  _buildDataVaultSection(),
                  const SizedBox(height: 30),

                  // SECTION 3: Appearance & App
                  _buildSectionHeader('APPEARANCE & APP'),
                  const SizedBox(height: 12),
                  _buildAppearanceSection(),
                  const SizedBox(height: 40),

                  // Footer
                  _buildFooter(),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }

  // --- SECTIONS ---

  Widget _buildIntelligenceSection(AISettings settings) {
    // Keep controller in sync if needed (though we mostly rely on user typing)
    if (_apiKeyController.text.isEmpty && settings.apiKey.isNotEmpty) {
      _apiKeyController.text = settings.apiKey;
    }

    return _buildCard([
      // API Key Field
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.key, color: Color(0xFFA855F7), size: 20),
                const SizedBox(width: 12),
                Text(
                  'Gemini API Key',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_isVerifying)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_isKeyValid == true)
                  const Icon(Icons.check_circle,
                      color: Colors.greenAccent, size: 20)
                else if (_isKeyValid == false)
                  const Icon(Icons.error, color: Colors.redAccent, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Paste your API key',
                      hintStyle: TextStyle(color: Colors.grey.shade700),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureApiKey = !_obscureApiKey;
                          });
                        },
                      ),
                    ),
                    onChanged: (val) {
                      // Reset validation state on type
                      if (_isKeyValid != null) {
                        setState(() => _isKeyValid = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _apiKeyController.text.isNotEmpty
                      ? () => _verifyKey(_apiKeyController.text)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    backgroundColor:
                        AppTheme.primaryBlue.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: const Text("Verify"),
                ),
              ],
            ),
            if (_isKeyValid == false)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Auth Error: Please check your key or quota limits.",
                  style:
                      GoogleFonts.inter(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            // Hint for invalid format
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _apiKeyController,
              builder: (context, value, child) {
                if (value.text.isNotEmpty && !value.text.startsWith('AIza')) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "Tip: Google AI keys usually start with 'AIza'",
                      style: GoogleFonts.inter(
                          color: Colors.orangeAccent, fontSize: 11),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://aistudio.google.com/app/apikey');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
              child: Text(
                'Get a free key from Google AI Studio',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),

      // Model Selector
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.psychology, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Model',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Choose your intelligence',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: [
                  'gemini-3-flash-preview',
                  'gemini-3-pro-preview',
                  'gemini-2.5-flash',
                  'gemini-2.5-pro',
                ].contains(settings.modelId)
                    ? settings.modelId
                    : 'gemini-3-flash-preview',
                dropdownColor: AppTheme.cardDark,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                isExpanded: false,
                items: const [
                  DropdownMenuItem(
                    value: 'gemini-3-flash-preview',
                    child: Text('Gemini 3.0 Flash (Latest & Fast)'),
                  ),
                  DropdownMenuItem(
                    value: 'gemini-3-pro-preview',
                    child: Text('Gemini 3.0 Pro (Most Intelligent)'),
                  ),
                  DropdownMenuItem(
                    value: 'gemini-2.5-flash',
                    child: Text('Gemini 2.5 Flash (Stable)'),
                  ),
                  DropdownMenuItem(
                    value: 'gemini-2.5-pro',
                    child: Text('Gemini 2.5 Pro (Reasoning)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(aiSettingsProvider.notifier).setModel(val);
                  }
                },
              ),
            ),
          ],
        ),
      ),
      Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),

      // Creativity Slider
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Creativity',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(settings.temperature * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppTheme.primaryBlue,
                inactiveTrackColor: Colors.white10,
                thumbColor: Colors.white,
                overlayColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: settings.temperature,
                min: 0.0,
                max: 1.0,
                onChanged: (val) {
                  ref.read(aiSettingsProvider.notifier).setTemperature(val);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Precise',
                      style:
                          GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                  Text('Balanced',
                      style:
                          GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                  Text('Creative',
                      style:
                          GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildDataVaultSection() {
    return _buildCard([
      SettingsTile(
        icon: Icons.download,
        title: 'Export Backup',
        subtitle: 'Save your brain as JSON',
        iconColor: Colors.greenAccent,
        iconBackground: Colors.greenAccent.withValues(alpha: 0.1),
        onTap: _exportBackup,
      ),
      Divider(
          height: 1, color: Colors.white.withValues(alpha: 0.1), indent: 56),
      SettingsTile(
        icon: Icons.upload,
        title: 'Restore Backup',
        subtitle: 'Bring memories back',
        iconColor: Colors.blueAccent,
        iconBackground: Colors.blueAccent.withValues(alpha: 0.1),
        onTap: _restoreBackup,
      ),
      Divider(
          height: 1, color: Colors.white.withValues(alpha: 0.1), indent: 56),
      SettingsTile(
        icon: Icons.delete_forever,
        title: 'Delete All Data',
        subtitle: 'This cannot be undone',
        iconColor: Colors.redAccent,
        iconBackground: Colors.redAccent.withValues(alpha: 0.1),
        showChevron: false,
        onTap: _deleteAllData,
      ),
    ]);
  }

  Widget _buildAppearanceSection() {
    return _buildCard([
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.text_fields, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Font Size',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer(builder: (context, ref, _) {
              final fontScale = ref.watch(fontScaleProvider);
              return SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.85, label: Text('Small')),
                  ButtonSegment(value: 1.0, label: Text('Normal')),
                  ButtonSegment(value: 1.15, label: Text('Large')),
                ],
                selected: {fontScale},
                onSelectionChanged: (newSelection) {
                  ref
                      .read(fontScaleProvider.notifier)
                      .setScale(newSelection.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.primaryBlue;
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    return Colors.white;
                  }),
                  side: WidgetStateProperty.all(
                      const BorderSide(color: Colors.white24)),
                ),
              );
            }),
          ],
        ),
      ),
    ]);
  }

  // --- LOGIC ---

  Future<void> _exportBackup() async {
    try {
      final notes = await ref.read(noteRepositoryProvider).getAllNotesList();
      final jsonList = notes.map((n) => _noteToJson(n)).toList();
      final jsonString = jsonEncode(jsonList);

      final fileName =
          'flux_backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';

      if (kIsWeb) {
        // Web Export: Trigger download via AnchorElement
        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Backup downloaded!'),
                backgroundColor: Colors.green),
          );
        }
        return;
      }

      // Mobile/Desktop Export
      String? outputPath;
      // Note: saveFile is not supported on Web/Mobile in some versions of file_picker,
      // but works on Desktop. For Mobile we might need getDirectoryPath.
      // However, per prompt requirements we try saveFile first.
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Backup',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
      } else {
        // Fallback for Mobile (Android/iOS) where saveFile might be limited
        // or just rely on Share feature? For now, we'll try picking a directory.
        final dir = await FilePicker.platform.getDirectoryPath();
        if (dir != null) {
          outputPath = '$dir/$fileName';
        }
      }

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsString(jsonString);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Backup saved successfully!'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        // User canceled
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final notes = jsonList.map((j) => _noteFromJson(j)).toList();

        await ref.read(noteRepositoryProvider).saveNotes(notes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Restored ${notes.length} notes!'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAllData() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Delete Everything?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will wipe all notes and tags permanently. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
              await ref.read(noteRepositoryProvider).deleteAllNotes();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('All data deleted.'),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Delete All',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // --- SERIALIZATION HELPERS ---

  Map<String, dynamic> _noteToJson(Note note) {
    return {
      'uuid': note.uuid,
      'title': note.title,
      'titleMetadata': note.titleMetadata,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
      'tags': note.tags,
      'isPinned': note.isPinned,
      'summary': note.summary,
      'blocks': note.blocks.map((b) => _blockToJson(b)).toList(),
      // 'id' is local Isar ID, usually skip for import/export unless preserving exact DB state.
      // We rely on UUID for logical identity.
    };
  }

  Note _noteFromJson(dynamic json) {
    final note = Note()
      ..uuid = json['uuid']
      ..title = json['title']
      ..titleMetadata = json['titleMetadata']
      ..createdAt = DateTime.parse(json['createdAt'])
      ..updatedAt = DateTime.parse(json['updatedAt'])
      ..tags = List<String>.from(json['tags'] ?? [])
      ..isPinned = json['isPinned'] ?? false
      ..summary = json['summary']
      ..blocks =
          (json['blocks'] as List).map((b) => _blockFromJson(b)).toList();
    return note;
  }

  Map<String, dynamic> _blockToJson(ContentBlock block) {
    return {
      'id': block.id,
      'type': block.type.name,
      'content': block.content,
      'isChecked': block.isChecked,
      'metadata': block.metadata,
      'textColor': block.textColor,
      'backgroundColor': block.backgroundColor,
    };
  }

  ContentBlock _blockFromJson(dynamic json) {
    return ContentBlock(
      id: json['id'],
      type: BlockType.values.firstWhere((e) => e.name == json['type'],
          orElse: () => BlockType.paragraph),
      content: json['content'],
      isChecked: json['isChecked'],
      metadata: json['metadata'],
      textColor: json['textColor'],
      backgroundColor: json['backgroundColor'],
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.bolt,
              color: Colors.white.withValues(alpha: 0.2), size: 32),
          const SizedBox(height: 12),
          Text(
            'FluxNotes v1.0.0',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Text(
            'Local-First & AI-Powered',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

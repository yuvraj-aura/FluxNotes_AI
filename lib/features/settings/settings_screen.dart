import 'package:flutter/material.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:flux_notes/widgets/settings_tile.dart';
import 'package:flux_notes/widgets/theme_selector.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),
            Text(
              'Settings',
              style: AppTheme.darkTheme.appBarTheme.titleTextStyle,
            ),
            const SizedBox(height: 30),
            _buildSectionHeader('APPEARANCE'),
            const SizedBox(height: 12),
            const ThemeSelector(),
            const SizedBox(height: 8),
            Text(
              'Choose a theme or let the system decide.',
              style: GoogleFonts.inter(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 30),
            _buildSectionHeader('GENERAL'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.person,
                    title: 'Account',
                    subtitle: 'Manage subscription & profile',
                    iconColor: const Color(0xFF3B82F6),
                    iconBackground:
                        const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                    onTap: () {},
                  ),
                  Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                      indent: 70),
                  SettingsTile(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    subtitle: 'Reminders & updates',
                    iconColor: const Color(0xFFF59E0B),
                    iconBackground:
                        const Color(0xFF78350F).withValues(alpha: 0.3),
                    onTap: () {},
                  ),
                  Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                      indent: 70),
                  SettingsTile(
                    icon: Icons.lock,
                    title: 'Security',
                    subtitle: 'FaceID & Passcode',
                    iconColor: const Color(0xFF10B981),
                    iconBackground:
                        const Color(0xFF064E3B).withValues(alpha: 0.3),
                    onTap: () {},
                  ),
                  Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                      indent: 70),
                  SettingsTile(
                    icon: Icons.psychology,
                    title: 'Brain Connection',
                    subtitle: 'Gemini AI Configuration',
                    iconColor: const Color(0xFFA855F7),
                    iconBackground:
                        const Color(0xFF581C87).withValues(alpha: 0.3),
                    onTap: () => _showApiKeyDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildSectionHeader('INFO'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SettingsTile(
                icon: Icons.info_outline,
                title: 'About FluxNotes',
                subtitle: 'Version 1.0.2',
                iconColor: Colors.white,
                iconBackground: Colors.white.withValues(alpha: 0.1),
                showChevron: true,
                onTap: () {},
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 60),
            Center(
              child: Column(
                children: [
                  Icon(Icons.description,
                      color: Colors.white.withValues(alpha: 0.3), size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'FluxNotes for iOS',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    'Made with precision',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
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
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final controller = TextEditingController(
      text: prefs.getString('gemini_api_key') ?? '',
    );
    String? errorText;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          title: Text(
            'Gemini API Key',
            style: AppTheme.darkTheme.textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your Gemini API key to enable AI features.',
                style: AppTheme.darkTheme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Paste API Key here',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryBlue),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (_) {
                  if (errorText != null) {
                    setState(() => errorText = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final url =
                      Uri.parse('https://aistudio.google.com/app/apikey');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Get a Free Gemini Key',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryBlue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final key = controller.text.trim();
                if (key.isEmpty) {
                  setState(() => errorText = "Required for AI features");
                  return;
                }
                await prefs.setString('gemini_api_key', key);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

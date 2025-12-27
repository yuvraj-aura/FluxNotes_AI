import 'package:flutter/material.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/core/providers/theme_provider.dart';

class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildOption(context, ref, Icons.settings_brightness, 'System',
              ThemeMode.system, currentTheme),
          _buildOption(context, ref, Icons.light_mode, 'Light', ThemeMode.light,
              currentTheme),
          _buildOption(context, ref, Icons.dark_mode, 'Dark', ThemeMode.dark,
              currentTheme),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, WidgetRef ref, IconData icon,
      String label, ThemeMode mode, ThemeMode currentMode) {
    final isSelected = mode == currentMode;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
        ),
        child: InkWell(
          onTap: () {
            ref.read(themeProvider.notifier).state = mode;
          },
          borderRadius: BorderRadius.circular(21),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

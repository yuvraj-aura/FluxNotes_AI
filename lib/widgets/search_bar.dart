import 'package:flutter/material.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomSearchBar extends StatelessWidget {
  const CustomSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        decoration: InputDecoration(
          icon: const Icon(Icons.search, color: Colors.grey),
          hintText: 'Search notes, tags...',
          hintStyle: GoogleFonts.inter(color: Colors.grey),
          border: InputBorder.none,
        ),
        style: GoogleFonts.inter(color: Colors.white),
      ),
    );
  }
}

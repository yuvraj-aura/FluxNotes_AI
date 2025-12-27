import 'package:flutter/material.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                      fontSize: 30, // 3xl in tailwind approx
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
                  borderRadius: BorderRadius.circular(30), // rounded-full
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Icon(Icons.search,
                          color: Color(0xFF9AA6BC), size: 24), // text-secondary
                    ),
                    Expanded(
                      child: TextField(
                        enabled: false, // Disabled for now since no tags
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

            // Empty State
            Expanded(
              child: Center(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

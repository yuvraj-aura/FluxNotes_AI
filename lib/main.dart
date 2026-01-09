import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/features/home/home_screen.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:flux_notes/core/services/notification_service.dart';
import 'package:flux_notes/core/providers/theme_provider.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flux_notes/data/models/note_model.dart';

import 'package:flux_notes/core/providers/font_scale_provider.dart';

void main() async {
  // 1. Initialize Bindings (REQUIRED)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. CRITICAL FIX: Tell the Splash Screen to go away IMMEDIATELY.
  try {
    FlutterNativeSplash.remove();
  } catch (e) {
    // Ignore errors if it's already removed
  }

  // 3. Initialize Database (Safe Mode)
  try {
    final dirPath =
        kIsWeb ? '' : (await getApplicationDocumentsDirectory()).path;

    // Check if Isar is already open to prevent errors
    // CRITICAL: Do NOT open Isar on Web in this version
    if (!kIsWeb && Isar.instanceNames.isEmpty) {
      await Isar.open(
        [NoteSchema],
        directory: dirPath,
        inspector: false,
      );
    }
  } catch (e) {
    debugPrint("DATABASE ERROR: $e");
    // Even if database fails, we continue to runApp so the screen turns on
  }

  // Preserve previous logic: Initialize Daily Briefing
  try {
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.scheduleDailyBriefing();
  } catch (e) {
    debugPrint("Notification Init Error: $e");
  }

  // Preserve previous logic: Seed Demo Note
  try {
    final container = ProviderContainer();
    final noteRepository = container.read(noteRepositoryProvider);
    // NoteRepository checks if DB is open, so this is safe
    await noteRepository.checkAndSeedDemoNote();
    container.dispose();
  } catch (e) {
    debugPrint("Seeding Error: $e");
  }

  // 4. Run the App
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return MaterialApp(
      title: 'FluxNotes',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}

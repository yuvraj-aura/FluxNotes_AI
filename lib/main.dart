import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/features/home/home_screen.dart';
import 'package:flux_notes/theme/app_theme.dart';
import 'package:flux_notes/core/services/notification_service.dart';
import 'package:flux_notes/core/providers/theme_provider.dart';
import 'package:flux_notes/data/repositories/note_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Daily Briefing
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.scheduleDailyBriefing();

  // Seed Demo Note
  final container = ProviderContainer();
  final noteRepository = container.read(noteRepositoryProvider);
  await noteRepository.checkAndSeedDemoNote();
  container.dispose();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'FluxNotes',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

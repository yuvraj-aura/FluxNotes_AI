import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/data/models/note_model.dart';
import 'package:flux_notes/features/settings/providers/ai_settings_provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class NoKeyException implements Exception {
  final String message =
      "Please set your Gemini API Key in Settings to use AI features.";
  @override
  String toString() => message;
}

class AIService {
  final Ref ref;

  AIService(this.ref);

  Future<String> _getApiKey() async {
    final settings = ref.read(aiSettingsProvider).value;
    final key = settings?.apiKey;
    if (key == null || key.isEmpty) {
      throw NoKeyException();
    }
    return key;
  }

  Future<bool> validateKey(String apiKey) async {
    if (apiKey.isEmpty) return false;

    // List of models to try for verification (newest to oldest)
    final modelsToTry = [
      'gemini-3-flash-preview',
      'gemini-3-pro-preview',
      'gemini-2.5-flash',
      'gemini-2.5-pro',
    ];

    debugPrint(
        '[AIService-v2] Validating key: ${apiKey.substring(0, min(5, apiKey.length))}...');

    for (final modelId in modelsToTry) {
      try {
        debugPrint('[AIService] Attempting with model: $modelId');
        final model = GenerativeModel(model: modelId, apiKey: apiKey);
        final response = await model.generateContent([Content.text('Test')]);

        if (response.text != null) {
          debugPrint('[AIService] Validation success with $modelId');
          return true;
        }
      } catch (e) {
        debugPrint('[AIService] Failed with $modelId: $e');
        // Continue to next model
      }
    }

    debugPrint('[AIService] All models failed validation.');
    return false;
  }

  GenerativeModel _getModel(String apiKey) {
    final settings = ref.read(aiSettingsProvider).value;
    final modelId = settings?.modelId ?? 'gemini-3-flash-preview';
    // Ensure temperature is within valid range (0.0 - 1.0) generally, though Gemini supports up to 2.0 sometimes
    // confining to 0-1 for safety/UI match.
    final temp = settings?.temperature ?? 0.5;

    return GenerativeModel(
      model: modelId,
      apiKey: apiKey,
      generationConfig: GenerationConfig(temperature: temp),
    );
  }

  Future<List<String>> generateTags(String noteContent) async {
    try {
      final apiKey = await _getApiKey();
      final model = _getModel(apiKey);
      final prompt =
          'Analyze this note: "$noteContent". Return a list of 3-5 relevant hashtags in JSON format. Example: ["#work", "#urgent"]. Return ONLY the JSON array.';
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        final cleanedText = response.text!
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final List<dynamic> tags = jsonDecode(cleanedText);
        return tags.map((e) => e.toString()).toList();
      }
    } on NoKeyException {
      rethrow;
    } catch (e) {
      // Fail silently for tags
    }
    return [];
  }

  Future<String> chatWithNotes(String userQuestion, List<Note> allNotes) async {
    // Web Mock: Return dummy response to prevent freezing/NoKeyException
    final apiKey = await _getApiKey(); // Will throw if missing
    debugPrint(
        '[AIService] chatWithNotes using key: ${apiKey.substring(0, min(5, apiKey.length))}...');

    try {
      final model = _getModel(apiKey);

      final StringBuffer contextBuffer = StringBuffer();
      contextBuffer.writeln(
          "System: You are a helpful second brain. Here is my entire knowledge base:");

      for (var note in allNotes) {
        contextBuffer.writeln("---");
        contextBuffer.writeln("Note ID: ${note.id}");
        contextBuffer.writeln("Title: ${note.title}");
        final content = note.blocks.map((b) => b.content).join('\n');
        contextBuffer.writeln("Content: $content");
        contextBuffer.writeln("---");
      }

      contextBuffer.writeln("User Question: '$userQuestion'");
      contextBuffer.writeln(
          "Answer strictly based on the notes provided. Cite the Note ID in your answer using format [Note ID]. If the answer is not in the notes, state that you don't know.");

      final content = [Content.text(contextBuffer.toString())];
      final response = await model.generateContent(content);

      return response.text ?? "I couldn't generate a response.";
    } catch (e) {
      if (e is NoKeyException) rethrow; // Should be caught by _getApiKey anyway
      return "Error communicating with AI: $e";
    }
  }

  Future<Map<String, dynamic>> classifyThought(String text) async {
    try {
      final apiKey = await _getApiKey();
      final model = _getModel(apiKey);
      final prompt =
          'Analyze this text: "$text". Is it a "task" (something to do) or a "note" (an idea/info)? Return JSON ONLY: {"type": "task" or "note", "content": "cleaned text (fix grammar/formatting)"}';
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        final cleanedText = response.text!
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        return jsonDecode(cleanedText);
      }
    } catch (e) {
      // Return default if error or no key
    }
    return {'type': 'note', 'content': text};
  }
}

final aiServiceProvider = Provider<AIService>((ref) => AIService(ref));

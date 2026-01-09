import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AISettings {
  final String apiKey;
  final String modelId;
  final double temperature;

  const AISettings({
    this.apiKey = '',
    this.modelId = 'gemini-3-flash-preview',
    this.temperature = 0.5,
  });

  AISettings copyWith({
    String? apiKey,
    String? modelId,
    double? temperature,
  }) {
    return AISettings(
      apiKey: apiKey ?? this.apiKey,
      modelId: modelId ?? this.modelId,
      temperature: temperature ?? this.temperature,
    );
  }
}

class AISettingsNotifier extends StateNotifier<AsyncValue<AISettings>> {
  AISettingsNotifier() : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('gemini_api_key') ?? '';
      final modelId = prefs.getString('ai_model') ?? 'gemini-3-flash-preview';
      final temperature = prefs.getDouble('ai_creativity') ?? 0.5;

      state = AsyncValue.data(AISettings(
        apiKey: apiKey,
        modelId: modelId,
        temperature: temperature,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    if (state.hasValue) {
      state = AsyncValue.data(state.value!.copyWith(apiKey: key));
    }
  }

  Future<void> setModel(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_model', modelId);
    if (state.hasValue) {
      state = AsyncValue.data(state.value!.copyWith(modelId: modelId));
    }
  }

  Future<void> setTemperature(double temp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ai_creativity', temp);
    if (state.hasValue) {
      state = AsyncValue.data(state.value!.copyWith(temperature: temp));
    }
  }
}

final aiSettingsProvider =
    StateNotifierProvider<AISettingsNotifier, AsyncValue<AISettings>>((ref) {
  return AISettingsNotifier();
});

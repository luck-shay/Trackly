import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

enum AIValidationFailureReason {
  missingApiKey,
  invalidImage,
  quotaOrRateLimited,
  unavailableModel,
  networkError,
  rejectedByModel,
  unknown,
}

class AIValidationResult {
  final bool approved;
  final String userMessage;
  final AIValidationFailureReason? failureReason;

  const AIValidationResult._({
    required this.approved,
    required this.userMessage,
    this.failureReason,
  });

  const AIValidationResult.approved()
      : this._(approved: true, userMessage: 'Validation passed.');

  const AIValidationResult.rejected({
    required String userMessage,
    required AIValidationFailureReason reason,
  }) : this._(
         approved: false,
         userMessage: userMessage,
         failureReason: reason,
       );
}

class AIService {
  static const String _primaryApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String _secondaryApiKey = String.fromEnvironment(
    'GOOGLE_API_KEY',
    defaultValue: '',
  );

  static const String _tertiaryApiKey = String.fromEnvironment(
    'GENAI_API_KEY',
    defaultValue: '',
  );

  static String get _apiKey {
    if (_primaryApiKey.trim().isNotEmpty) return _primaryApiKey.trim();
    if (_secondaryApiKey.trim().isNotEmpty) return _secondaryApiKey.trim();
    if (_tertiaryApiKey.trim().isNotEmpty) return _tertiaryApiKey.trim();
    return '';
  }

  static const String _configuredModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-1.5-flash',
  );

  static const String _configuredModelsCsv = String.fromEnvironment(
    'GEMINI_MODELS',
    defaultValue: '',
  );

  static const List<String> _fallbackModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-pro',
  ];

  static const int _maxModelAttempts = 2;

  static bool _isTransientModelError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('429') ||
        lower.contains('resource_exhausted') ||
        lower.contains('rate limit') ||
        lower.contains('too many requests') ||
        lower.contains('deadline exceeded') ||
        lower.contains('timeout') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('unavailable') ||
        lower.contains('503');
  }

  static String _detectMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  static List<String> _candidateModels() {
    final models = <String>[];

    void addModel(String model) {
      final trimmed = model.trim();
      if (trimmed.isEmpty || models.contains(trimmed)) return;
      models.add(trimmed);
    }

    addModel(_configuredModel);
    if (_configuredModelsCsv.trim().isNotEmpty) {
      for (final model in _configuredModelsCsv.split(',')) {
        addModel(model);
      }
    }
    for (final fallback in _fallbackModels) {
      addModel(fallback);
    }

    return models;
  }

  static AIValidationResult _mapErrorToResult(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('api key')) {
      return const AIValidationResult.rejected(
        userMessage: 'AI setup is incomplete. Please configure API key.',
        reason: AIValidationFailureReason.missingApiKey,
      );
    }
    if (message.contains('429') ||
        message.contains('resource_exhausted') ||
        message.contains('quota') ||
        message.contains('rate limit') ||
        message.contains('too many requests')) {
      return const AIValidationResult.rejected(
        userMessage: 'AI is busy right now. Please try again in a moment.',
        reason: AIValidationFailureReason.quotaOrRateLimited,
      );
    }
    if (message.contains('model') &&
        (message.contains('not found') || message.contains('unsupported'))) {
      return const AIValidationResult.rejected(
        userMessage: 'AI model is unavailable. Please retry shortly.',
        reason: AIValidationFailureReason.unavailableModel,
      );
    }
    if (message.contains('socket') ||
        message.contains('network') ||
        message.contains('timeout') ||
        message.contains('connection')) {
      return const AIValidationResult.rejected(
        userMessage: 'Network issue while checking photo. Please retry.',
        reason: AIValidationFailureReason.networkError,
      );
    }
    return const AIValidationResult.rejected(
      userMessage: 'AI validation failed. Please try again.',
      reason: AIValidationFailureReason.unknown,
    );
  }

  static Future<AIValidationResult> validateHabitCompletionDetailed(
    String habitTitle,
    File imageFile,
  ) async {
    if (_apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('AIService: No API key provided (GEMINI_API_KEY/GOOGLE_API_KEY/GENAI_API_KEY).');
      }
      return const AIValidationResult.rejected(
        userMessage: 'AI setup is incomplete in this build. Please configure API key and rebuild.',
        reason: AIValidationFailureReason.missingApiKey,
      );
    }

    try {
      final prompt = TextPart('''
        Analyze this image. The user claims this picture proves they completed their habit: "$habitTitle".
        Does the image realistically demonstrate the completion or participation in this habit?
        Reply with a single word "YES" if it proves it, or "NO" if it clearly does not.
      ''');

      final imageBytes = await imageFile.readAsBytes();
      if (imageBytes.isEmpty) {
        if (kDebugMode) {
          debugPrint('AIService: Image bytes are empty.');
        }
        return const AIValidationResult.rejected(
          userMessage: 'Photo appears invalid. Please capture again.',
          reason: AIValidationFailureReason.invalidImage,
        );
      }

      final imagePart = DataPart(_detectMimeType(imageFile.path), imageBytes);
      final candidates = _candidateModels();

      Object? lastError;
      for (final modelName in candidates) {
        for (var attempt = 1; attempt <= _maxModelAttempts; attempt++) {
          try {
            final model = GenerativeModel(
              model: modelName,
              apiKey: _apiKey,
            );

            final response = await model
                .generateContent([
                  Content.multi([prompt, imagePart]),
                ])
                .timeout(const Duration(seconds: 20));

            final text = response.text?.trim().toUpperCase() ?? 'NO';
            if (kDebugMode) {
              debugPrint('AIService: Validation response with $modelName: $text');
            }

            if (text.contains('YES')) {
              return const AIValidationResult.approved();
            }

            return const AIValidationResult.rejected(
              userMessage: 'AI did not find clear proof for this habit. Try a clearer photo.',
              reason: AIValidationFailureReason.rejectedByModel,
            );
          } catch (e) {
            lastError = e;
            if (kDebugMode) {
              debugPrint('AIService: Model $modelName failed (attempt $attempt): $e');
            }

            if (attempt >= _maxModelAttempts || !_isTransientModelError(e.toString())) {
              break;
            }

            await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
          }
        }
      }

      if (lastError != null) {
        if (kDebugMode) {
          debugPrint('AIService: All candidate models failed. Last error: $lastError');
        }
        return _mapErrorToResult(lastError);
      }

      return const AIValidationResult.rejected(
        userMessage: 'AI validation failed. Please try again.',
        reason: AIValidationFailureReason.unknown,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('AIService: Unexpected validation error: $e');
      return _mapErrorToResult(e);
    }
  }

  static Future<bool> validateHabitCompletion(
    String habitTitle,
    File imageFile,
  ) async {
    final result = await validateHabitCompletionDetailed(habitTitle, imageFile);
    return result.approved;
  }

  // ── AI Coaching ─────────────────────────────────────────────────────────

  /// Generate a personalized coaching insight based on habit data.
  static Future<String?> generateCoachingInsight({
    required int currentStreak,
    required double completionRate,
    required String bestDay,
    required String worstDay,
    required int totalHabits,
    required int totalCompletions,
    String? moodSummary,
  }) async {
    final key = _apiKey;
    if (key.isEmpty) return null;

    try {
      final model = GenerativeModel(
        model: _configuredModel,
        apiKey: key,
      );

      final prompt = '''You are a supportive, encouraging habit coach for the app "Trackly". 
Generate a brief, personalized coaching message (2-3 sentences max) based on this user data:

- Current streak: $currentStreak days
- Completion rate: ${(completionRate * 100).round()}%
- Best day: $bestDay
- Worst day: $worstDay
- Total habits: $totalHabits
- Total completions: $totalCompletions
${moodSummary != null ? '- Recent mood: $moodSummary' : ''}

Rules:
- Be warm, specific, and actionable
- If streak is strong, celebrate it
- If completion rate is low, be encouraging not judgmental
- If there's a weak day, suggest a concrete strategy
- Use 1-2 relevant emojis
- Never use generic platitudes like "you got this"
- Sound like a knowledgeable friend, not a corporate app''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AIService: Coaching insight failed: $e');
      }
      return null;
    }
  }

  /// Generate a weekly performance summary.
  static Future<String?> generateWeeklySummary({
    required double completionRate,
    required int streakLength,
    required int completedCount,
    required int totalPossible,
    required List<String> topHabits,
    required List<String> missedHabits,
  }) async {
    final key = _apiKey;
    if (key.isEmpty) return null;

    try {
      final model = GenerativeModel(
        model: _configuredModel,
        apiKey: key,
      );

      final prompt = '''You are a habit coach for "Trackly". Write a brief weekly summary (3-4 sentences) for this user:

- Weekly completion: ${(completionRate * 100).round()}% ($completedCount/$totalPossible)
- Current streak: $streakLength days
- Top habits: ${topHabits.join(', ')}
- Most missed: ${missedHabits.join(', ')}

Rules:
- Start with the highlight of the week
- Mention specific habit names
- End with one actionable tip for next week
- Warm, personal tone with 1-2 emojis
- Keep it under 4 sentences''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AIService: Weekly summary failed: $e');
      }
      return null;
    }
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Mood Journal Screen
// Beautiful mood check-in and journaling interface.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/mood_entry.dart';
import '../providers/mood_provider.dart';
import '../theme/app_layout.dart';

class MoodJournalScreen extends StatefulWidget {
  final DateTime? date;

  const MoodJournalScreen({super.key, this.date});

  @override
  State<MoodJournalScreen> createState() => _MoodJournalScreenState();
}

class _MoodJournalScreenState extends State<MoodJournalScreen> {
  MoodLevel? _selectedMood;
  final Set<String> _selectedTags = {};
  final TextEditingController _journalController = TextEditingController();
  bool _isSaving = false;
  late final DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.date ?? DateTime.now();

    // Load existing entry if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MoodProvider>();
      final existing = provider.todaysMood;
      if (existing != null && existing.dateKeyValue == MoodEntry.dateKey(_date)) {
        setState(() {
          _selectedMood = existing.moodLevel;
          _selectedTags.addAll(existing.tags);
          _journalController.text = existing.journalText;
        });
      }
    });
  }

  @override
  void dispose() {
    _journalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedMood == null) return;

    setState(() => _isSaving = true);

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final entry = MoodEntry(
      id: MoodEntry.dateKey(_date),
      userId: userId,
      date: _date,
      moodLevel: _selectedMood!,
      journalText: _journalController.text.trim(),
      tags: _selectedTags.toList(),
      createdAt: DateTime.now(),
    );

    try {
      await context.read<MoodProvider>().saveMood(entry);

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save mood: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'How are you feeling?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedMood != null)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppLayout.lg, 8, AppLayout.lg, 120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mood Selector ──
            _buildMoodSelector(scheme, isDark)
                .animate()
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 32),

            // ── Tags ──
            if (_selectedMood != null) ...[
              Text(
                'What describes your mood?',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms),
              const SizedBox(height: 14),
              _buildTagSelector(scheme, isDark)
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 300.ms),
              const SizedBox(height: 32),

              // ── Journal Entry ──
              Text(
                'Journal (optional)',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 300.ms),
              const SizedBox(height: 14),
              _buildJournalField(scheme, isDark)
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 300.ms),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoodSelector(ColorScheme scheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Column(
        children: [
          Text(
            _selectedMood?.emoji ?? '🤔',
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedMood?.label ?? 'Select your mood',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: MoodLevel.values.map((mood) {
              final isSelected = _selectedMood == mood;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedMood = mood);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? Border.all(color: scheme.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      mood.emoji,
                      style: TextStyle(
                        fontSize: isSelected ? 32 : 28,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSelector(ColorScheme scheme, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MoodTag.all.map((tag) {
        final isSelected = _selectedTags.contains(tag);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _selectedTags.remove(tag);
              } else {
                _selectedTags.add(tag);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.15)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: isSelected
                  ? Border.all(color: scheme.primary.withValues(alpha: 0.4))
                  : null,
            ),
            child: Text(
              tag,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildJournalField(ColorScheme scheme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: TextField(
        controller: _journalController,
        maxLines: 6,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: scheme.onSurface,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText: 'Write about your day, what went well, what you learned...',
          hintStyle: GoogleFonts.inter(
            fontSize: 15,
            color: scheme.onSurface.withValues(alpha: 0.35),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }
}

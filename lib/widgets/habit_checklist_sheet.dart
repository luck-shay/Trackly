// ─────────────────────────────────────────────────────────────────────────────
// Trackly — Habit Checklist Bottom Sheet
// Interactive sub-task checklist for multi-step routines.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../providers/habits_provider.dart';
import '../theme/category_colors.dart';

class HabitChecklistSheet extends StatefulWidget {
  final Habit habit;

  const HabitChecklistSheet({
    super.key,
    required this.habit,
  });

  static Future<void> show(BuildContext context, Habit habit) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HabitChecklistSheet(habit: habit),
    );
  }

  @override
  State<HabitChecklistSheet> createState() => _HabitChecklistSheetState();
}

class _HabitChecklistSheetState extends State<HabitChecklistSheet> {
  final TextEditingController _newItemController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Get live habit state from provider if updated
    final liveHabit = context.watch<HabitsProvider>().habitById(widget.habit.id) ?? widget.habit;
    final checklist = liveHabit.checklist;
    final completedCount = checklist.where((i) => i.isCompleted).length;
    final isAllDone = checklist.isNotEmpty && completedCount == checklist.length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: CategoryColors.forCategory(liveHabit.category)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CategoryColors.iconForCategory(liveHabit.category),
                        color: CategoryColors.forCategory(liveHabit.category),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            liveHabit.title,
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Routine Checklist • $completedCount/${checklist.length} done',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: scheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Progress Line
              if (checklist.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: checklist.isEmpty ? 0 : completedCount / checklist.length,
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                      color: scheme.primary,
                      minHeight: 6,
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Checklist Items List
              Flexible(
                child: checklist.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No sub-tasks in this checklist yet.',
                          style: GoogleFonts.inter(
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: checklist.length,
                        itemBuilder: (context, index) {
                          final item = checklist[index];
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context
                                  .read<HabitsProvider>()
                                  .toggleChecklistItem(liveHabit, item.id);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: item.isCompleted
                                          ? scheme.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: item.isCompleted
                                            ? scheme.primary
                                            : scheme.onSurface
                                                .withValues(alpha: 0.4),
                                        width: 2,
                                      ),
                                    ),
                                    child: item.isCompleted
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: Colors.black,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: item.isCompleted
                                            ? FontWeight.w500
                                            : FontWeight.w600,
                                        color: item.isCompleted
                                            ? scheme.onSurface
                                                .withValues(alpha: 0.45)
                                            : scheme.onSurface,
                                        decoration: item.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: scheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Add Step Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _isAdding
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newItemController,
                              autofocus: true,
                              style: GoogleFonts.inter(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Add a new step...',
                                hintStyle: TextStyle(
                                  color: scheme.onSurface.withValues(alpha: 0.4),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: scheme.primary.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  final newItem = HabitChecklistItem(
                                    id: '${DateTime.now().microsecondsSinceEpoch}',
                                    title: val.trim(),
                                  );
                                  final updated = [...checklist, newItem];
                                  final newHabit = liveHabit.copyWith(checklist: updated);
                                  context.read<HabitsProvider>().logHabitCompletion(newHabit);
                                  _newItemController.clear();
                                  setState(() => _isAdding = false);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded),
                            color: scheme.primary,
                            onPressed: () {
                              final val = _newItemController.text.trim();
                              if (val.isNotEmpty) {
                                final newItem = HabitChecklistItem(
                                  id: '${DateTime.now().microsecondsSinceEpoch}',
                                  title: val,
                                );
                                final updated = [...checklist, newItem];
                                final newHabit = liveHabit.copyWith(checklist: updated);
                                context.read<HabitsProvider>().logHabitCompletion(newHabit);
                                _newItemController.clear();
                                setState(() => _isAdding = false);
                              }
                            },
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: () => setState(() => _isAdding = true),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 20,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add sub-task step',
                                style: GoogleFonts.inter(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 12),

              // Bottom Button: Mark All Done / Complete Habit
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAllDone
                          ? scheme.primary.withValues(alpha: 0.2)
                          : scheme.primary,
                      foregroundColor: isAllDone ? scheme.primary : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      HapticFeedback.heavyImpact();
                      await context
                          .read<HabitsProvider>()
                          .markAllChecklistDone(liveHabit);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.done_all_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isAllDone ? 'Habit Complete ✓' : 'Mark All Done & Complete Habit',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

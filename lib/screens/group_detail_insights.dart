part of 'group_detail_screen.dart';

class _GroupPulseCard extends StatefulWidget {
  final Group group;
  final List<GroupTask> tasks;

  const _GroupPulseCard({required this.group, required this.tasks});

  @override
  State<_GroupPulseCard> createState() => _GroupPulseCardState();
}

class _GroupPulseCardState extends State<_GroupPulseCard> {
  late Future<Map<String, String>> _memberNamesFuture;

  @override
  void initState() {
    super.initState();
    _memberNamesFuture = _memberNames(widget.group.memberIds);
  }

  @override
  void didUpdateWidget(covariant _GroupPulseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameMembers(oldWidget.group.memberIds, widget.group.memberIds)) {
      _memberNamesFuture = _memberNames(widget.group.memberIds);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _sameMembers(List<String> previous, List<String> current) {
    if (previous.length != current.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      if (previous[index] != current[index]) {
        return false;
      }
    }
    return true;
  }

  Map<String, int> _todayCounts(DateTime now) {
    final counts = <String, int>{};
    for (final task in widget.tasks) {
      task.completions.forEach((uid, dates) {
        final total = dates.where((date) => _isSameDay(date, now)).length;
        if (total > 0) {
          counts[uid] = (counts[uid] ?? 0) + total;
        }
      });
    }
    return counts;
  }

  Map<String, int> _weekCounts(DateTime now) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final counts = <String, int>{};
    for (final task in widget.tasks) {
      task.completions.forEach((uid, dates) {
        final total = dates.where((date) {
          return !date.isBefore(start) && !date.isAfter(end);
        }).length;
        if (total > 0) {
          counts[uid] = (counts[uid] ?? 0) + total;
        }
      });
    }
    return counts;
  }

  Future<Map<String, String>> _memberNames(List<String> memberIds) async {
    final social = SocialService();
    final names = <String, String>{};

    for (final memberId in memberIds) {
      final profile = await social.getUserProfile(memberId);
      final username = profile?.username?.trim();
      final displayName = profile?.displayName.trim();

      if (displayName != null && displayName.isNotEmpty) {
        names[memberId] = displayName;
      } else if (username != null && username.isNotEmpty) {
        names[memberId] = '@$username';
      } else {
        names[memberId] = memberId;
      }
    }

    return names;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayCounts = _todayCounts(now);
    final weekCounts = _weekCounts(now);

    final activeToday = widget.group.memberIds
        .where((memberId) => (todayCounts[memberId] ?? 0) > 0)
        .length;

    String? topUid;
    var maxCount = 0;
    for (final entry in weekCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        topUid = entry.key;
      }
    }

    final hasTasks = widget.tasks.isNotEmpty;
    final hasMultipleMembers = widget.group.memberIds.length > 1;

    String nextAction;
    if (!hasTasks) {
      nextAction = 'Create your first task to start this group.';
    } else if (!hasMultipleMembers) {
      nextAction = 'Invite members so progress and competition can start.';
    } else if (activeToday == 0) {
      nextAction = 'No one has logged progress today yet.';
    } else {
      nextAction = 'Group is active today. Keep the streak going.';
    }

    return FutureBuilder<Map<String, String>>(
      future: _memberNamesFuture,
      builder: (context, snapshot) {
        final names = snapshot.data ?? const <String, String>{};
        final topName = topUid == null
            ? 'No leader yet'
            : '${names[topUid] ?? topUid} • $maxCount this week';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppLayout.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group Pulse',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const VGap(AppLayout.xs),
              Text(
                nextAction,
                style: GoogleFonts.inter(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.72),
                  height: 1.4,
                ),
              ),
              const VGap(AppLayout.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PulseChip(label: 'Tasks', value: '${widget.tasks.length}'),
                  _PulseChip(
                    label: 'Active Today',
                    value: '$activeToday/${widget.group.memberIds.length}',
                  ),
                  _PulseChip(label: 'Top Performer', value: topName),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PulseChip extends StatelessWidget {
  final String label;
  final String value;

  const _PulseChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

enum _LeaderboardWindow { today, week, allTime }

class _GroupLeaderboardCard extends StatefulWidget {
  final Group group;
  final List<GroupTask> tasks;

  const _GroupLeaderboardCard({required this.group, required this.tasks});

  @override
  State<_GroupLeaderboardCard> createState() => _GroupLeaderboardCardState();
}

class _GroupLeaderboardCardState extends State<_GroupLeaderboardCard> {
  _LeaderboardWindow _window = _LeaderboardWindow.week;
  bool _showCalendar = false;
  DateTime _calendarFocusedDay = DateTime.now();
  DateTime? _calendarSelectedDay;
  String? _calendarSelectedUid;
  late Future<Map<String, UserProfile?>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _profilesFuture = _loadProfiles(widget.group.memberIds);
  }

  @override
  void didUpdateWidget(covariant _GroupLeaderboardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameMembers(oldWidget.group.memberIds, widget.group.memberIds)) {
      _profilesFuture = _loadProfiles(widget.group.memberIds);
    }
  }

  Widget _buildWindowChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          color: selected
              ? (isDark ? Colors.white : scheme.onPrimary)
              : scheme.onSurface.withValues(alpha: isDark ? 0.88 : 0.78),
        ),
      ),
      selected: selected,
      selectedColor: isDark
          ? scheme.primary.withValues(alpha: 0.36)
          : scheme.primary.withValues(alpha: 0.2),
      backgroundColor: scheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.04),
      checkmarkColor: isDark ? Colors.white : scheme.onPrimary,
      side: BorderSide(
        color: selected
            ? (isDark
                  ? scheme.primary.withValues(alpha: 0.72)
                  : scheme.primary.withValues(alpha: 0.35))
            : scheme.onSurface.withValues(alpha: isDark ? 0.5 : 0.25),
        width: 1.5,
      ),
      onSelected: (_) => onTap(),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _sameMembers(List<String> previous, List<String> current) {
    if (previous.length != current.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      if (previous[index] != current[index]) {
        return false;
      }
    }
    return true;
  }

  bool _isWithinRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && !value.isAfter(end);
  }

  DateTime _dayOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Future<Map<String, UserProfile?>> _loadProfiles(
    List<String> memberIds,
  ) async {
    final social = SocialService();
    final profiles = await Future.wait(
      memberIds.map((memberId) => social.getUserProfile(memberId)),
    );

    final byId = <String, UserProfile?>{};
    for (var index = 0; index < memberIds.length; index++) {
      byId[memberIds[index]] = profiles[index];
    }
    return byId;
  }

  String _displayNameFor(String uid, Map<String, UserProfile?> profiles) {
    final profile = profiles[uid];
    final displayName = profile?.displayName.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final username = profile?.username?.trim() ?? '';
    if (username.isNotEmpty) {
      return '@$username';
    }
    return uid;
  }

  int _completionEventsForUser({
    required String uid,
    required DateTime start,
    required DateTime end,
  }) {
    var total = 0;
    for (final task in widget.tasks) {
      final dates = task.completions[uid] ?? const <DateTime>[];
      total += dates.where((date) => _isWithinRange(date, start, end)).length;
    }
    return total;
  }

  int _activeDaysForUser({
    required String uid,
    required DateTime start,
    required DateTime end,
  }) {
    final days = <DateTime>{};
    for (final task in widget.tasks) {
      final dates = task.completions[uid] ?? const <DateTime>[];
      for (final date in dates) {
        if (_isWithinRange(date, start, end)) {
          days.add(_dayOnly(date));
        }
      }
    }
    return days.length;
  }

  int _todayTaskCompletions(GroupTask task, DateTime now) {
    var total = 0;
    for (final dates in task.completions.values) {
      total += dates.where((date) => _isSameDay(date, now)).length;
    }
    return total;
  }

  int _completionsOnDateForUser({required String uid, required DateTime day}) {
    var total = 0;
    for (final task in widget.tasks) {
      final dates = task.completions[uid] ?? const <DateTime>[];
      total += dates.where((date) => _isSameDay(date, day)).length;
    }
    return total;
  }

  Map<DateTime, int> _calendarCountsForUser(String uid) {
    final counts = <DateTime, int>{};
    for (final task in widget.tasks) {
      final dates = task.completions[uid] ?? const <DateTime>[];
      for (final date in dates) {
        final day = _dayOnly(date);
        counts[day] = (counts[day] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final weekStart = todayStart.subtract(const Duration(days: 6));

    return FutureBuilder<Map<String, UserProfile?>>(
      future: _profilesFuture,
      builder: (context, snapshot) {
        final profiles = snapshot.data ?? const <String, UserProfile?>{};

        final rankRows =
            widget.group.memberIds.map((uid) {
              final todayEvents = _completionEventsForUser(
                uid: uid,
                start: todayStart,
                end: todayEnd,
              );
              final weekEvents = _completionEventsForUser(
                uid: uid,
                start: weekStart,
                end: todayEnd,
              );
              final allEvents = _completionEventsForUser(
                uid: uid,
                start: DateTime(2020, 1, 1),
                end: todayEnd,
              );

              final weekActiveDays = _activeDaysForUser(
                uid: uid,
                start: weekStart,
                end: todayEnd,
              );

              final score = switch (_window) {
                _LeaderboardWindow.today => todayEvents,
                _LeaderboardWindow.week => weekEvents,
                _LeaderboardWindow.allTime => allEvents,
              };

              return _LeaderboardMemberRow(
                uid: uid,
                name: _displayNameFor(uid, profiles),
                photoUrl: profiles[uid]?.photoUrl,
                score: score,
                todayEvents: todayEvents,
                weekEvents: weekEvents,
                allEvents: allEvents,
                weekActiveDays: weekActiveDays,
              );
            }).toList()..sort((a, b) {
              final scoreCompare = b.score.compareTo(a.score);
              if (scoreCompare != 0) {
                return scoreCompare;
              }
              final consistencyCompare = b.weekActiveDays.compareTo(
                a.weekActiveDays,
              );
              if (consistencyCompare != 0) {
                return consistencyCompare;
              }
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

        _LeaderboardMemberRow? mostConsistent;
        _LeaderboardMemberRow? mostActiveToday;
        for (final row in rankRows) {
          if (mostConsistent == null ||
              row.weekActiveDays > mostConsistent.weekActiveDays) {
            mostConsistent = row;
          }
          if (mostActiveToday == null ||
              row.todayEvents > mostActiveToday.todayEvents) {
            mostActiveToday = row;
          }
        }

        GroupTask? topTaskToday;
        var topTaskTodayCompletions = 0;
        for (final task in widget.tasks) {
          final taskCompletions = _todayTaskCompletions(task, now);
          if (taskCompletions > topTaskTodayCompletions) {
            topTaskTodayCompletions = taskCompletions;
            topTaskToday = task;
          }
        }

        final scoreLabel = switch (_window) {
          _LeaderboardWindow.today => 'today',
          _LeaderboardWindow.week => 'this week',
          _LeaderboardWindow.allTime => 'all time',
        };

        if (rankRows.isNotEmpty && _calendarSelectedUid == null) {
          _calendarSelectedUid = rankRows.first.uid;
        }
        final selectedUid = _calendarSelectedUid;
        final dayCounts = selectedUid == null
            ? const <DateTime, int>{}
            : _calendarCountsForUser(selectedUid);
        final selectedDay = _calendarSelectedDay ?? _dayOnly(now);
        final selectedDayCount = selectedUid == null
            ? 0
            : _completionsOnDateForUser(uid: selectedUid, day: selectedDay);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppLayout.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group Leaderboard',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const VGap(AppLayout.xs),
              Text(
                'Ranked by completions $scoreLabel.',
                style: GoogleFonts.inter(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.72),
                  height: 1.4,
                ),
              ),
              const VGap(AppLayout.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildWindowChip(
                    context,
                    label: 'Leaderboard',
                    selected: !_showCalendar,
                    onTap: () {
                      setState(() => _showCalendar = false);
                    },
                  ),
                  _buildWindowChip(
                    context,
                    label: 'Calendar',
                    selected: _showCalendar,
                    onTap: () {
                      setState(() => _showCalendar = true);
                    },
                  ),
                  _buildWindowChip(
                    context,
                    label: 'Today',
                    selected: _window == _LeaderboardWindow.today,
                    onTap: () {
                      setState(() => _window = _LeaderboardWindow.today);
                    },
                  ),
                  _buildWindowChip(
                    context,
                    label: 'Week',
                    selected: _window == _LeaderboardWindow.week,
                    onTap: () {
                      setState(() => _window = _LeaderboardWindow.week);
                    },
                  ),
                  _buildWindowChip(
                    context,
                    label: 'All time',
                    selected: _window == _LeaderboardWindow.allTime,
                    onTap: () {
                      setState(() => _window = _LeaderboardWindow.allTime);
                    },
                  ),
                ],
              ),
              const VGap(AppLayout.sm),
              if (_showCalendar) ...[
                if (rankRows.isEmpty)
                  Text(
                    'No members yet.',
                    style: GoogleFonts.inter(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedUid,
                    decoration: const InputDecoration(
                      labelText: 'Member',
                      border: OutlineInputBorder(),
                    ),
                    items: rankRows
                        .map(
                          (row) => DropdownMenuItem<String>(
                            value: row.uid,
                            child: Text(row.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _calendarSelectedUid = value;
                      });
                    },
                  ),
                  const VGap(AppLayout.sm),
                  TableCalendar<void>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _calendarFocusedDay,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selectedDayPredicate: (day) =>
                        _isSameDay(day, _calendarSelectedDay ?? _dayOnly(now)),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _calendarSelectedDay = selected;
                        _calendarFocusedDay = focused;
                      });
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final count = dayCounts[_dayOnly(day)] ?? 0;
                        if (count <= 0) {
                          return null;
                        }
                        final intensity = count >= 5
                            ? 0.45
                            : count >= 3
                            ? 0.32
                            : 0.2;
                        return Container(
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: intensity),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const VGap(AppLayout.xs),
                  Text(
                    'Selected day: ${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')} • $selectedDayCount completions',
                    style: GoogleFonts.inter(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ] else ...[
                if (rankRows.isEmpty)
                  Text(
                    'No members yet.',
                    style: GoogleFonts.inter(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  )
                else
                  ...rankRows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return _LeaderboardTile(
                      rank: index + 1,
                      row: row,
                      metricLabel: scoreLabel,
                    );
                  }),
              ],
              const VGap(AppLayout.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PulseChip(
                    label: 'Most consistent',
                    value: mostConsistent == null
                        ? 'No data yet'
                        : '${mostConsistent.name} • ${mostConsistent.weekActiveDays}/7 days',
                  ),
                  _PulseChip(
                    label: 'Most active today',
                    value: mostActiveToday == null
                        ? 'No data yet'
                        : '${mostActiveToday.name} • ${mostActiveToday.todayEvents} completions',
                  ),
                  _PulseChip(
                    label: 'Top task today',
                    value: topTaskToday == null || topTaskTodayCompletions == 0
                        ? 'No completions yet'
                        : '${topTaskToday.title} • $topTaskTodayCompletions',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeaderboardMemberRow {
  final String uid;
  final String name;
  final String? photoUrl;
  final int score;
  final int todayEvents;
  final int weekEvents;
  final int allEvents;
  final int weekActiveDays;

  const _LeaderboardMemberRow({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.score,
    required this.todayEvents,
    required this.weekEvents,
    required this.allEvents,
    required this.weekActiveDays,
  });
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final _LeaderboardMemberRow row;
  final String metricLabel;

  const _LeaderboardTile({
    required this.rank,
    required this.row,
    required this.metricLabel,
  });

  IconData _rankIcon(int rank) {
    if (rank == 1) return Icons.emoji_events_rounded;
    if (rank == 2) return Icons.workspace_premium_rounded;
    if (rank == 3) return Icons.military_tech_rounded;
    return Icons.tag_rounded;
  }

  Color _rankColor(BuildContext context, int rank) {
    if (rank == 1) return const Color(0xFFFFC107);
    if (rank == 2) return const Color(0xFFB0BEC5);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(_rankIcon(rank), color: _rankColor(context, rank), size: 20),
          const HGap(10),
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
            backgroundImage:
                row.photoUrl != null && row.photoUrl!.trim().isNotEmpty
                ? NetworkImage(row.photoUrl!.trim())
                : null,
            child: row.photoUrl != null && row.photoUrl!.trim().isNotEmpty
                ? null
                : Text(
                    (row.name.isEmpty ? '?' : row.name[0]).toUpperCase(),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
          ),
          const HGap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${row.todayEvents} today • ${row.weekEvents} week • ${row.allEvents} total',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${row.score}',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const HGap(4),
          Text(
            metricLabel,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

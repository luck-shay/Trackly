import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/group.dart';
import '../models/group_challenge.dart';
import '../models/user_profile.dart';
import '../services/group_service.dart';
import '../services/social_service.dart';
import '../theme/app_layout.dart';
import '../utils/quantity_format.dart';

class GroupChallengeDetailScreen extends StatelessWidget {
  final Group group;
  final GroupChallenge challenge;

  const GroupChallengeDetailScreen({
    super.key,
    required this.group,
    required this.challenge,
  });

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _displayName(String uid, Map<String, UserProfile?> profiles) {
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

  Future<Map<String, UserProfile?>> _loadProfiles(List<String> uids) async {
    final social = SocialService();
    final profiles = await Future.wait(
      uids.map((uid) => social.getUserProfile(uid)),
    );
    final map = <String, UserProfile?>{};
    for (var i = 0; i < uids.length; i++) {
      map[uids[i]] = profiles[i];
    }
    return map;
  }

  String _timeLabel(GroupChallenge liveChallenge) {
    if (!liveChallenge.isReadyToStart) {
      return 'Waiting for invite acceptance';
    }
    final now = DateTime.now();
    if (now.isBefore(liveChallenge.startAt)) {
      final days = liveChallenge.startAt.difference(now).inDays + 1;
      return 'Starts in $days day${days == 1 ? '' : 's'}';
    }
    if (now.isAfter(liveChallenge.endAt)) {
      return 'Challenge ended';
    }
    final daysLeft =
        liveChallenge.endAt
            .difference(DateTime(now.year, now.month, now.day))
            .inDays +
        1;
    return '$daysLeft day${daysLeft == 1 ? '' : 's'} left';
  }

  Future<void> _endChallenge(
    BuildContext context,
    GroupChallenge liveChallenge,
  ) async {
    final shouldEnd =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('End challenge now?'),
              content: const Text(
                'This will close the challenge immediately for everyone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('End Challenge'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldEnd || !context.mounted) {
      return;
    }

    try {
      await GroupService().endGroupChallenge(liveChallenge);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Challenge ended.')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not end challenge. ${error.toString().split('\n').first}',
          ),
        ),
      );
    }
  }

  Future<void> _logProgress(
    BuildContext context,
    GroupChallenge liveChallenge,
  ) async {
    final controller = TextEditingController(text: '1');

    final entered = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Log Progress',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const VGap(AppLayout.xs),
                Text(
                  liveChallenge.title,
                  style: GoogleFonts.inter(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const VGap(AppLayout.md),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    suffixText: liveChallenge.hasTarget
                        ? liveChallenge.unit
                        : null,
                  ),
                ),
                const VGap(AppLayout.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 2, 3, 5].map((value) {
                    return ActionChip(
                      label: Text('+$value'),
                      onPressed: () {
                        controller.text = value.toString();
                      },
                    );
                  }).toList(),
                ),
                const VGap(AppLayout.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final parsed = double.tryParse(controller.text.trim());
                      if (parsed == null || !parsed.isFinite || parsed <= 0) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a valid value greater than 0.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(sheetContext, parsed);
                    },
                    child: const Text('Save progress'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (entered == null || entered <= 0 || !context.mounted) {
      return;
    }

    try {
      await GroupService().addChallengeProgress(
        challenge: liveChallenge,
        delta: entered,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            liveChallenge.hasTarget
                ? 'Logged ${formatQuantity(entered, maxDecimals: 1)} ${liveChallenge.unit}.'
                : 'Logged ${formatQuantity(entered, maxDecimals: 1)} progress.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save progress. ${error.toString().split('\n').first}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = GroupService().userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Challenge',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<List<GroupChallenge>>(
        stream: GroupService().streamGroupChallenges(group.id),
        builder: (context, snapshot) {
          final challenges = snapshot.data ?? const <GroupChallenge>[];
          GroupChallenge? liveChallenge;
          for (final candidate in challenges) {
            if (candidate.id == challenge.id) {
              liveChallenge = candidate;
              break;
            }
          }
          final challengeData = liveChallenge ?? challenge;

          final amParticipant =
              myUid.isNotEmpty && challengeData.participantIds.contains(myUid);
          final myTotal = myUid.isEmpty
              ? 0.0
              : challengeData.totalForUser(myUid);
          final myToday = myUid.isEmpty
              ? 0.0
              : challengeData.valueForUserOnDate(myUid, DateTime.now());
          final myProgress =
              challengeData.hasTarget && challengeData.targetValue > 0
              ? (myTotal / challengeData.targetValue).clamp(0.0, 1.0).toDouble()
              : 0.0;

          final rows =
              challengeData.participantIds.map((uid) {
                return (
                  uid,
                  challengeData.totalForUser(uid),
                  challengeData.valueForUserOnDate(uid, DateTime.now()),
                );
              }).toList()..sort((a, b) {
                final scoreCompare = b.$2.compareTo(a.$2);
                if (scoreCompare != 0) {
                  return scoreCompare;
                }
                return a.$1.compareTo(b.$1);
              });

          return FutureBuilder<Map<String, UserProfile?>>(
            future: _loadProfiles(challengeData.participantIds),
            builder: (context, profileSnapshot) {
              final profiles =
                  profileSnapshot.data ?? const <String, UserProfile?>{};

              return SingleChildScrollView(
                padding: AppLayout.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
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
                            challengeData.title,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (challengeData.description.trim().isNotEmpty) ...[
                            const VGap(AppLayout.xs),
                            Text(
                              challengeData.description,
                              style: GoogleFonts.inter(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.74),
                                height: 1.4,
                              ),
                            ),
                          ],
                          const VGap(AppLayout.sm),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(
                                label: 'Status',
                                value: _timeLabel(challengeData),
                              ),
                              _MetaChip(
                                label: 'Target',
                                value: challengeData.hasTarget
                                    ? '${formatQuantity(challengeData.targetValue, maxDecimals: 1)} ${challengeData.unit}'
                                    : 'No target',
                              ),
                              _MetaChip(
                                label: 'Participants',
                                value: '${challengeData.participantIds.length}',
                              ),
                            ],
                          ),
                          if (amParticipant) ...[
                            const VGap(AppLayout.md),
                            if (challengeData.hasTarget)
                              Text(
                                challengeData.targetValue > 0
                                    ? 'You: ${formatQuantity(myTotal, maxDecimals: 1)}/${formatQuantity(challengeData.targetValue, maxDecimals: 1)} ${challengeData.unit}'
                                    : 'You: ${formatQuantity(myTotal, maxDecimals: 1)} ${challengeData.unit} logged (target is 0)',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (challengeData.hasTarget &&
                                challengeData.targetValue > 0) ...[
                              const VGap(AppLayout.xs),
                              LinearProgressIndicator(
                                value: myProgress,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ],
                            if (challengeData.hasTarget)
                              const VGap(AppLayout.xs),
                            Text(
                              challengeData.hasTarget
                                  ? 'Today: ${formatQuantity(myToday, maxDecimals: 1)} ${challengeData.unit}'
                                  : 'Today: ${formatQuantity(myToday, maxDecimals: 1)} logs',
                              style: GoogleFonts.inter(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.68),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const VGap(AppLayout.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Challenge Leaderboard',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (amParticipant)
                          ElevatedButton.icon(
                            onPressed: challengeData.isActive
                                ? () => _logProgress(context, challengeData)
                                : null,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Log'),
                          ),
                        const HGap(8),
                        if (!challengeData.hasEnded)
                          OutlinedButton.icon(
                            onPressed: () =>
                                _endChallenge(context, challengeData),
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('End'),
                          ),
                      ],
                    ),
                    const VGap(AppLayout.sm),
                    if (!challengeData.isReadyToStart)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'This challenge will start once at least one invited member accepts.',
                          style: GoogleFonts.inter(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.68),
                          ),
                        ),
                      ),
                    ...rows.asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final row = entry.value;
                      final uid = row.$1;
                      final total = row.$2;
                      final today = row.$3;
                      final isMe = uid == myUid;
                      final name = isMe ? 'You' : _displayName(uid, profiles);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '#$rank',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const HGap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    challengeData.hasTarget
                                        ? 'Today: ${formatQuantity(today, maxDecimals: 1)} ${challengeData.unit}'
                                        : 'Today: ${formatQuantity(today, maxDecimals: 1)} logs',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.66),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatQuantity(total, maxDecimals: 1),
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (rows.isEmpty)
                      Text(
                        'No participants available.',
                        style: GoogleFonts.inter(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.66),
                        ),
                      ),
                    const VGap(AppLayout.sm),
                    if (_isSameDay(challengeData.endAt, DateTime.now()) &&
                        challengeData.isActive)
                      Text(
                        'Challenge closes today. Final push.',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/group.dart';
import '../models/user_profile.dart';
import '../services/group_service.dart';
import '../services/social_service.dart';
import '../theme/app_layout.dart';

class CreateGroupChallengeScreen extends StatefulWidget {
  final Group group;

  const CreateGroupChallengeScreen({super.key, required this.group});

  @override
  State<CreateGroupChallengeScreen> createState() =>
      _CreateGroupChallengeScreenState();
}

class _CreateGroupChallengeScreenState
    extends State<CreateGroupChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unitController = TextEditingController();
  final _targetController = TextEditingController();

  final Set<String> _selectedParticipants = <String>{};
  bool _isSaving = false;
  bool _showParticipantRequirement = false;
  int _durationDays = 7;

  String get _currentUid => GroupService().userId;
  bool get _hasSelectedFriend =>
      _selectedParticipants.any((uid) => uid != _currentUid);

  @override
  void initState() {
    super.initState();
    if (_currentUid.isNotEmpty) {
      _selectedParticipants.add(_currentUid);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<Map<String, UserProfile?>> _loadProfiles() async {
    final social = SocialService();
    final profiles = await Future.wait(
      widget.group.memberIds.map((memberId) => social.getUserProfile(memberId)),
    );

    final map = <String, UserProfile?>{};
    for (var i = 0; i < widget.group.memberIds.length; i++) {
      map[widget.group.memberIds[i]] = profiles[i];
    }
    return map;
  }

  String _displayName(String uid, Map<String, UserProfile?> profiles) {
    if (uid == _currentUid) {
      return 'You';
    }
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

  Future<void> _save() async {
    setState(() {
      _showParticipantRequirement = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final unit = _unitController.text.trim();
    final targetRaw = _targetController.text.trim();

    final hasUnit = unit.isNotEmpty;
    final hasTarget = targetRaw.isNotEmpty;

    if (hasUnit != hasTarget) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Target and unit must be entered together, or both left empty.',
          ),
        ),
      );
      return;
    }

    var targetValue = 0.0;
    if (hasTarget) {
      final parsedTarget = double.tryParse(targetRaw);
      if (parsedTarget == null || !parsedTarget.isFinite || parsedTarget < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid target of 0 or more.')),
        );
        return;
      }
      targetValue = parsedTarget;
    }

    if (!_hasSelectedFriend) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one other group member to challenge.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final startAt = DateTime(now.year, now.month, now.day);
    final endAt = startAt
        .add(Duration(days: _durationDays))
        .subtract(const Duration(seconds: 1));

    try {
      final challenge = await GroupService().createGroupChallenge(
        groupId: widget.group.id,
        title: title,
        description: description,
        participantIds: _selectedParticipants.toList(),
        unit: unit,
        targetValue: targetValue,
        startAt: startAt,
        endAt: endAt,
      );

      if (!mounted) {
        return;
      }
      Navigator.pop(context, challenge);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not create challenge. ${error.toString().split('\n').first}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Start Challenge',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<Map<String, UserProfile?>>(
        future: _loadProfiles(),
        builder: (context, snapshot) {
          final profiles = snapshot.data ?? const <String, UserProfile?>{};

          return SingleChildScrollView(
            padding: AppLayout.screenPadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a live head-to-head challenge in ${widget.group.name}.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const VGap(AppLayout.md),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Challenge title',
                      hintText: 'e.g. Solve 3 DSA problems this week',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Title is required.';
                      }
                      return null;
                    },
                  ),
                  const VGap(AppLayout.sm),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Add rules or context for the challenge.',
                    ),
                  ),
                  const VGap(AppLayout.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _targetController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Target (optional)',
                            hintText: '3',
                          ),
                          validator: (value) {
                            final raw = (value ?? '').trim();
                            if (raw.isEmpty) {
                              if (_unitController.text.trim().isNotEmpty) {
                                return 'Target is required when unit is set.';
                              }
                              return null;
                            }
                            final parsed = double.tryParse(raw);
                            if (parsed == null ||
                                !parsed.isFinite ||
                                parsed < 0) {
                              return 'Enter a number 0 or greater.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const HGap(AppLayout.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _unitController,
                          decoration: const InputDecoration(
                            labelText: 'Unit (optional)',
                            hintText: 'problems',
                          ),
                          validator: (value) {
                            final raw = (value ?? '').trim();
                            if (raw.isEmpty &&
                                _targetController.text.trim().isNotEmpty) {
                              return 'Unit is required when target is set.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const VGap(AppLayout.xs),
                  Text(
                    'Leave both blank for open-ended challenges.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                  const VGap(AppLayout.lg),
                  Text(
                    'Duration: $_durationDays day${_durationDays == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: _durationDays.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: '$_durationDays',
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _durationDays = value.round();
                            });
                          },
                  ),
                  Text(
                    'Challenge ends in $_durationDays day${_durationDays == 1 ? '' : 's'} from today.',
                    style: GoogleFonts.inter(
                      color: scheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                  const VGap(AppLayout.lg),
                  Text(
                    'Challenge participants',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const VGap(AppLayout.xs),
                  Text(
                    'You are auto-included. Select at least one friend to challenge.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  if (_showParticipantRequirement && !_hasSelectedFriend)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Please select at least one friend.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.error,
                        ),
                      ),
                    ),
                  const VGap(AppLayout.sm),
                  ...widget.group.memberIds.map((uid) {
                    final isMe = uid == _currentUid;
                    final selected = _selectedParticipants.contains(uid);

                    return CheckboxListTile(
                      value: selected,
                      onChanged: _isSaving || isMe
                          ? null
                          : (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedParticipants.add(uid);
                                } else {
                                  _selectedParticipants.remove(uid);
                                }
                                if (_showParticipantRequirement &&
                                    _hasSelectedFriend) {
                                  _showParticipantRequirement = false;
                                }
                              });
                            },
                      title: Text(
                        _displayName(uid, profiles),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: isMe
                          ? Text(
                              'Challenge creator',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: 0.62),
                              ),
                            )
                          : null,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }),
                  const VGap(AppLayout.xl),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.flag_rounded),
                      label: Text(
                        _isSaving ? 'Starting...' : 'Start Challenge',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

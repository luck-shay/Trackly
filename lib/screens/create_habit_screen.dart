import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../models/habit.dart';
import '../services/social_service.dart';
import '../providers/create_habit_provider.dart';
import '../theme/app_layout.dart';

class CreateHabitScreen extends StatelessWidget {
  final HabitSpaceType initialSpaceType;
  final Habit? initialHabit;

  const CreateHabitScreen({
    super.key,
    this.initialSpaceType = HabitSpaceType.individual,
    this.initialHabit,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateHabitProvider(),
      child: _CreateHabitView(
        initialSpaceType: initialHabit?.spaceType ?? initialSpaceType,
        initialHabit: initialHabit,
      ),
    );
  }
}

class _CreateHabitView extends StatefulWidget {
  final HabitSpaceType initialSpaceType;
  final Habit? initialHabit;

  const _CreateHabitView({
    required this.initialSpaceType,
    required this.initialHabit,
  });

  @override
  State<_CreateHabitView> createState() => _CreateHabitViewState();
}

class _CreateHabitViewState extends State<_CreateHabitView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _groupNameController;

  bool get _isEditMode => widget.initialHabit != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialHabit?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialHabit?.description ?? '',
    );
    _groupNameController = TextEditingController(
      text: widget.initialHabit?.groupName ?? '',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final provider = context.read<CreateHabitProvider>();
      if (widget.initialHabit != null) {
        provider.initializeForEdit(widget.initialHabit!);
        return;
      }

      if (provider.spaceType != widget.initialSpaceType) {
        provider.setSpaceType(widget.initialSpaceType);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Edit Routine' : 'New Routine',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: AppLayout.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What do you want to build?',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fade().slideY(begin: 0.1),
              const VGap(AppLayout.xl),

              Text(
                'HABIT NAME',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ).animate().fade(delay: 100.ms),
              const VGap(AppLayout.sm),
              Consumer<CreateHabitProvider>(
                builder: (context, provider, child) {
                  return TextFormField(
                    controller: _titleController,
                    style: GoogleFonts.inter(fontSize: 18),
                    decoration: InputDecoration(
                      hintText: provider.currentPlaceholder,
                      hintStyle: TextStyle(color: Colors.grey[700]),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please give your habit a name.';
                      }
                      return null;
                    },
                  );
                },
              ).animate().fade(delay: 150.ms).slideX(begin: 0.05),

              const VGap(AppLayout.xl),

              Text(
                'DESCRIPTION (OPTIONAL)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ).animate().fade(delay: 200.ms),
              const VGap(AppLayout.sm),
              TextFormField(
                controller: _descriptionController,
                style: GoogleFonts.inter(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'e.g. 5km around the park',
                  hintStyle: TextStyle(color: Colors.grey[700]),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 3,
              ).animate().fade(delay: 250.ms).slideX(begin: 0.05),

              const VGap(AppLayout.xxl),

              Text(
                'TRACKING TYPE',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ).animate().fade(delay: 260.ms),
              const VGap(AppLayout.sm),
              Consumer<CreateHabitProvider>(
                builder: (context, provider, child) {
                  return SwitchListTile.adaptive(
                    value: provider.isQuantified,
                    onChanged: provider.setQuantified,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Enable quantified logging',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      provider.isQuantified
                          ? 'Users will log a value (distance, hours, reps, etc.)'
                          : 'Simple done/undone toggle',
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  );
                },
              ),
              Consumer<CreateHabitProvider>(
                builder: (context, provider, child) {
                  return SwitchListTile.adaptive(
                    value: provider.requiresPhotoValidation,
                    onChanged: provider.setRequiresPhotoValidation,
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Text(
                          'Require Photo Validation',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.auto_awesome, color: Colors.yellow[700], size: 16),
                      ],
                    ),
                    subtitle: Text(
                      'AI will check proof of your work upon completion',
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  );
                },
              ),
              Consumer<CreateHabitProvider>(
                builder: (context, provider, child) {
                  if (!provider.isQuantified) {
                    return const SizedBox.shrink();
                  }

                  const units = [
                    'km',
                    'hours',
                    'reps',
                    'pages',
                    'steps',
                    'units',
                  ];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const VGap(AppLayout.sm),
                      Text(
                        'UNIT',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 1.2,
                        ),
                      ),
                      const VGap(AppLayout.xs),
                      Wrap(
                        spacing: AppLayout.xs,
                        runSpacing: AppLayout.xs,
                        children: units.map((unit) {
                          final isSelected = provider.quantUnit == unit;
                          return ChoiceChip(
                            label: Text(unit),
                            selected: isSelected,
                            onSelected: (_) => provider.setQuantUnit(unit),
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            labelStyle: GoogleFonts.inter(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                      const VGap(AppLayout.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MAX DAILY VALUE',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '${provider.quantMax.toStringAsFixed(provider.quantValueDecimals)} ${provider.quantUnit}',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: provider.quantMax,
                        min: provider.quantSliderMin,
                        max: provider.quantSliderMax,
                        divisions: provider.quantSliderDivisions,
                        onChanged: provider.setQuantMax,
                      ),
                    ],
                  );
                },
              ),

              const VGap(AppLayout.xxl),

              Text(
                'SHARING MODE',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ).animate().fade(delay: 275.ms),
              const VGap(AppLayout.sm),
              Consumer<CreateHabitProvider>(
                builder: (context, provider, child) {
                  final isIndividual =
                      provider.spaceType == HabitSpaceType.individual;
                  final isShared =
                      provider.spaceType == HabitSpaceType.sharedTask;
                  final isGroup = provider.spaceType == HabitSpaceType.group;

                  return Wrap(
                    spacing: AppLayout.xs,
                    runSpacing: AppLayout.xs,
                    children: [
                      ChoiceChip(
                        label: const Text('Individual'),
                        selected: isIndividual,
                        onSelected: _isEditMode
                            ? null
                            : (_) {
                                provider.setSpaceType(HabitSpaceType.individual);
                              },
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        labelStyle: GoogleFonts.inter(
                          color: isIndividual ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Shared task'),
                        selected: isShared,
                        onSelected: _isEditMode
                            ? null
                            : (_) {
                                provider.setSpaceType(HabitSpaceType.sharedTask);
                              },
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        labelStyle: GoogleFonts.inter(
                          color: isShared ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Group'),
                        selected: isGroup,
                        onSelected: _isEditMode
                            ? null
                            : (_) {
                                provider.setSpaceType(HabitSpaceType.group);
                              },
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        labelStyle: GoogleFonts.inter(
                          color: isGroup ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ).animate().fade(delay: 300.ms).slideX(begin: 0.05),

              if (_isEditMode) ...[
                const VGap(AppLayout.xs),
                Text(
                  'Sharing mode is locked after creation.',
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],

              const VGap(AppLayout.md),
              Consumer<CreateHabitProvider>(
                builder: (context, provider, child) {
                  if (provider.spaceType != HabitSpaceType.group) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GROUP NAME',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 1.2,
                        ),
                      ).animate().fade(delay: 325.ms),
                      const VGap(AppLayout.sm),
                      TextFormField(
                        controller: _groupNameController,
                        style: GoogleFonts.inter(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'e.g. Sunrise Runners',
                          hintStyle: TextStyle(color: Colors.grey[700]),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (provider.spaceType == HabitSpaceType.group &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Please name the group.';
                          }
                          return null;
                        },
                      ).animate().fade(delay: 350.ms).slideX(begin: 0.05),
                      const VGap(AppLayout.sm),
                      Text(
                        'Groups are the premium, richer collaboration mode. Shared tasks stay lightweight for small circles.',
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ).animate().fade(delay: 375.ms),
                      const VGap(AppLayout.md),
                      Text(
                        'GROUP TASK MODE',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 1.2,
                        ),
                      ),
                      const VGap(AppLayout.xs),
                      Wrap(
                        spacing: AppLayout.xs,
                        runSpacing: AppLayout.xs,
                        children: GroupTaskMode.values.map((mode) {
                          final isSelected = provider.groupTaskMode == mode;
                          return ChoiceChip(
                            label: Text(mode.label),
                            selected: isSelected,
                            onSelected: (_) => provider.setGroupTaskMode(mode),
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            labelStyle: GoogleFonts.inter(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                      const VGap(AppLayout.xs),
                      Text(
                        provider.groupTaskMode == GroupTaskMode.shared
                            ? 'Everyone works on the same task.'
                            : 'Each member can set their own task inside the group.',
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const VGap(AppLayout.xxl),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TARGET FREQUENCY',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                      letterSpacing: 1.2,
                    ),
                  ),
                  Consumer<CreateHabitProvider>(
                    builder: (context, provider, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${provider.targetDays} days / week',
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ).animate().fade(delay: 300.ms),
              const VGap(AppLayout.md),
              Consumer<CreateHabitProvider>(
                builder: (context, provider, child) {
                  return SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      inactiveTrackColor: Theme.of(context).colorScheme.surface,
                      thumbColor: Theme.of(context).colorScheme.primary,
                      overlayColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                      trackHeight: 8.0,
                    ),
                    child: Slider(
                      value: provider.targetDays.toDouble(),
                      min: 1,
                      max: 7,
                      divisions: 6,
                      onChanged: (double value) {
                        provider.setTargetDays(value.toInt());
                      },
                    ),
                  );
                },
              ).animate().fade(delay: 350.ms),
              
              const VGap(AppLayout.xxl),

              Text(
                'REMINDER TIME',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ).animate().fade(delay: 375.ms),
              const VGap(AppLayout.sm),
              Consumer<CreateHabitProvider>(
                builder: (context, provider, child) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      final now = TimeOfDay.now();
                      final initialTime = provider.reminderTime != null
                          ? TimeOfDay(
                              hour: int.parse(provider.reminderTime!.split(':')[0]),
                              minute: int.parse(provider.reminderTime!.split(':')[1]),
                            )
                          : now;

                      final selected = await showTimePicker(
                        context: context,
                        initialTime: initialTime,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: Theme.of(context).colorScheme.primary,
                                onPrimary: Colors.black,
                                surface: const Color(0xFF1A1A1A),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (selected != null) {
                        provider.setReminderTime(
                          "${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}",
                        );
                      }
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: provider.reminderTime != null
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[600],
                      ),
                    ),
                    title: Text(
                      provider.reminderTime ?? 'No reminder set',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: provider.reminderTime != null 
                            ? Colors.white 
                            : Colors.grey[600],
                      ),
                    ),
                    trailing: provider.reminderTime != null
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => provider.setReminderTime(null),
                          )
                        : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  );
                },
              ).animate().fade(delay: 400.ms).slideX(begin: 0.05),


              const VGap(AppLayout.xxl),

              StreamBuilder<List<UserProfile>>(
                stream: SocialService().streamFriends(),
                builder: (context, snapshot) {
                  return Consumer<CreateHabitProvider>(
                    builder: (context, provider, child) {
                      if (provider.spaceType == HabitSpaceType.individual) {
                        return const SizedBox.shrink();
                      }

                      if (_isEditMode) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SHARING',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[500],
                                letterSpacing: 1.2,
                              ),
                            ).animate().fade(delay: 400.ms),
                            const VGap(AppLayout.sm),
                            Text(
                              'Friend sharing cannot be edited here. Use invite/leave actions from the habit details screen.',
                              style: GoogleFonts.inter(
                                color: Colors.grey[500],
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ).animate().fade(delay: 450.ms),
                          ],
                        );
                      }

                      final shareTitle =
                          provider.spaceType == HabitSpaceType.group
                          ? 'INVITE MEMBERS (OPTIONAL)'
                          : 'SHARE WITH FRIENDS (OPTIONAL)';

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shareTitle,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[500],
                                letterSpacing: 1.2,
                              ),
                            ).animate().fade(delay: 400.ms),
                            const VGap(AppLayout.sm),
                            Text(
                              'No friends to share with.',
                              style: GoogleFonts.inter(color: Colors.grey[600]),
                            ).animate().fade(delay: 450.ms),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shareTitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                              letterSpacing: 1.2,
                            ),
                          ).animate().fade(delay: 400.ms),
                          const VGap(AppLayout.sm),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: snapshot.data!.map((friend) {
                              final isSelected = provider.selectedFriends
                                  .contains(friend.uid);
                              return FilterChip(
                                label: Text(
                                  friend.displayName,
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                checkmarkColor: Colors.black,
                                onSelected: (_) {
                                  provider.toggleFriend(friend.uid);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ).animate().fade(delay: 450.ms);
                    },
                  );
                },
              ),

              const VGap(60),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final provider = context.read<CreateHabitProvider>();
                      final title = _titleController.text.trim();
                      final description = _descriptionController.text.trim();
                      final groupName = _groupNameController.text.trim();

                      if (provider.spaceType == HabitSpaceType.group &&
                          groupName.isEmpty) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please add a group name.'),
                            ),
                          );
                        }
                        return;
                      }
                      try {
                        final newHabit = await context
                            .read<CreateHabitProvider>()
                            .saveHabit(
                              title: title,
                              description: description,
                              groupName: groupName,
                            );
                        if (context.mounted) {
                          Navigator.pop(context, newHabit);
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not create habit. ${error.toString().split('\n').first}',
                              ),
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Consumer<CreateHabitProvider>(
                    builder: (context, provider, _) {
                      if (provider.isEditMode) {
                        return Text(
                          'Save Changes',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }

                      final ctaLabel =
                          provider.spaceType == HabitSpaceType.group
                          ? 'Create Group'
                          : provider.spaceType == HabitSpaceType.individual
                          ? 'Create Task'
                          : 'Create Shared Task';

                      return Text(
                        ctaLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ).animate().fade(delay: 450.ms).slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }
}

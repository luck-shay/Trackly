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

  const CreateHabitScreen({
    super.key,
    this.initialSpaceType = HabitSpaceType.individual,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateHabitProvider(),
      child: _CreateHabitView(initialSpaceType: initialSpaceType),
    );
  }
}

class _CreateHabitView extends StatefulWidget {
  final HabitSpaceType initialSpaceType;

  const _CreateHabitView({required this.initialSpaceType});

  @override
  State<_CreateHabitView> createState() => _CreateHabitViewState();
}

class _CreateHabitViewState extends State<_CreateHabitView> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final provider = context.read<CreateHabitProvider>();
      if (provider.spaceType != widget.initialSpaceType) {
        provider.setSpaceType(widget.initialSpaceType);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String title = '';
    String description = '';
    String groupName = '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Routine',
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
                    onSaved: (value) => title = value!,
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
                onSaved: (value) => description = value ?? '',
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
                        onSelected: (_) {
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
                        onSelected: (_) {
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
                        onSelected: (_) {
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
                        onSaved: (value) => groupName = value?.trim() ?? '',
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

              StreamBuilder<List<UserProfile>>(
                stream: SocialService().streamFriends(),
                builder: (context, snapshot) {
                  return Consumer<CreateHabitProvider>(
                    builder: (context, provider, child) {
                      if (provider.spaceType == HabitSpaceType.individual) {
                        return const SizedBox.shrink();
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
                      _formKey.currentState!.save();
                      final provider = context.read<CreateHabitProvider>();
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

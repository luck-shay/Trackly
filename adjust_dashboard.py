import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    text = f.read()

# Replace variables related to personalHabits up to filteredPersonalHabits
# We want individualHabits and sharedHabits

replacement = """
                  final individualHabits = provider.habits
                      .where((habit) => !habit.isGroup && habit.spaceType == HabitSpaceType.individual)
                      .toList();
                  final sharedHabits = provider.habits
                      .where((habit) => !habit.isGroup && habit.spaceType == HabitSpaceType.sharedTask)
                      .toList();
                  final groupHabits = provider.habits
                      .where((habit) => habit.isGroup)
                      .toList();
                  final orderedGroupHabits = _applySavedOrder(
                    groupHabits,
                    _groupOrderIds,
                  );
                  // For now, keep using _personalOrderIds for both, or separate them. Let's separate them later or just combine them for ordering:
                  final personalHabits = [...individualHabits, ...sharedHabits];
                  final orderedPersonalHabits = _applySavedOrder(
                    personalHabits,
                    _personalOrderIds,
                  );
                  if (!_hasCapturedInitialCompletionOrder &&
                      !_isLoadingSectionPrefs) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _refreshCompletedOrderSnapshot();
                    });
                  }
                  final displayGroupHabits = _orderWithCompletedLast(
                    orderedGroupHabits,
                  );
                  final displayPersonalHabits = _orderWithCompletedLast(
                    orderedPersonalHabits,
                  );
                  final displayIndividualHabits = displayPersonalHabits.where((h) => h.spaceType == HabitSpaceType.individual).toList();
                  final displaySharedHabits = displayPersonalHabits.where((h) => h.spaceType == HabitSpaceType.sharedTask).toList();

                  final individualCount = individualHabits.length;
                  final sharedCount = sharedHabits.length;

                  final scopeHabits = <Habit>[
                    ...displayGroupHabits,
                    ...displayPersonalHabits,
                  ];
                  final now = DateTime.now();
                  final completedCount = scopeHabits
                      .where(
                        (habit) =>
                            habit.isCompletedOnDate(provider.userId, now),
                      )
                      .length;
                  final incompleteCount = scopeHabits.length - completedCount;
                  final filteredGroupHabits = switch (_selectedFilter) {
                    DashboardFilter.all => displayGroupHabits,
                    DashboardFilter.challenges => const <Habit>[],
                    DashboardFilter.group => displayGroupHabits,
                    DashboardFilter.individual => const <Habit>[],
                    DashboardFilter.shared => const <Habit>[],
                    DashboardFilter.incomplete =>
                      displayGroupHabits
                          .where(
                            (habit) =>
                                !habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                    DashboardFilter.completed =>
                      displayGroupHabits
                          .where(
                            (habit) =>
                                habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                  };
                  final filteredIndividualHabits = switch (_selectedFilter) {
                    DashboardFilter.all => displayIndividualHabits,
                    DashboardFilter.challenges => const <Habit>[],
                    DashboardFilter.group => const <Habit>[],
                    DashboardFilter.individual => displayIndividualHabits,
                    DashboardFilter.shared => const <Habit>[],
                    DashboardFilter.incomplete =>
                      displayIndividualHabits
                          .where(
                            (habit) =>
                                !habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                    DashboardFilter.completed =>
                      displayIndividualHabits
                          .where(
                            (habit) =>
                                habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                  };
                  final filteredSharedHabits = switch (_selectedFilter) {
                    DashboardFilter.all => displaySharedHabits,
                    DashboardFilter.challenges => const <Habit>[],
                    DashboardFilter.group => const <Habit>[],
                    DashboardFilter.individual => const <Habit>[],
                    DashboardFilter.shared => displaySharedHabits,
                    DashboardFilter.incomplete =>
                      displaySharedHabits
                          .where(
                            (habit) =>
                                !habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                    DashboardFilter.completed =>
                      displaySharedHabits
                          .where(
                            (habit) =>
                                habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                  };
"""

target = """                  final personalHabits = provider.habits
                      .where((habit) => !habit.isGroup)
                      .toList();
                  final groupHabits = provider.habits
                      .where((habit) => habit.isGroup)
                      .toList();
                  final orderedGroupHabits = _applySavedOrder(
                    groupHabits,
                    _groupOrderIds,
                  );
                  final orderedPersonalHabits = _applySavedOrder(
                    personalHabits,
                    _personalOrderIds,
                  );
                  if (!_hasCapturedInitialCompletionOrder &&
                      !_isLoadingSectionPrefs) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _refreshCompletedOrderSnapshot();
                    });
                  }
                  final displayGroupHabits = _orderWithCompletedLast(
                    orderedGroupHabits,
                  );
                  final displayPersonalHabits = _orderWithCompletedLast(
                    orderedPersonalHabits,
                  );
                  final sharedCount = personalHabits.length;
                  final scopeHabits = <Habit>[
                    ...displayGroupHabits,
                    ...displayPersonalHabits,
                  ];
                  final now = DateTime.now();
                  final completedCount = scopeHabits
                      .where(
                        (habit) =>
                            habit.isCompletedOnDate(provider.userId, now),
                      )
                      .length;
                  final incompleteCount = scopeHabits.length - completedCount;
                  final filteredGroupHabits = switch (_selectedFilter) {
                    DashboardFilter.all => displayGroupHabits,
                    DashboardFilter.challenges => const <Habit>[],
                    DashboardFilter.group => displayGroupHabits,
                    DashboardFilter.individual => const <Habit>[],
                    DashboardFilter.shared => const <Habit>[],
                    DashboardFilter.incomplete =>
                      displayGroupHabits
                          .where(
                            (habit) =>
                                !habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                    DashboardFilter.completed =>
                      displayGroupHabits
                          .where(
                            (habit) =>
                                habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                  };
                  final filteredPersonalHabits = switch (_selectedFilter) {
                    DashboardFilter.all => displayPersonalHabits,
                    DashboardFilter.challenges => const <Habit>[],
                    DashboardFilter.group => const <Habit>[],
                    DashboardFilter.individual => displayPersonalHabits,
                    DashboardFilter.shared => displayPersonalHabits,
                    DashboardFilter.incomplete =>
                      displayPersonalHabits
                          .where(
                            (habit) =>
                                !habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                    DashboardFilter.completed =>
                      displayPersonalHabits
                          .where(
                            (habit) =>
                                habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                  };"""

text = text.replace(target, replacement)

# Then we also need to update the showPersonal logic
show_logic_target = """                  final showGroups =
                      filteredGroupHabits.isNotEmpty ||
                      _selectedFilter == DashboardFilter.all ||
                      _selectedFilter == DashboardFilter.group ||
                      _selectedFilter == DashboardFilter.incomplete ||
                      _selectedFilter == DashboardFilter.completed;
                  final showPersonal =
                      filteredPersonalHabits.isNotEmpty ||
                      _selectedFilter == DashboardFilter.all ||
                      _selectedFilter == DashboardFilter.shared ||
                      _selectedFilter == DashboardFilter.individual ||
                      _selectedFilter == DashboardFilter.incomplete ||
                      _selectedFilter == DashboardFilter.completed;"""

# sometimes the text is 
show_logic_target2 = """                  final showGroups =
                      filteredGroupHabits.isNotEmpty ||
                      _selectedFilter == DashboardFilter.all ||
                      _selectedFilter == DashboardFilter.group ||
                      _selectedFilter == DashboardFilter.incomplete ||
                      _selectedFilter == DashboardFilter.completed;
                  final showPersonal =
                      filteredPersonalHabits.isNotEmpty ||
                      _selectedFilter == DashboardFilter.all ||
                      _selectedFilter == DashboardFilter.shared ||
                      _selectedFilter == DashboardFilter.incomplete ||
                      _selectedFilter == DashboardFilter.completed;"""

show_logic_replacement = """                  final showGroups =
                      filteredGroupHabits.isNotEmpty ||
                      _selectedFilter == DashboardFilter.all ||
                      _selectedFilter == DashboardFilter.group ||
                      _selectedFilter == DashboardFilter.incomplete ||
                      _selectedFilter == DashboardFilter.completed;
                  final showIndividual =
                      filteredIndividualHabits.isNotEmpty ||
                      _selectedFilter == DashboardFilter.all ||
                      _selectedFilter == DashboardFilter.individual ||
                      _selectedFilter == DashboardFilter.incomplete ||
                      _selectedFilter == DashboardFilter.completed;
                  final showShared =
                      filteredSharedHabits.isNotEmpty ||
                      _selectedFilter == DashboardFilter.all ||
                      _selectedFilter == DashboardFilter.shared ||
                      _selectedFilter == DashboardFilter.incomplete ||
                      _selectedFilter == DashboardFilter.completed;"""

text = text.replace(show_logic_target, show_logic_replacement)
text = text.replace(show_logic_target2, show_logic_replacement)

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(text)


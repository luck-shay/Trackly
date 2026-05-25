part of 'create_habit_screen.dart';

class _FriendSelectionSheet extends StatefulWidget {
  final String title;
  final List<UserProfile> friends;
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _FriendSelectionSheet({
    required this.title,
    required this.friends,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  State<_FriendSelectionSheet> createState() => _FriendSelectionSheetState();
}

class _FriendSelectionSheetState extends State<_FriendSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _displayName(UserProfile friend) {
    final name = friend.displayName.trim();
    return name.isEmpty ? friend.uid : name;
  }

  String? _subtitleForFriend(UserProfile friend, bool hasDuplicateDisplayName) {
    final username = friend.username?.trim() ?? '';
    final email = friend.email.trim();

    if (username.isNotEmpty && hasDuplicateDisplayName && email.isNotEmpty) {
      return '@$username • $email';
    }
    if (username.isNotEmpty) {
      return '@$username';
    }
    if (email.isNotEmpty) {
      return email;
    }
    if (hasDuplicateDisplayName) {
      return 'ID: ${friend.uid.substring(0, friend.uid.length < 8 ? friend.uid.length : 8)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sortedFriends = List<UserProfile>.from(widget.friends)
      ..sort(
        (a, b) => _displayName(
          a,
        ).toLowerCase().compareTo(_displayName(b).toLowerCase()),
      );

    final nameCounts = <String, int>{};
    for (final friend in sortedFriends) {
      final key = _displayName(friend).toLowerCase();
      nameCounts[key] = (nameCounts[key] ?? 0) + 1;
    }

    final filteredFriends = sortedFriends.where((friend) {
      if (_searchQuery.isEmpty) {
        return true;
      }
      final displayName = _displayName(friend).toLowerCase();
      final username = (friend.username ?? '').trim().toLowerCase();
      final email = friend.email.trim().toLowerCase();
      return displayName.contains(_searchQuery) ||
          username.contains(_searchQuery) ||
          email.contains(_searchQuery);
    }).toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppLayout.lg,
          AppLayout.md,
          AppLayout.lg,
          AppLayout.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const VGap(AppLayout.xs),
            Text(
              '${widget.selectedIds.length} selected',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            const VGap(AppLayout.sm),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, username, or email',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.2,
                  ),
                ),
              ),
            ),
            const VGap(AppLayout.sm),
            if (filteredFriends.isEmpty)
              Text(
                'No friends match your search.',
                style: GoogleFonts.inter(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              )
            else
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: ListView.separated(
                  itemCount: filteredFriends.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (context, index) {
                    final friend = filteredFriends[index];
                    final isSelected = widget.selectedIds.contains(friend.uid);
                    final subtitle = _subtitleForFriend(
                      friend,
                      (nameCounts[_displayName(friend).toLowerCase()] ?? 0) > 1,
                    );

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        setState(() {
                          widget.onToggle(friend.uid);
                        });
                      },
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.08),
                        backgroundImage:
                            friend.photoUrl != null &&
                                friend.photoUrl!.trim().isNotEmpty
                            ? NetworkImage(friend.photoUrl!.trim())
                            : null,
                        child:
                            friend.photoUrl != null &&
                                friend.photoUrl!.trim().isNotEmpty
                            ? null
                            : Text(
                                (_displayName(friend).isEmpty
                                        ? '?'
                                        : _displayName(friend)[0])
                                    .toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      title: Text(
                        _displayName(friend),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: subtitle == null
                          ? null
                          : Text(
                              subtitle,
                              style: GoogleFonts.inter(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.62),
                              ),
                            ),
                      trailing: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.08),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(
                          isSelected ? Icons.check_rounded : Icons.add_rounded,
                          size: 18,
                          color: isSelected
                              ? Colors.black
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

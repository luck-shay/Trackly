part of 'group_detail_screen.dart';

class _InviteMembersSheet extends StatefulWidget {
  final Group group;

  const _InviteMembersSheet({required this.group});

  @override
  State<_InviteMembersSheet> createState() => _InviteMembersSheetState();
}

class _GroupMembersSheet extends StatelessWidget {
  final Group group;

  const _GroupMembersSheet({required this.group});

  Future<List<UserProfile>> _loadMembers() async {
    final social = SocialService();
    final memberIds = group.memberIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    final profiles = await Future.wait(
      memberIds.map((id) => social.getUserProfile(id)),
    );

    final resolved = <UserProfile>[];
    for (var i = 0; i < memberIds.length; i++) {
      final uid = memberIds[i];
      final profile = profiles[i];
      if (profile != null) {
        resolved.add(profile);
      } else {
        resolved.add(
          UserProfile(
            uid: uid,
            email: '',
            displayName: uid,
            username: null,
            photoUrl: null,
            friends: const <String>[],
          ),
        );
      }
    }

    resolved.sort((a, b) {
      if (a.uid == group.ownerId) return -1;
      if (b.uid == group.ownerId) return 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
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
              'Group members',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const VGap(AppLayout.xs),
            Text(
              '${group.memberIds.length} member${group.memberIds.length == 1 ? '' : 's'} in ${group.name}',
              style: GoogleFonts.inter(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const VGap(AppLayout.md),
            Flexible(
              child: FutureBuilder<List<UserProfile>>(
                future: _loadMembers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final members = snapshot.data!;
                  if (members.isEmpty) {
                    return Text(
                      'No members found in this group.',
                      style: GoogleFonts.inter(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final isOwner = member.uid == group.ownerId;
                      final subtitle =
                          member.username != null &&
                              member.username!.trim().isNotEmpty
                          ? '@${member.username!.trim()}'
                          : null;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.08),
                          backgroundImage:
                              member.photoUrl != null &&
                                  member.photoUrl!.trim().isNotEmpty
                              ? NetworkImage(member.photoUrl!.trim())
                              : null,
                          child:
                              member.photoUrl != null &&
                                  member.photoUrl!.trim().isNotEmpty
                              ? null
                              : Text(
                                  (member.displayName.isEmpty
                                          ? '?'
                                          : member.displayName[0])
                                      .toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                member.displayName.isEmpty
                                    ? member.uid
                                    : member.displayName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isOwner)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Admin',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: subtitle == null
                            ? null
                            : Text(
                                subtitle,
                                style: GoogleFonts.inter(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.62),
                                ),
                              ),
                      );
                    },
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

class _InviteMembersSheetState extends State<_InviteMembersSheet> {
  final Set<String> _selectedFriendIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSubmitting = false;

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

  Future<void> _sendInvites() async {
    if (_selectedFriendIds.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final social = SocialService();
      for (final uid in _selectedFriendIds) {
        await social.sendGroupInvite(
          groupId: widget.group.id,
          groupName: widget.group.name,
          toUserId: uid,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Group invites sent.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send invites. ${error.toString().split('\n').first}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'Invite members',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const VGap(AppLayout.sm),
            Text(
              'Select friends to invite to ${widget.group.name}.',
              style: GoogleFonts.inter(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const VGap(AppLayout.md),
            StreamBuilder<List<UserProfile>>(
              stream: SocialService().streamFriends(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final inviteableFriends = snapshot.data!
                    .where(
                      (friend) => !widget.group.memberIds.contains(friend.uid),
                    )
                    .toList();

                if (inviteableFriends.isEmpty) {
                  return Text(
                    'All your friends are already in this group, or you have no friends yet.',
                    style: GoogleFonts.inter(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  );
                }

                inviteableFriends.sort(
                  (a, b) => a.displayName.toLowerCase().compareTo(
                    b.displayName.toLowerCase(),
                  ),
                );

                final nameCounts = <String, int>{};
                for (final friend in inviteableFriends) {
                  final key = _displayName(friend).toLowerCase();
                  nameCounts[key] = (nameCounts[key] ?? 0) + 1;
                }

                final filteredFriends = inviteableFriends.where((friend) {
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedFriendIds.length} selected',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const VGap(AppLayout.xs),
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
                        height: MediaQuery.of(context).size.height * 0.34,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredFriends.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (context, index) {
                            final friend = filteredFriends[index];
                            final isSelected = _selectedFriendIds.contains(
                              friend.uid,
                            );
                            final subtitle = _subtitleForFriend(
                              friend,
                              (nameCounts[_displayName(friend).toLowerCase()] ??
                                      0) >
                                  1,
                            );

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedFriendIds.remove(friend.uid);
                                  } else {
                                    _selectedFriendIds.add(friend.uid);
                                  }
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
                                        (friend.displayName.isEmpty
                                                ? '?'
                                                : friend.displayName[0])
                                            .toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                              title: Text(
                                _displayName(friend),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: subtitle == null
                                  ? null
                                  : Text(
                                      subtitle,
                                      style: GoogleFonts.inter(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.62),
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
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
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
                    const VGap(AppLayout.lg),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _sendInvites,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _isSubmitting ? 'Sending...' : 'Send Invites',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

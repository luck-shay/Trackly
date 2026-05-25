import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/social_service.dart';
import '../services/database_service.dart';
import '../services/subscription_exceptions.dart';
import '../models/user_profile.dart';
import '../models/habit.dart';
import '../providers/friends_provider.dart';
import '../providers/subscription_provider.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<FriendsProvider>();
      _searchController.text = provider.lastQuery;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final social = SocialService();
    final db = DatabaseService();
    // final friendsProvider = context.read<FriendsProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Friends',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 24.0,
          bottom: 120.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar and Results
            Consumer<FriendsProvider>(
              builder: (context, provider, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: provider.hasActiveQuery
                              ? scheme.primary.withValues(alpha: 0.42)
                              : scheme.onSurface.withValues(alpha: 0.12),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.inter(color: scheme.onSurface),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: scheme.onSurface.withValues(alpha: 0.64),
                          ),
                          hintText: 'Search username',
                          hintStyle: GoogleFonts.inter(
                            color: scheme.onSurface.withValues(alpha: 0.62),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          suffixIcon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: provider.isSearching
                                ? const Padding(
                                    key: ValueKey('searching'),
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : provider.hasActiveQuery
                                    ? IconButton(
                                        key: const ValueKey('clear'),
                                        tooltip: 'Clear search',
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () {
                                          _searchController.clear();
                                          context
                                              .read<FriendsProvider>()
                                              .clearSearch();
                                        },
                                      )
                                    : Icon(
                                        key: const ValueKey('idle'),
                                        Icons.person_search_rounded,
                                        color: scheme.onSurface.withValues(
                                          alpha: 0.58,
                                        ),
                                      ),
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: context.read<FriendsProvider>().queueSearch,
                        onSubmitted: (value) =>
                            context.read<FriendsProvider>().searchUsers(value),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (provider.searchResults.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.resultTitle,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (provider.hasActiveQuery)
                            Text(
                              '${provider.searchResults.length} found',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(
                                  alpha: 0.58,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...provider.searchResults.map(
                        (user) => _FriendSearchTile(user: user),
                      ),
                      Divider(
                        color: scheme.onSurface.withValues(alpha: 0.12),
                        height: 48,
                      ),
                    ] else if (provider.hasSearched &&
                        provider.lastQuery.trim().isNotEmpty &&
                        !provider.isSearching) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No users found for "${provider.lastQuery.trim()}".',
                                style: GoogleFonts.inter(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ],
                );
              },
            ),

            // Goal Invites
            StreamBuilder<QuerySnapshot>(
              stream: social.streamHabitInvites(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final invites = snapshot.data!.docs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Habit Invites',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...invites.map((doc) {
                      final req = doc.data() as Map<String, dynamic>;
                      final fromUid = req['from'] as String;
                      final habitId = req['habitId'] as String;

                      return FutureBuilder(
                        future: Future.wait([
                          social.getUserProfile(fromUid),
                          db.getHabitById(habitId),
                        ]),
                        builder: (ctx, AsyncSnapshot<List<dynamic>> combinedSnapshot) {
                          if (!combinedSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final user =
                              combinedSnapshot.data![0] as UserProfile?;
                          final habit = combinedSnapshot.data![1] as Habit?;

                          if (user == null || habit == null) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.withValues(
                                  alpha: 0.15,
                                ),
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                              ),
                              title: Text(
                                'Unavailable invite',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'This invite is no longer valid. Remove it.',
                                style: GoogleFonts.inter(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.68,
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () async {
                                  try {
                                    await social.declineHabitInvite(doc.id);
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not remove invalid invite. Please try again.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.2),
                              child: const Icon(
                                Icons.track_changes_rounded,
                                color: Colors.black,
                              ),
                            ),
                            title: Text(
                              habit.title,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text(
                              'Invited by ${user.displayName}',
                              style: GoogleFonts.inter(
                                color: scheme.onSurface.withValues(alpha: 0.68),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF00E676),
                                  ),
                                  onPressed: () async {
                                    try {
                                      await social.acceptHabitInvite(
                                        doc.id,
                                        habitId,
                                      );
                                    } on UpgradeRequiredException catch (
                                      error
                                    ) {
                                      if (!context.mounted) return;
                                      try {
                                        await context
                                            .read<SubscriptionProvider>()
                                            .presentPaywall();
                                      } catch (_) {}
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(error.message)),
                                      );
                                    } catch (_) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not accept invite. Please try again.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    try {
                                      await social.declineHabitInvite(doc.id);
                                    } catch (_) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not decline invite. Please try again.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                    Divider(
                      color: scheme.onSurface.withValues(alpha: 0.12),
                      height: 48,
                    ),
                  ],
                );
              },
            ),

            // Pending Friend Requests
            StreamBuilder<QuerySnapshot>(
              stream: social.streamChallengeInvites(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final invites = snapshot.data!.docs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Challenge Invites',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...invites.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final fromUid = (data['from'] as String? ?? '').trim();
                      final groupId = (data['groupId'] as String? ?? '').trim();
                      final challengeId = (data['challengeId'] as String? ?? '')
                          .trim();
                      final challengeTitle =
                          (data['challengeTitle'] as String? ?? 'Challenge')
                              .trim();

                      return FutureBuilder<UserProfile?>(
                        future: social.getUserProfile(fromUid),
                        builder: (ctx, userSnapshot) {
                          final inviter = userSnapshot.data;
                          final inviterLabel =
                              inviter?.displayName.trim().isNotEmpty == true
                              ? inviter!.displayName
                              : 'A group member';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
                              child: const Icon(
                                Icons.flag_rounded,
                                color: Colors.black,
                              ),
                            ),
                            title: Text(
                              challengeTitle,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text(
                              'Invited by $inviterLabel',
                              style: GoogleFonts.inter(
                                color: scheme.onSurface.withValues(alpha: 0.68),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF00E676),
                                  ),
                                  onPressed: () async {
                                    try {
                                      await social.acceptChallengeInvite(
                                        inviteId: doc.id,
                                        groupId: groupId,
                                        challengeId: challengeId,
                                      );
                                    } catch (_) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not accept challenge invite. Please try again.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    try {
                                      await social.declineChallengeInvite(
                                        doc.id,
                                      );
                                    } catch (_) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not decline challenge invite. Please try again.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                    Divider(
                      color: scheme.onSurface.withValues(alpha: 0.12),
                      height: 48,
                    ),
                  ],
                );
              },
            ),

            // Pending Friend Requests
            StreamBuilder<QuerySnapshot>(
              stream: social.streamIncomingFriendRequests(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final requests = snapshot.data!.docs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Friend Requests',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...requests.map((doc) {
                      final req = doc.data() as Map<String, dynamic>;
                      final fromUid = req['from'];

                      return FutureBuilder<UserProfile?>(
                        future: social.getUserProfile(fromUid),
                        builder: (ctx, userSnapshot) {
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox.shrink();
                          }

                          if (!userSnapshot.hasData ||
                              userSnapshot.data == null) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.withValues(
                                  alpha: 0.15,
                                ),
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                              ),
                              title: Text(
                                'Unavailable request',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'This friend request is no longer valid. Remove it.',
                                style: GoogleFonts.inter(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.68,
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () async {
                                  try {
                                    await social.declineFriendRequest(doc.id);
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not remove invalid request. Please try again.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          }

                          final user = userSnapshot.data!;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.withValues(
                                alpha: 0.2,
                              ),
                              backgroundImage: user.photoUrl != null
                                  ? NetworkImage(user.photoUrl!)
                                  : null,
                              child: user.photoUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.displayName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text('Wants to be friends'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF00E676),
                                  ),
                                  onPressed: () async {
                                    try {
                                      await social.acceptFriendRequest(
                                        doc.id,
                                        fromUid,
                                      );
                                    } catch (_) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not accept request. Please try again.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    try {
                                      await social.declineFriendRequest(doc.id);
                                    } catch (_) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not decline request. Please try again.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                    Divider(
                      color: scheme.onSurface.withValues(alpha: 0.12),
                      height: 48,
                    ),
                  ],
                );
              },
            ),

            // Friends List
            Text(
              'My Friends',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<UserProfile>>(
              stream: social.streamFriends(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final friends = snapshot.data ?? [];

                if (friends.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Text(
                        'No friends yet.\nSearch for them above!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: scheme.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ),
                  ).animate().fade();
                }

                return Column(
                  children: [
                    ...friends.map(
                      (friend) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          backgroundImage: friend.photoUrl != null
                              ? NetworkImage(friend.photoUrl!)
                              : null,
                          child: friend.photoUrl == null
                              ? Icon(Icons.person, color: scheme.onPrimary)
                              : null,
                        ),
                        title: Text(
                          friend.displayName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          friend.username != null
                              ? '@${friend.username}'
                              : friend.email,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.68),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FriendProfileScreen(friend: friend),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ).animate().fade().slideY(begin: 0.1);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendSearchTile extends StatelessWidget {
  final UserProfile user;

  const _FriendSearchTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final status = provider.statusFor(user.uid);
    final isBusy = provider.isBusy(user.uid);
    final username = user.username?.trim() ?? '';
    final subtitle = username.isNotEmpty ? '@$username' : user.email;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: scheme.primary.withValues(alpha: 0.18),
        backgroundImage: user.photoUrl != null
            ? NetworkImage(user.photoUrl!)
            : null,
        child: user.photoUrl == null
            ? Icon(Icons.person_rounded, color: scheme.onPrimary)
            : null,
      ),
      title: Text(
        user.displayName.trim().isNotEmpty ? user.displayName : 'Trackly user',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: scheme.onSurface.withValues(alpha: 0.68),
        ),
      ),
      trailing: _FriendSearchAction(
        isBusy: isBusy,
        status: status,
        onPressed:
            status == FriendRelationshipStatus.friend ||
                status == FriendRelationshipStatus.outgoingPending ||
                isBusy
            ? null
            : () async {
                try {
                  final result = await context
                      .read<FriendsProvider>()
                      .sendFriendRequest(user);
                  if (!context.mounted) return;

                  final message = switch (result) {
                    FriendRequestResult.sent =>
                      'Friend request sent to ${_displayName(user)}',
                    FriendRequestResult.acceptedIncoming =>
                      'You and ${_displayName(user)} are now friends.',
                    FriendRequestResult.alreadyFriends =>
                      'You are already friends with ${_displayName(user)}.',
                    FriendRequestResult.alreadyPending =>
                      'Friend request is already pending.',
                    FriendRequestResult.unavailable =>
                      'Could not send request. Please try again.',
                  };

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not send request. Please try again.',
                      ),
                    ),
                  );
                }
              },
      ),
    );
  }

  String _displayName(UserProfile user) {
    final name = user.displayName.trim();
    if (name.isNotEmpty) return name;
    final username = user.username?.trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    return 'this user';
  }
}

class _FriendSearchAction extends StatelessWidget {
  final FriendRelationshipStatus status;
  final bool isBusy;
  final VoidCallback? onPressed;

  const _FriendSearchAction({
    required this.status,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const SizedBox.square(
        dimension: 40,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final config = switch (status) {
      FriendRelationshipStatus.friend => (
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF00C853),
        tooltip: 'Friends',
      ),
      FriendRelationshipStatus.outgoingPending => (
        icon: Icons.schedule_rounded,
        color: Colors.amber,
        tooltip: 'Request pending',
      ),
      FriendRelationshipStatus.incomingPending => (
        icon: Icons.person_add_alt_1_rounded,
        color: const Color(0xFF00E676),
        tooltip: 'Accept request',
      ),
      FriendRelationshipStatus.none => (
        icon: Icons.person_add_rounded,
        color: const Color(0xFF00E676),
        tooltip: 'Send request',
      ),
    };

    return IconButton(
      tooltip: config.tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: config.color.withValues(alpha: 0.12),
        disabledBackgroundColor: config.color.withValues(alpha: 0.12),
        fixedSize: const Size.square(40),
      ),
      icon: Icon(
        config.icon,
        color: onPressed == null ? config.color : config.color,
      ),
    );
  }
}

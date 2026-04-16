import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/social_service.dart';
import '../services/database_service.dart';
import '../models/user_profile.dart';
import '../models/habit.dart';
import '../providers/friends_provider.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final social = SocialService();
    final db = DatabaseService();
    final friendsProvider = context.watch<FriendsProvider>();

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
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: TextFormField(
                initialValue: friendsProvider.lastQuery,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by @username...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  suffixIcon: const Icon(Icons.search, color: Colors.white70),
                ),
                onFieldSubmitted: (val) => context.read<FriendsProvider>().searchUsers(val),
              ),
            ),
            const SizedBox(height: 24),

            if (friendsProvider.isSearching)
              const Center(child: CircularProgressIndicator())
            else if (friendsProvider.searchResults.isNotEmpty) ...[
              Text(
                'Search Results',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...friendsProvider.searchResults.map(
                    (user) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        user.displayName,
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        user.username != null
                            ? '@${user.username}'
                            : user.email,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.person_add_rounded,
                          color: Color(0xFF00E676),
                        ),
                        onPressed: () async {
                          await social.sendFriendRequest(user.uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Friend request sent to ${user.displayName}',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
              const Divider(color: Colors.white10, height: 48),
            ] else if (friendsProvider.hasSearched && friendsProvider.lastQuery.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No user found with the exact username "${friendsProvider.lastQuery}".',
                        style: GoogleFonts.inter(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

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
                        builder:
                            (
                              ctx,
                              AsyncSnapshot<List<dynamic>> combinedSnapshot,
                            ) {
                              if (!combinedSnapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              final user =
                                  combinedSnapshot.data![0] as UserProfile?;
                              final habit = combinedSnapshot.data![1] as Habit?;

                              if (user == null || habit == null) {
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.red.withValues(alpha: 0.15),
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
                                      color: Colors.grey,
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
                                    color: Colors.white,
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
                                  style: GoogleFonts.inter(color: Colors.grey),
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
                                          await social.declineHabitInvite(
                                            doc.id,
                                          );
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
                    const Divider(color: Colors.white10, height: 48),
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
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox.shrink();
                          }

                          if (!userSnapshot.hasData || userSnapshot.data == null) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.withValues(alpha: 0.15),
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
                                  color: Colors.grey,
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
                              backgroundColor: Colors.orange.withValues(alpha: 0.2),
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
                    const Divider(color: Colors.white10, height: 48),
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
                        style: GoogleFonts.inter(color: Colors.grey[500]),
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
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          title: Text(
                            friend.displayName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            friend.username != null
                                ? '@${friend.username}'
                                : friend.email,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey,
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

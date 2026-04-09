import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/social_service.dart';
import '../models/user_profile.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final SocialService _social = SocialService();
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  void _searchUsers() async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });
    final email = _searchController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }
    final results = await _social.searchUsersByEmail(email);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friends', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by exact email...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white70),
                    onPressed: _searchUsers,
                  ),
                ),
                onSubmitted: (_) => _searchUsers(),
              ),
            ),
            const SizedBox(height: 24),

            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else if (_searchResults.isNotEmpty) ...[
              Text('Search Results', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ..._searchResults.map((user) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                title: Text(user.displayName, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                subtitle: Text(user.email, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                trailing: IconButton(
                  icon: const Icon(Icons.person_add_rounded, color: Color(0xFF00E676)),
                  onPressed: () async {
                    await _social.sendFriendRequest(user.uid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Friend request sent to ${user.displayName}')),
                      );
                    }
                  },
                ),
              )).toList(),
              const Divider(color: Colors.white10, height: 48),
            ] else if (_hasSearched && _searchController.text.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No user found globally with the exact email "${_searchController.text}".',
                        style: GoogleFonts.inter(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Pending Requests
            StreamBuilder<QuerySnapshot>(
              stream: _social.streamIncomingFriendRequests(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final requests = snapshot.data!.docs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Friend Requests', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ...requests.map((doc) {
                      final req = doc.data() as Map<String, dynamic>;
                      final fromUid = req['from'];
                      
                      return FutureBuilder<UserProfile?>(
                        future: _social.getUserProfile(fromUid),
                        builder: (ctx, userSnapshot) {
                          if (!userSnapshot.hasData) return const SizedBox.shrink();
                          final user = userSnapshot.data!;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.withOpacity(0.2),
                              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                              child: user.photoUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                            ),
                            title: Text(user.displayName, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Wants to be friends'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Color(0xFF00E676)),
                                  onPressed: () => _social.acceptFriendRequest(doc.id, fromUid),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                                  onPressed: () => _social.declineFriendRequest(doc.id),
                                ),
                              ],
                            ),
                          );
                        }
                      );
                    }).toList(),
                    const Divider(color: Colors.white10, height: 48),
                  ],
                );
              }
            ),

            // Friends List
            Text('My Friends', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            StreamBuilder<List<UserProfile>>(
              stream: _social.streamFriends(),
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
                  children: friends.map((friend) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
                      child: friend.photoUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    title: Text(friend.displayName, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    subtitle: Text(friend.email, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => FriendProfileScreen(friend: friend)),
                      );
                    },
                  )).toList(),
                ).animate().fade().slideY(begin: 0.1);
              }
            ),
          ],
        ),
      ),
    );
  }
}

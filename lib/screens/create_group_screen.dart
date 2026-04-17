import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../services/group_service.dart';
import '../services/social_service.dart';
import '../theme/app_layout.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedFriendIds = <String>{};

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final group = await GroupService().createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      final social = SocialService();
      for (final friendId in _selectedFriendIds) {
        await social.sendGroupInvite(
          groupId: group.id,
          groupName: group.name,
          toUserId: friendId,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, {
        'group': group,
        'targetTab': 2,
        'snackbarMessage': 'Group created: ${group.name}',
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not create group. ${error.toString().split('\n').first}',
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Group',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: AppLayout.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group becomes its own workspace. Add as many tasks as you want inside it.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
              const VGap(AppLayout.lg),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Group name',
                  hintText: 'e.g. Home Members',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name.';
                  }
                  return null;
                },
              ),
              const VGap(AppLayout.md),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What is this group for?',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const VGap(AppLayout.xl),
              Text(
                'Invite friends (optional)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[300],
                ),
              ),
              const VGap(AppLayout.sm),
              StreamBuilder<List<UserProfile>>(
                stream: SocialService().streamFriends(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final friends = snapshot.data!;
                  if (friends.isEmpty) {
                    return Text(
                      'No friends found. You can invite members later from the group page.',
                      style: GoogleFonts.inter(color: Colors.grey[500]),
                    );
                  }

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: friends.map((friend) {
                      final isSelected = _selectedFriendIds.contains(friend.uid);
                      return FilterChip(
                        label: Text(friend.displayName),
                        selected: isSelected,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        checkmarkColor: Colors.black,
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedFriendIds.add(friend.uid);
                            } else {
                              _selectedFriendIds.remove(friend.uid);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              const VGap(AppLayout.xxl),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isSaving ? 'Creating...' : 'Create Group',
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
      ),
    );
  }
}

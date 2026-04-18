import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_mode_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  Future<void> _changeProfilePhoto(BuildContext context) async {
    final error = await context.read<ProfileProvider>().uploadProfilePicture();
    if (!context.mounted || error == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _openProfilePhotoPreview(
    BuildContext context,
    String photoUrl,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) {
        return GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: Hero(
                        tag: 'profile-photo-preview',
                        child: Image.network(
                          photoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image_rounded,
                            size: 72,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ProfileProvider>().cancelEditing();
    });
  }

  @override
  void dispose() {
    // Ensure profile always reopens in view mode.
    context.read<ProfileProvider>().cancelEditing();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final themeModeProvider = context.watch<ThemeModeProvider>();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          context.read<ProfileProvider>().cancelEditing();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: Text(
            'Profile',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData ||
                !snapshot.data!.exists ||
                snapshot.data!.data() == null) {
              return const Center(child: Text('Failed to load profile.'));
            }

            final profile = UserProfile.fromMap(
              snapshot.data!.data() as Map<String, dynamic>,
            );

            if (!profileProvider.isEditing) {
              _nameController.text = profile.displayName;
              _usernameController.text = profile.username ?? '';
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: profileProvider.isUploadingPicture
                              ? null
                              : () async {
                                  if (profileProvider.isEditing) {
                                    await _changeProfilePhoto(context);
                                    return;
                                  }
                                  final photoUrl = profile.photoUrl?.trim();
                                  if (photoUrl == null || photoUrl.isEmpty) {
                                    return;
                                  }
                                  await _openProfilePhotoPreview(
                                    context,
                                    photoUrl,
                                  );
                                },
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            backgroundImage: profile.photoUrl != null
                                ? NetworkImage(profile.photoUrl!)
                                : null,
                            child: profileProvider.isUploadingPicture
                                ? const CircularProgressIndicator()
                                : (profile.photoUrl == null
                                      ? Icon(
                                          Icons.person,
                                          size: 56,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        )
                                      : null),
                          ),
                        ),
                        if (profileProvider.isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: profileProvider.isUploadingPicture
                                    ? null
                                    : () => _changeProfilePhoto(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    size: 16,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    if (!profileProvider.isEditing) ...[
                      Text(
                        profile.displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profile.username != null
                            ? '@${profile.username}'
                            : 'No username set',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profile.email,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit, size: 20),
                        label: const Text('Edit Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                        onPressed: () {
                          context.read<ProfileProvider>().startEditing();
                        },
                      ),
                    ] else ...[
                      _buildTextField(
                        context,
                        'Display Name',
                        _nameController,
                        Icons.badge_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        context,
                        'Username',
                        _usernameController,
                        Icons.alternate_email_rounded,
                      ),
                      if (profileProvider.usernameError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            profileProvider.usernameError!,
                            style: GoogleFonts.inter(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                      if (profileProvider.isCheckingUsername)
                        const CircularProgressIndicator()
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                context.read<ProfileProvider>().cancelEditing();
                              },
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                final success = await context
                                    .read<ProfileProvider>()
                                    .saveProfile(
                                      _nameController.text,
                                      _usernameController.text,
                                    );
                                if (success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Profile updated successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                'Save',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],

                    if (!profileProvider.isEditing) ...[
                      const SizedBox(height: 48),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: SwitchListTile.adaptive(
                          value: themeModeProvider.isDarkMode,
                          onChanged: (value) {
                            context
                                .read<ThemeModeProvider>()
                                .setDarkModeEnabled(value);
                          },
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Dark Mode',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            themeModeProvider.isDarkMode
                                ? 'Using dark appearance'
                                : 'Using light appearance',
                            style: GoogleFonts.inter(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          secondary: Icon(
                            themeModeProvider.isDarkMode
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          activeThumbColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      ),
                    ],
                    if (!profileProvider.isEditing) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade900.withValues(
                            alpha: 0.3,
                          ),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          await AuthService().signOut();
                          if (context.mounted) {
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    String label,
    TextEditingController controller,
    IconData icon, {
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 18),
          decoration: InputDecoration(
            prefixText: prefix,
            prefixStyle: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 18,
            ),
            prefixIcon: Icon(icon, color: Colors.grey[600]),
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
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';
import '../models/subscription_state.dart';
import '../providers/profile_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/theme_mode_provider.dart';
import 'analytics_screen.dart';
import 'insights_screen.dart';
import 'paywall_screen.dart';
import '../widgets/pro_badge_avatar.dart';
import '../widgets/appearance_selector.dart';
import '../theme/color_scheme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  ProfileProvider? _profileProvider;
  Future<void>? _profileBootstrapFuture;

  Future<void> _ensureProfileDocumentExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    await AuthService().syncUserToFirestore(user);
  }

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
                          errorBuilder: (_, _, _) => Icon(
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profileProvider ??= context.read<ProfileProvider>();
  }

  @override
  void dispose() {
    // Ensure profile always reopens in view mode.
    _profileProvider?.resetEditingState();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final themeModeProvider = context.watch<ThemeModeProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final subscriptionState = subscriptionProvider.state;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return PopScope(
      canPop: !profileProvider.isEditing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && profileProvider.isEditing) {
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
        body: userId.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<DocumentSnapshot>(
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
              _profileBootstrapFuture ??= _ensureProfileDocumentExists();

              return FutureBuilder<void>(
                future: _profileBootstrapFuture,
                builder: (context, bootstrapSnapshot) {
                  if (bootstrapSnapshot.connectionState !=
                      ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (bootstrapSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_off_rounded,
                              size: 56,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Setting up your profile is taking a moment.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _profileBootstrapFuture = null;
                                });
                              },
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return const Center(child: CircularProgressIndicator());
                },
              );
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
                          child: ProBadgeAvatar(
                            isPro: subscriptionProvider.hasProAccess,
                            radius: 56,
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
                      const SizedBox(height: 24),
                      _ActionTile(
                        icon: Icons.palette_rounded,
                        title: 'Appearance',
                        subtitle: themeModeProvider.themeMode == ThemeMode.system
                            ? 'Matches your device'
                            : (themeModeProvider.themeMode == ThemeMode.dark ? 'Dark' : 'Light'),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            builder: (_) => const AppearanceSelector(isBottomSheet: true),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _ProSection(
                        state: subscriptionState,
                        subscriptionProvider: subscriptionProvider,
                      ),
                    ],
                    if (!profileProvider.isEditing) ...[
                      const SizedBox(height: 48),
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

// ── Pro Section ───────────────────────────────────────────────────────────────

class _ProSection extends StatelessWidget {
  final SubscriptionState state;
  final SubscriptionProvider subscriptionProvider;

  const _ProSection({required this.state, required this.subscriptionProvider});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasProAccess = state.hasAccess;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasProAccess
              ? AppTheme.proAmber.withValues(alpha: 0.4)
              : scheme.onSurface.withValues(alpha: 0.08),
          width: hasProAccess ? 1.5 : 1,
        ),
        boxShadow: hasProAccess
            ? [
                BoxShadow(
                  color: AppTheme.proAmber.withValues(alpha: isDark ? 0.1 : 0.06),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Plan badge ───────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: hasProAccess ? AppTheme.proBadgeGradient : null,
                  color: hasProAccess ? null : scheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasProAccess) ...[
                      const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.black),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      hasProAccess ? 'TRACKLY PRO' : 'FREE TIER',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: hasProAccess
                            ? Colors.black
                            : scheme.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (state.isTrialActive)
                Text(
                  'Trial Active',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.proAmber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Current plan label ──────────────────────────────────
          Text(
            hasProAccess ? 'Pro Membership Unlocked' : 'Supercharge Trackly with Pro',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasProAccess
                ? 'Enjoy unlimited heatmaps, AI coach recommendations, private groups, and priority analytics.'
                : 'Unlock AI habit coaching, completion heatmaps, unlimited group collaboration, and custom widgets.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: scheme.onSurface.withValues(alpha: 0.6),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          // ── Quick access buttons (Pro users) ────────────────────
          if (hasProAccess) ...[
            _ActionTile(
              icon: Icons.insights_rounded,
              title: 'Analytics',
              subtitle: 'View your habit analytics',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.auto_awesome_rounded,
              title: 'Insights',
              subtitle: 'Personalized habit insights',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InsightsScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // ── Error message ───────────────────────────────────────
          if (state.errorMessage != null &&
              '${state.errorMessage}'.isNotEmpty) ...[
            Text(
              '${state.errorMessage}',
              style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],

          // ── Actions ─────────────────────────────────────────────
          if (!hasProAccess) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PaywallScreen(),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Upgrade to Pro',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (hasProAccess)
            _ActionTile(
              icon: Icons.credit_card_rounded,
              title: 'Manage Subscription',
              subtitle: 'View or cancel your subscription',
              onTap: () async {
                try {
                  await subscriptionProvider.openCustomerCenter();
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not open subscription management. ${error.toString().split('\n').first}',
                      ),
                    ),
                  );
                }
              },
            ),

          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      try {
                        await subscriptionProvider.restore();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Purchases restored.')),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not restore. ${error.toString().split('\n').first}',
                            ),
                          ),
                        );
                      }
                    },
              child: Text(
                'Restore Purchases',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: scheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        title: Text('Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
             return const Center(child: Text('Failed to load profile.'));
          }

          final profile = UserProfile.fromMap(snapshot.data!.data() as Map<String, dynamic>);
          
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
                CircleAvatar(
                  radius: 56,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.person, size: 56, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 32),
                
                if (!profileProvider.isEditing) ...[
                  Text(
                    profile.displayName,
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.username != null ? '@${profile.username}' : 'No username set',
                    style: GoogleFonts.inter(fontSize: 18, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.email,
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit, size: 20),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: Colors.white10),
                    ),
                    onPressed: () {
                      context.read<ProfileProvider>().startEditing();
                    },
                  ),
                ] else ...[
                  _buildTextField(context, 'Display Name', _nameController, Icons.badge_rounded),
                  const SizedBox(height: 16),
                  _buildTextField(context, 'Username', _usernameController, Icons.alternate_email_rounded, prefix: '@'),
                  if (profileProvider.usernameError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(profileProvider.usernameError!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13)),
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
                          child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                              final success = await context.read<ProfileProvider>().saveProfile(
                                  _nameController.text, 
                                  _usernameController.text
                              );
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
                                );
                              }
                          },
                          child: Text('Save', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                ],
                
                const SizedBox(height: 64),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900.withOpacity(0.3),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    await AuthService().signOut();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
                const SizedBox(height: 120), 
              ],
            ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildTextField(BuildContext context, String label, TextEditingController controller, IconData icon, {String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 18),
          decoration: InputDecoration(
            prefixText: prefix,
            prefixStyle: GoogleFonts.inter(color: Theme.of(context).colorScheme.primary, fontSize: 18),
            prefixIcon: Icon(icon, color: Colors.grey[600]),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
          ),
        ),
      ],
    );
  }
}

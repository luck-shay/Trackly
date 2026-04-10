import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SocialService _social = SocialService();
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  bool _isEditing = false;
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  
  bool _isCheckingUsername = false;
  String? _usernameError;
  
  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    final newUsername = _usernameController.text.trim().toLowerCase();
    
    if (newName.isEmpty) {
      setState(() => _usernameError = 'Name cannot be empty.');
      return;
    }
    if (newUsername.isEmpty) {
      setState(() => _usernameError = 'Username cannot be empty.');
      return;
    }
    
    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    final isAvailable = await _social.isUsernameAvailable(newUsername);
    if (!isAvailable) {
      setState(() {
         _usernameError = 'Username is already taken.';
         _isCheckingUsername = false;
      });
      return;
    }

    await _social.updateProfile(displayName: newName, username: newUsername);
    
    setState(() {
       _isCheckingUsername = false;
       _isEditing = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Hidden back button for main tab
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
          
          if (!_isEditing) {
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
                
                if (!_isEditing) ...[
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
                      setState(() => _isEditing = true);
                    },
                  ),
                ] else ...[
                  _buildTextField('Display Name', _nameController, Icons.badge_rounded),
                  const SizedBox(height: 16),
                  _buildTextField('Username', _usernameController, Icons.alternate_email_rounded, prefix: '@'),
                  if (_usernameError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_usernameError!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13)),
                    ),
                  const SizedBox(height: 32),
                  if (_isCheckingUsername)
                    const CircularProgressIndicator()
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _usernameError = null;
                            });
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
                          onPressed: _saveProfile,
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
                const SizedBox(height: 120), // Padding for Nav Bar
              ],
            ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {String? prefix}) {
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

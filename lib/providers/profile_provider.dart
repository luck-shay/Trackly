import 'package:flutter/foundation.dart';
import '../services/social_service.dart';

class ProfileProvider extends ChangeNotifier {
  final SocialService _social = SocialService();

  bool _isEditing = false;
  bool _isCheckingUsername = false;
  String? _usernameError;

  bool get isEditing => _isEditing;
  bool get isCheckingUsername => _isCheckingUsername;
  String? get usernameError => _usernameError;

  void startEditing() {
    _isEditing = true;
    notifyListeners();
  }

  void cancelEditing() {
    _isEditing = false;
    _usernameError = null;
    notifyListeners();
  }

  Future<bool> saveProfile(String newName, String newUsername) async {
    newUsername = newUsername.trim().toLowerCase();
    newName = newName.trim();

    if (newName.isEmpty) {
      _usernameError = 'Name cannot be empty.';
      notifyListeners();
      return false;
    }
    if (newUsername.isEmpty) {
      _usernameError = 'Username cannot be empty.';
      notifyListeners();
      return false;
    }

    _isCheckingUsername = true;
    _usernameError = null;
    notifyListeners();

    final isAvailable = await _social.isUsernameAvailable(newUsername);
    if (!isAvailable) {
      _usernameError = 'Username is already taken.';
      _isCheckingUsername = false;
      notifyListeners();
      return false;
    }

    await _social.updateProfile(displayName: newName, username: newUsername);
    
    _isCheckingUsername = false;
    _isEditing = false;
    notifyListeners();
    return true;
  }
}

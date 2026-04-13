import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

    try {
      final isAvailable = await _social.isUsernameAvailable(newUsername);
      if (!isAvailable) {
        _usernameError = 'Username is already taken.';
        return false;
      }

      await _social.updateProfile(displayName: newName, username: newUsername);
      _isEditing = false;
      return true;
    } catch (_) {
      _usernameError = 'Could not save your profile. Please try again.';
      return false;
    } finally {
      _isCheckingUsername = false;
      notifyListeners();
    }
  }

  bool _isUploadingPicture = false;
  bool get isUploadingPicture => _isUploadingPicture;

  Future<String?> uploadProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (pickedFile == null) return null;

    if (_social.userId.isEmpty) {
      return 'You must be signed in to upload a photo.';
    }

    _isUploadingPicture = true;
    notifyListeners();

    try {
      final file = File(pickedFile.path);
      if (!await file.exists()) {
        return 'Selected photo could not be read.';
      }

      final bytes = await file.length();
      if (bytes == 0) {
        return 'Selected photo is empty.';
      }
      if (bytes > 10 * 1024 * 1024) {
        return 'Please select an image smaller than 10MB.';
      }

      final lowerPath = pickedFile.path.toLowerCase();
      String contentType;
      if (lowerPath.endsWith('.png')) {
        contentType = 'image/png';
      } else if (lowerPath.endsWith('.webp')) {
        contentType = 'image/webp';
      } else if (lowerPath.endsWith('.heic') || lowerPath.endsWith('.heif')) {
        contentType = 'image/heic';
      } else {
        contentType = 'image/jpeg';
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${_social.userId}.jpg');

      await storageRef.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await storageRef.getDownloadURL();

      await _social.updateProfile(photoUrl: downloadUrl);
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading profile picture: $e');
      }
      return 'Could not upload profile photo. Please try again.';
    } finally {
      _isUploadingPicture = false;
      notifyListeners();
    }
  }
}

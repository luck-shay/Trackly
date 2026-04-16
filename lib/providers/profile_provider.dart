import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/social_service.dart';

class _StorageTarget {
  final String bucketName;
  final FirebaseStorage storage;

  const _StorageTarget({required this.bucketName, required this.storage});
}

class ProfileProvider extends ChangeNotifier {
  final SocialService _social = SocialService();

  static const int _maxProfileImageBytes = 10 * 1024 * 1024;

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

  List<_StorageTarget> _candidateStorageTargets() {
    final targets = <_StorageTarget>[];
    final seen = <String>{};

    void addBucket(String bucketName) {
      final clean = bucketName.trim().replaceFirst('gs://', '');
      if (clean.isEmpty || seen.contains(clean)) {
        return;
      }
      seen.add(clean);
      targets.add(
        _StorageTarget(
          bucketName: clean,
          storage: FirebaseStorage.instanceFor(bucket: 'gs://$clean'),
        ),
      );
    }

    final bucket = Firebase.app().options.storageBucket?.trim() ?? '';
    if (bucket.isNotEmpty) {
      addBucket(bucket);
      if (bucket.endsWith('.firebasestorage.app')) {
        addBucket(bucket.replaceFirst('.firebasestorage.app', '.appspot.com'));
      } else if (bucket.endsWith('.appspot.com')) {
        addBucket(bucket.replaceFirst('.appspot.com', '.firebasestorage.app'));
      }
    }

    if (targets.isEmpty) {
      targets.add(
        _StorageTarget(
          bucketName: FirebaseStorage.instance.app.options.storageBucket ?? 'unknown-bucket',
          storage: FirebaseStorage.instance,
        ),
      );
    }

    return targets;
  }

  Future<String?> uploadProfilePicture() async {
    final picker = ImagePicker();
    XFile? pickedFile;

    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('ProfileProvider: Image pick failed: ${e.code} ${e.message}');
      }
      return 'Photo access failed. Please allow photo permission in Settings.';
    }

    if (pickedFile == null) return null;

    if (_social.userId.isEmpty) {
      return 'You must be signed in to upload a photo.';
    }

    _isUploadingPicture = true;
    notifyListeners();

    try {
      final bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) {
        return 'Selected photo is empty.';
      }
      if (bytes.lengthInBytes > _maxProfileImageBytes) {
        return 'Please select an image smaller than 10MB.';
      }

      final normalizedMime = (pickedFile.mimeType ?? '').toLowerCase();
      final contentType = normalizedMime.startsWith('image/')
          ? normalizedMime
          : 'image/jpeg';

      final storageCandidates = _candidateStorageTargets();
      FirebaseException? lastStorageError;

      for (final target in storageCandidates) {
        try {
          final storageRef = target.storage
              .ref()
              .child('profile_pictures')
              .child('${_social.userId}.jpg');

          final downloadToken =
              '${DateTime.now().microsecondsSinceEpoch}-${_social.userId}';

          final uploadSnapshot = await storageRef.putData(
            bytes,
            SettableMetadata(
              contentType: contentType,
              customMetadata: {
                'firebaseStorageDownloadTokens': downloadToken,
              },
            ),
          );

          String? downloadUrl;
          FirebaseException? lastUrlError;

          for (var attempt = 0; attempt < 5; attempt++) {
            try {
              downloadUrl = await uploadSnapshot.ref.getDownloadURL();
              break;
            } on FirebaseException catch (e) {
              lastUrlError = e;
              if (e.code != 'object-not-found') {
                rethrow;
              }
              // Some runs return object-not-found immediately after upload;
              // retry once against the uploaded ref.
              await Future<void>.delayed(
                Duration(milliseconds: 300 * (attempt + 1)),
              );
            }
          }

          if ((downloadUrl == null || downloadUrl.isEmpty) &&
              lastUrlError?.code == 'object-not-found') {
            final encodedPath = Uri.encodeComponent(uploadSnapshot.ref.fullPath);
            downloadUrl =
                'https://firebasestorage.googleapis.com/v0/b/${target.bucketName}/o/$encodedPath?alt=media&token=$downloadToken';
          }

          if (downloadUrl == null || downloadUrl.isEmpty) {
            throw lastUrlError ?? FirebaseException(
              plugin: 'firebase_storage',
              code: 'object-not-found',
              message: 'Uploaded object could not be resolved for URL.',
            );
          }

          await _social.updateProfile(photoUrl: downloadUrl);
          return null;
        } on FirebaseException catch (e) {
          lastStorageError = e;
          if (kDebugMode) {
            debugPrint(
              'ProfileProvider: Bucket attempt failed (${target.bucketName}): ${e.code} ${e.message}',
            );
          }
          continue;
        }
      }

      throw lastStorageError ?? FirebaseException(
        plugin: 'firebase_storage',
        code: 'unknown',
        message: 'Profile upload failed for all configured buckets.',
      );
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ProfileProvider: Firebase upload failed: ${e.code} ${e.message}',
        );
      }

      if (e.code == 'permission-denied') {
        return 'Upload blocked by Firebase rules (permission-denied).';
      }
      if (e.code == 'unauthenticated') {
        return 'Session expired. Please sign in again.';
      }

      final message = e.message?.trim();
      if (message != null && message.isNotEmpty) {
        return 'Upload failed: $message';
      }
      return 'Upload failed (${e.code}).';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfileProvider: Unexpected upload error: $e');
      }
      return 'Could not upload profile photo. Please try again.';
    } finally {
      _isUploadingPicture = false;
      notifyListeners();
    }
  }
}

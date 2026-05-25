import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarCacheState {
  final String? photoUrl;
  final Uint8List? bytes;

  const AvatarCacheState({this.photoUrl, this.bytes});
}

class AvatarCache {
  static final ValueNotifier<AvatarCacheState> notifier =
      ValueNotifier(const AvatarCacheState());

  static String _photoUrlKey(String uid) => 'avatar_cache_url_$uid';
  static String _bytesKey(String uid) => 'avatar_cache_bytes_$uid';

  static Future<void> initialize(String uid) async {
    final clean = uid.trim();
    if (clean.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_photoUrlKey(clean));
    final encoded = prefs.getString(_bytesKey(clean));
    if (encoded == null || encoded.isEmpty) {
      notifier.value = AvatarCacheState(photoUrl: url);
      return;
    }

    try {
      final bytes = base64Decode(encoded);
      notifier.value = AvatarCacheState(photoUrl: url, bytes: bytes);
    } catch (_) {
      notifier.value = AvatarCacheState(photoUrl: url);
    }
  }

  static Future<void> updateFromNetwork(String uid, String photoUrl) async {
    final clean = uid.trim();
    final trimmedUrl = photoUrl.trim();
    if (clean.isEmpty || trimmedUrl.isEmpty) {
      return;
    }

    final current = notifier.value;
    if (current.photoUrl == trimmedUrl && current.bytes != null) {
      return;
    }

    try {
      final data = await NetworkAssetBundle(Uri.parse(trimmedUrl)).load('');
      final bytes = data.buffer.asUint8List();
      if (bytes.lengthInBytes > 512 * 1024) {
        notifier.value = AvatarCacheState(photoUrl: trimmedUrl);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_photoUrlKey(clean), trimmedUrl);
      await prefs.setString(_bytesKey(clean), base64Encode(bytes));
      notifier.value = AvatarCacheState(photoUrl: trimmedUrl, bytes: bytes);
    } catch (_) {
      notifier.value = AvatarCacheState(photoUrl: trimmedUrl);
    }
  }

  static Future<void> clear(String uid) async {
    final clean = uid.trim();
    if (clean.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_photoUrlKey(clean));
    await prefs.remove(_bytesKey(clean));
    notifier.value = const AvatarCacheState();
  }
}

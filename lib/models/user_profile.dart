class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? username;
  final String? photoUrl;
  final List<String> friends;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.username,
    this.photoUrl,
    List<String>? friends,
  }) : friends = friends ?? [];

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'username': username,
      'photoUrl': photoUrl,
      'friends': friends,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      username: map['username'],
      photoUrl: map['photoUrl'],
      friends: List<String>.from(map['friends'] ?? []),
    );
  }
}

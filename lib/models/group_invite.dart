import 'package:cloud_firestore/cloud_firestore.dart';

class GroupInvite {
  final String id;
  final String groupId;
  final String? groupName;
  final String fromUserId;
  final String toUserId;
  final String status;
  final DateTime? createdAt;

  GroupInvite({
    required this.id,
    required this.groupId,
    this.groupName,
    required this.fromUserId,
    required this.toUserId,
    this.status = 'pending',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'from': fromUserId,
      'to': toUserId,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory GroupInvite.fromMap(Map<String, dynamic> map, {String? id}) {
    return GroupInvite(
      id: id ?? map['id'] ?? '',
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] as String?,
      fromUserId: map['from'] ?? '',
      toUserId: map['to'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] != null
                ? DateTime.tryParse(map['createdAt'].toString())
                : null),
    );
  }
}

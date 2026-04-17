import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final DateTime createdAt;
  final List<String> memberIds;

  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.createdAt,
    required this.memberIds,
  });

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    DateTime? createdAt,
    List<String>? memberIds,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      memberIds: memberIds ?? this.memberIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
      'memberIds': memberIds,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic raw) {
      if (raw is DateTime) {
        return raw;
      }
      if (raw is Timestamp) {
        return raw.toDate();
      }
      if (raw is String) {
        return DateTime.tryParse(raw);
      }
      return null;
    }

    return Group(
      id: id ?? (map['id'] as String? ?? ''),
      name: (map['name'] as String? ?? '').trim(),
      description: (map['description'] as String? ?? '').trim(),
      ownerId: (map['ownerId'] as String? ?? '').trim(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      memberIds: List<String>.from(map['memberIds'] ?? const <String>[]),
    );
  }
}

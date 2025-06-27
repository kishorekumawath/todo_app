

import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final String ownerId;
  final String ownerEmail;
  final List<String> sharedWith;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastModifiedBy;
  final String priority; // low, medium, high
  final DateTime? dueDate;
  final List<String> tags;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.ownerId,
    required this.ownerEmail,
    required this.sharedWith,
    required this.createdAt,
    required this.updatedAt,
    required this.lastModifiedBy,
    this.priority = 'medium',
    this.dueDate,
    this.tags = const [],
  });

  // Convert from Firestore document
  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      ownerId: data['ownerId'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      sharedWith: List<String>.from(data['sharedWith'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      lastModifiedBy: data['lastModifiedBy'] ?? '',
      priority: data['priority'] ?? 'medium',
      dueDate: data['dueDate'] != null ? (data['dueDate'] as Timestamp).toDate() : null,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'ownerId': ownerId,
      'ownerEmail': ownerEmail,
      'sharedWith': sharedWith,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastModifiedBy': lastModifiedBy,
      'priority': priority,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'tags': tags,
    };
  }

  // Create a copy with updated fields
  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    String? ownerId,
    String? ownerEmail,
    List<String>? sharedWith,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastModifiedBy,
    String? priority,
    DateTime? dueDate,
    List<String>? tags,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      sharedWith: sharedWith ?? this.sharedWith,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      tags: tags ?? this.tags,
    );
  }

  // Check if user has permission to edit
  bool canEdit(String userId) {
    return ownerId == userId || sharedWith.contains(userId);
  }

  // Check if task is overdue
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  // Get priority color
  int get priorityColor {
    switch (priority) {
      case 'high':
        return 0xFFFF5252;
      case 'medium':
        return 0xFFFF9800;
      case 'low':
        return 0xFF4CAF50;
      default:
        return 0xFF757575;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TaskModel(id: $id, title: $title, isCompleted: $isCompleted)';
  }
}
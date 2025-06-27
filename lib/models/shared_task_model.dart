

import 'package:cloud_firestore/cloud_firestore.dart';

enum SharePermission { view, edit, admin }
enum ShareStatus { pending, accepted, rejected }

class SharedTaskModel {
  final String id;
  final String taskId;
  final String ownerId;
  final String ownerEmail;
  final String sharedWithEmail;
  final String? sharedWithId;
  final SharePermission permission;
  final ShareStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? message;

  SharedTaskModel({
    required this.id,
    required this.taskId,
    required this.ownerId,
    required this.ownerEmail,
    required this.sharedWithEmail,
    this.sharedWithId,
    required this.permission,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.message,
  });

  // Convert from Firestore document
  factory SharedTaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedTaskModel(
      id: doc.id,
      taskId: data['taskId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      sharedWithEmail: data['sharedWithEmail'] ?? '',
      sharedWithId: data['sharedWithId'],
      permission: _parsePermission(data['permission']),
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null 
          ? (data['respondedAt'] as Timestamp).toDate() 
          : null,
      message: data['message'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'taskId': taskId,
      'ownerId': ownerId,
      'ownerEmail': ownerEmail,
      'sharedWithEmail': sharedWithEmail,
      'sharedWithId': sharedWithId,
      'permission': permission.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null 
          ? Timestamp.fromDate(respondedAt!) 
          : null,
      'message': message,
    };
  }

  // Parse permission from string
  static SharePermission _parsePermission(String? permission) {
    switch (permission) {
      case 'view':
        return SharePermission.view;
      case 'edit':
        return SharePermission.edit;
      case 'admin':
        return SharePermission.admin;
      default:
        return SharePermission.view;
    }
  }

  // Parse status from string
  static ShareStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return ShareStatus.pending;
      case 'accepted':
        return ShareStatus.accepted;
      case 'rejected':
        return ShareStatus.rejected;
      default:
        return ShareStatus.pending;
    }
  }

  // Create a copy with updated fields
  SharedTaskModel copyWith({
    String? id,
    String? taskId,
    String? ownerId,
    String? ownerEmail,
    String? sharedWithEmail,
    String? sharedWithId,
    SharePermission? permission,
    ShareStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? message,
  }) {
    return SharedTaskModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      sharedWithEmail: sharedWithEmail ?? this.sharedWithEmail,
      sharedWithId: sharedWithId ?? this.sharedWithId,
      permission: permission ?? this.permission,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      message: message ?? this.message,
    );
  }

  // Check if user can edit based on permission
  bool get canEdit => permission == SharePermission.edit || permission == SharePermission.admin;

  // Check if user can share with others
  bool get canShare => permission == SharePermission.admin;

  // Get permission display text
  String get permissionText {
    switch (permission) {
      case SharePermission.view:
        return 'View Only';
      case SharePermission.edit:
        return 'Can Edit';
      case SharePermission.admin:
        return 'Admin';
    }
  }

  // Get status display text
  String get statusText {
    switch (status) {
      case ShareStatus.pending:
        return 'Pending';
      case ShareStatus.accepted:
        return 'Accepted';
      case ShareStatus.rejected:
        return 'Rejected';
    }
  }

  // Get status color
  int get statusColor {
    switch (status) {
      case ShareStatus.pending:
        return 0xFFFF9800;
      case ShareStatus.accepted:
        return 0xFF4CAF50;
      case ShareStatus.rejected:
        return 0xFFFF5252;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedTaskModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SharedTaskModel(id: $id, taskId: $taskId, sharedWithEmail: $sharedWithEmail, status: $status)';
  }
}
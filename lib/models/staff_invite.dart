import 'package:cloud_firestore/cloud_firestore.dart';

class StaffInvite {
  const StaffInvite({
    required this.id,
    required this.hodId,
    required this.section,
    required this.staffEmail,
    required this.inviteLink,
    required this.createdAt,
  });

  final String id;
  final String hodId;
  final String section;
  final String staffEmail;
  final String inviteLink;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'hodId': hodId,
      'section': section,
      'staffEmail': staffEmail,
      'inviteLink': inviteLink,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory StaffInvite.fromMap(Map<String, dynamic> map, String id) {
    final created = map['createdAt'];
    DateTime createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is DateTime) {
      createdAt = created;
    } else {
      createdAt = DateTime.now();
    }

    return StaffInvite(
      id: id,
      hodId: map['hodId'] as String? ?? '',
      section: map['section'] as String? ?? '',
      staffEmail: map['staffEmail'] as String? ?? '',
      inviteLink: map['inviteLink'] as String? ?? '',
      createdAt: createdAt,
    );
  }
}

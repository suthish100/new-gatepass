import 'package:cloud_firestore/cloud_firestore.dart';

class Classroom {
  const Classroom({
    required this.id,
    required this.section,
    required this.year,
    required this.department,
    required this.hodId,
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.staffCode,
    required this.studentCode,
    required this.code,
    required this.inviteLink,
    this.hodDelegatedFinalApproverId,
    this.hodDelegatedFinalApproverName,
    this.hodDelegationReason,
    this.hodDelegationStartAt,
    this.hodDelegationEndAt,
    this.teacherDelegatedSingleApproverId,
    this.teacherDelegatedSingleApproverName,
    this.teacherDelegationReason,
    this.teacherDelegationStartAt,
    this.teacherDelegationEndAt,
    required this.createdAt,
  });

  final String id;
  final String section;
  final String year;
  final String department;
  final String hodId;
  final String teacherId;
  final String teacherName;
  final String teacherEmail;
  final String staffCode;
  final String studentCode;
  final String code;
  final String inviteLink;
  final String? hodDelegatedFinalApproverId;
  final String? hodDelegatedFinalApproverName;
  final String? hodDelegationReason;
  final DateTime? hodDelegationStartAt;
  final DateTime? hodDelegationEndAt;
  final String? teacherDelegatedSingleApproverId;
  final String? teacherDelegatedSingleApproverName;
  final String? teacherDelegationReason;
  final DateTime? teacherDelegationStartAt;
  final DateTime? teacherDelegationEndAt;
  final DateTime createdAt;

  bool get hasActiveHodDelegation {
    final now = DateTime.now();
    return hodDelegatedFinalApproverId != null &&
        hodDelegatedFinalApproverId!.isNotEmpty &&
        hodDelegationStartAt != null &&
        hodDelegationEndAt != null &&
        !now.isBefore(hodDelegationStartAt!) &&
        !now.isAfter(hodDelegationEndAt!);
  }

  bool get hasActiveTeacherDelegation {
    final now = DateTime.now();
    return teacherDelegatedSingleApproverId != null &&
        teacherDelegatedSingleApproverId!.isNotEmpty &&
        teacherDelegationStartAt != null &&
        teacherDelegationEndAt != null &&
        !now.isBefore(teacherDelegationStartAt!) &&
        !now.isAfter(teacherDelegationEndAt!);
  }

  Classroom copyWith({
    String? id,
    String? section,
    String? year,
    String? department,
    String? hodId,
    String? teacherId,
    String? teacherName,
    String? teacherEmail,
    String? staffCode,
    String? studentCode,
    String? code,
    String? inviteLink,
    String? hodDelegatedFinalApproverId,
    String? hodDelegatedFinalApproverName,
    String? hodDelegationReason,
    DateTime? hodDelegationStartAt,
    DateTime? hodDelegationEndAt,
    String? teacherDelegatedSingleApproverId,
    String? teacherDelegatedSingleApproverName,
    String? teacherDelegationReason,
    DateTime? teacherDelegationStartAt,
    DateTime? teacherDelegationEndAt,
    DateTime? createdAt,
  }) {
    return Classroom(
      id: id ?? this.id,
      section: section ?? this.section,
      year: year ?? this.year,
      department: department ?? this.department,
      hodId: hodId ?? this.hodId,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      teacherEmail: teacherEmail ?? this.teacherEmail,
      staffCode: staffCode ?? this.staffCode,
      studentCode: studentCode ?? this.studentCode,
      code: code ?? this.code,
      inviteLink: inviteLink ?? this.inviteLink,
      hodDelegatedFinalApproverId:
          hodDelegatedFinalApproverId ?? this.hodDelegatedFinalApproverId,
      hodDelegatedFinalApproverName:
          hodDelegatedFinalApproverName ?? this.hodDelegatedFinalApproverName,
      hodDelegationReason: hodDelegationReason ?? this.hodDelegationReason,
      hodDelegationStartAt: hodDelegationStartAt ?? this.hodDelegationStartAt,
      hodDelegationEndAt: hodDelegationEndAt ?? this.hodDelegationEndAt,
      teacherDelegatedSingleApproverId:
          teacherDelegatedSingleApproverId ?? this.teacherDelegatedSingleApproverId,
      teacherDelegatedSingleApproverName:
          teacherDelegatedSingleApproverName ?? this.teacherDelegatedSingleApproverName,
      teacherDelegationReason: teacherDelegationReason ?? this.teacherDelegationReason,
      teacherDelegationStartAt: teacherDelegationStartAt ?? this.teacherDelegationStartAt,
      teacherDelegationEndAt: teacherDelegationEndAt ?? this.teacherDelegationEndAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'section': section,
      'year': year,
      'department': department,
      'hodId': hodId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'teacherEmail': teacherEmail,
      'staffCode': staffCode,
      'studentCode': studentCode,
      'code': code,
      'inviteLink': inviteLink,
      'hodDelegatedFinalApproverId': hodDelegatedFinalApproverId,
      'hodDelegatedFinalApproverName': hodDelegatedFinalApproverName,
      'hodDelegationReason': hodDelegationReason,
      'hodDelegationStartAt': hodDelegationStartAt == null
          ? null
          : Timestamp.fromDate(hodDelegationStartAt!),
      'hodDelegationEndAt': hodDelegationEndAt == null
          ? null
          : Timestamp.fromDate(hodDelegationEndAt!),
      'teacherDelegatedSingleApproverId': teacherDelegatedSingleApproverId,
      'teacherDelegatedSingleApproverName': teacherDelegatedSingleApproverName,
      'teacherDelegationReason': teacherDelegationReason,
      'teacherDelegationStartAt': teacherDelegationStartAt == null
          ? null
          : Timestamp.fromDate(teacherDelegationStartAt!),
      'teacherDelegationEndAt': teacherDelegationEndAt == null
          ? null
          : Timestamp.fromDate(teacherDelegationEndAt!),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Classroom.fromMap(Map<String, dynamic> map, String id) {
    final created = map['createdAt'];
    final hodDelegationStartAt = map['hodDelegationStartAt'];
    final hodDelegationEndAt = map['hodDelegationEndAt'];
    DateTime createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is DateTime) {
      createdAt = created;
    } else {
      createdAt = DateTime.now();
    }

    final year = map['year'] as String? ?? '';
    final department = map['department'] as String? ?? '';
    final section = map['section'] as String? ?? '';
    final studentCode =
        map['studentCode'] as String? ?? map['code'] as String? ?? '';

    return Classroom(
      id: id,
      section: section.isNotEmpty
          ? section
          : '${year.isEmpty ? 'Class' : year} - ${department.isEmpty ? 'Department' : department}',
      year: year,
      department: department,
      hodId: map['hodId'] as String? ?? '',
      teacherId: map['teacherId'] as String? ?? '',
      teacherName: map['teacherName'] as String? ?? '',
      teacherEmail: map['teacherEmail'] as String? ?? '',
      staffCode: map['staffCode'] as String? ?? '',
      studentCode: studentCode,
      code: map['code'] as String? ?? studentCode,
      inviteLink: map['inviteLink'] as String? ?? '',
      hodDelegatedFinalApproverId:
          map['hodDelegatedFinalApproverId'] as String?,
      hodDelegatedFinalApproverName:
          map['hodDelegatedFinalApproverName'] as String?,
      hodDelegationReason: map['hodDelegationReason'] as String?,
      hodDelegationStartAt: hodDelegationStartAt is Timestamp
          ? hodDelegationStartAt.toDate()
          : hodDelegationStartAt as DateTime?,
      hodDelegationEndAt: hodDelegationEndAt is Timestamp
          ? hodDelegationEndAt.toDate()
          : hodDelegationEndAt as DateTime?,
      teacherDelegatedSingleApproverId:
          map['teacherDelegatedSingleApproverId'] as String?,
      teacherDelegatedSingleApproverName:
          map['teacherDelegatedSingleApproverName'] as String?,
      teacherDelegationReason: map['teacherDelegationReason'] as String?,
      teacherDelegationStartAt: map['teacherDelegationStartAt'] is Timestamp
          ? (map['teacherDelegationStartAt'] as Timestamp).toDate()
          : map['teacherDelegationStartAt'] as DateTime?,
      teacherDelegationEndAt: map['teacherDelegationEndAt'] is Timestamp
          ? (map['teacherDelegationEndAt'] as Timestamp).toDate()
          : map['teacherDelegationEndAt'] as DateTime?,
      createdAt: createdAt,
    );
  }
}

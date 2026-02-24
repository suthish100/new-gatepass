class AppRoles {
  static const String student = 'Student';
  static const String teacher = 'Teacher';
  static const String staff = teacher;
  static const String hod = 'HOD';

  static const List<String> all = <String>[student, teacher, hod];
}

class RequestStatus {
  static const String pending = 'Pending';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';
  static const String forwardedToHod = 'Forwarded to HOD';

  static const List<String> all = <String>[
    pending,
    approved,
    rejected,
    forwardedToHod,
  ];
}

const List<String> departments = <String>['AI&DS', 'CSC', 'ECE', 'EEE', 'MECH'];

const List<String> classYears = <String>[
  'I Year',
  'II Year',
  'III Year',
  'IV Year',
];

const List<String> classSections = <String>[
  '2nd Year',
  '3rd Year',
  'Final Year',
];

String roleDisplayName(String role) {
  if (role == AppRoles.teacher) {
    return 'Class Incharge';
  }
  return role;
}

class AppRoles {
  static const String student = 'Student';
  static const String teacher = 'Teacher';
  static const String staff = teacher;
  static const String hod = 'HOD';

  static const List<String> all = <String>[student, teacher, hod];
}

class HodType {
  static const String firstYear = '1st Year HOD';
  static const String senior = 'Senior HOD';

  // Legacy values retained for existing accounts created before label update.
  static const String firstYearLegacy = 'First Year HOD';
  static const String seniorLegacy = 'Senior Department HOD';

  static const List<String> all = <String>[firstYear, senior];
}

class RequestStatus {
  static const String pendingTeacher = 'Pending Teacher Approval';
  static const String forwardedToHod = 'Forwarded to HOD';
  static const String approved = 'Approved';
  static const String rejectedByTeacher = 'Rejected by Teacher';
  static const String rejectedByHod = 'Rejected by HOD';

  static const List<String> all = <String>[
    pendingTeacher,
    forwardedToHod,
    approved,
    rejectedByTeacher,
    rejectedByHod,
  ];
}

class PassType {
  static const String outing = 'Outing';
  static const String leave = 'Leave / Native Visit';

  static const List<String> all = <String>[outing, leave];
}

const List<String> departments = <String>['AI&DS', 'CSC', 'ECE', 'EEE', 'MECH'];

const List<String> classYears = <String>[
  'I Year',
  'II Year',
  'III Year',
  'IV Year',
];

const List<String> classSections = <String>[
  'I Year',
  'II Year',
  'III Year',
  'IV Year',
];

String roleDisplayName(String role) {
  if (role == AppRoles.teacher) {
    return 'Class Incharge';
  }
  return role;
}

bool isFirstYearHod(String? hodType) {
  return hodType == HodType.firstYear || hodType == HodType.firstYearLegacy;
}

bool isSeniorHod(String? hodType) {
  return hodType == HodType.senior || hodType == HodType.seniorLegacy;
}

String hodTypeDisplayName(String? hodType) {
  if (isFirstYearHod(hodType)) {
    return HodType.firstYear;
  }
  return HodType.senior;
}

const Map<String, String> colleges = <String, String>{
  'MEPCO2024': 'Mepco Schlenk Engineering College',
  'TCE2024':   'Thiagarajar College of Engineering',
  'ACEE2024':  'Arunachala College of Engineering',
  'RVCE2024':  'Renganayagi Varatharaj College of Engineering',
  // add more as needed
};

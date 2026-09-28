class User {
  final String employeeId;
  final String name;
  final String email;
  final String department;
  final String role; // 'employee' or 'admin'
  final bool active;
  final bool faceEnrolled;
  final String? faceEnrolledAt;
  final String? assignedOfficeId;

  User({
    required this.employeeId,
    required this.name,
    required this.email,
    required this.department,
    required this.role,
    this.active = true,
    this.faceEnrolled = false,
    this.faceEnrolledAt,
    this.assignedOfficeId,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      employeeId: json['employeeId'] ?? json['EmployeeID'] ?? '',
      name: json['name'] ?? json['Name'] ?? '',
      email: json['email'] ?? json['Email'] ?? '',
      department: json['department'] ?? json['Department'] ?? '',
      role: json['role'] ?? json['Role'] ?? 'employee',
      active: (json['active'] ?? json['Active'] ?? true).toString().toLowerCase() != 'false',
      faceEnrolled: (json['faceEnrolled'] ?? json['FaceEnrolled'] ?? false).toString().toLowerCase() == 'true',
      faceEnrolledAt: json['faceEnrolledAt'] ?? json['FaceEnrolledAt'],
      assignedOfficeId: json['assignedOfficeId'] ?? json['AssignedOfficeID'] ?? json['assignedOffice']?['officeId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'name': name,
      'email': email,
      'department': department,
      'role': role,
      'active': active,
      'faceEnrolled': faceEnrolled,
      'faceEnrolledAt': faceEnrolledAt,
      'assignedOfficeId': assignedOfficeId,
    };
  }
}

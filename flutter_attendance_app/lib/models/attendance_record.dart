class AttendanceRecord {
  final String sessionId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String officeId;
  final String workDate;
  final String clockInTimeUTC;
  final String clockInTimeKL;
  final String clockOutTimeUTC;
  final String clockOutTimeKL;
  final double? clockInLat;
  final double? clockInLng;
  final double? clockInAccuracy;
  final double? clockInDistanceMeters;
  final double? clockOutLat;
  final double? clockOutLng;
  final double? clockOutAccuracy;
  final double? clockOutDistanceMeters;
  final String faceVerified; // 'YES', 'NO', 'N/A'
  final String? faceVerificationConfidence;
  final int? workedMinutes;
  final double? workedHours;
  final String attendanceStatus; // 'IN_PROGRESS', 'COMPLETED', etc.
  final String? exceptionNotes;

  AttendanceRecord({
    required this.sessionId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.officeId,
    required this.workDate,
    required this.clockInTimeUTC,
    required this.clockInTimeKL,
    this.clockOutTimeUTC = '',
    this.clockOutTimeKL = '',
    this.clockInLat,
    this.clockInLng,
    this.clockInAccuracy,
    this.clockInDistanceMeters,
    this.clockOutLat,
    this.clockOutLng,
    this.clockOutAccuracy,
    this.clockOutDistanceMeters,
    this.faceVerified = 'N/A',
    this.faceVerificationConfidence,
    this.workedMinutes,
    this.workedHours,
    required this.attendanceStatus,
    this.exceptionNotes,
  });

  bool get isInProgress => attendanceStatus == 'IN_PROGRESS';
  bool get isCompleted => attendanceStatus == 'COMPLETED';
  bool get isException => attendanceStatus.startsWith('EXCEPTION_') || (exceptionNotes != null && exceptionNotes!.isNotEmpty);

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      sessionId: json['sessionId'] ?? json['SessionID'] ?? '',
      employeeId: json['employeeId'] ?? json['EmployeeID'] ?? '',
      employeeName: json['employeeName'] ?? json['EmployeeName'] ?? '',
      department: json['department'] ?? json['Department'] ?? '',
      officeId: json['officeId'] ?? json['OfficeID'] ?? '',
      workDate: json['workDate'] ?? json['WorkDate'] ?? '',
      clockInTimeUTC: json['clockInTimeUTC'] ?? json['ClockInTimeUTC'] ?? '',
      clockInTimeKL: json['clockInTimeKL'] ?? json['ClockInTimeKL'] ?? '',
      clockOutTimeUTC: json['clockOutTimeUTC'] ?? json['ClockOutTimeUTC'] ?? '',
      clockOutTimeKL: json['clockOutTimeKL'] ?? json['ClockOutTimeKL'] ?? '',
      clockInLat: json['clockInLat'] != null ? double.tryParse(json['clockInLat'].toString()) : null,
      clockInLng: json['clockInLng'] != null ? double.tryParse(json['clockInLng'].toString()) : null,
      clockInAccuracy: json['clockInAccuracy'] != null ? double.tryParse(json['clockInAccuracy'].toString()) : null,
      clockInDistanceMeters: json['clockInDistanceMeters'] != null ? double.tryParse(json['clockInDistanceMeters'].toString()) : null,
      clockOutLat: json['clockOutLat'] != null ? double.tryParse(json['clockOutLat'].toString()) : null,
      clockOutLng: json['clockOutLng'] != null ? double.tryParse(json['clockOutLng'].toString()) : null,
      clockOutAccuracy: json['clockOutAccuracy'] != null ? double.tryParse(json['clockOutAccuracy'].toString()) : null,
      clockOutDistanceMeters: json['clockOutDistanceMeters'] != null ? double.tryParse(json['clockOutDistanceMeters'].toString()) : null,
      faceVerified: json['faceVerified'] ?? json['FaceVerified'] ?? 'N/A',
      faceVerificationConfidence: json['faceVerificationConfidence'] ?? json['FaceVerificationConfidence'],
      workedMinutes: json['workedMinutes'] != null ? int.tryParse(json['workedMinutes'].toString()) : null,
      workedHours: json['workedHours'] != null ? double.tryParse(json['workedHours'].toString()) : null,
      attendanceStatus: json['attendanceStatus'] ?? json['AttendanceStatus'] ?? 'IN_PROGRESS',
      exceptionNotes: json['exceptionNotes'] ?? json['ExceptionNotes'],
    );
  }
}

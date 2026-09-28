import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/attendance_record.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AttendanceProvider>(context, listen: false).loadMyHistory();
    });
  }

  void _showSessionDetail(AttendanceRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              record.isCompleted ? Icons.check_circle : (record.isInProgress ? Icons.hourglass_top : Icons.warning),
              color: record.isCompleted ? Colors.green : (record.isInProgress ? Colors.amber : Colors.red),
            ),
            const SizedBox(width: 8),
            const Text('Session Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Session ID', record.sessionId),
              _detailRow('Work Date', record.workDate),
              _detailRow('Clock-In (KL)', record.clockInTimeKL),
              _detailRow('Clock-Out (KL)', record.clockOutTimeKL.isNotEmpty ? record.clockOutTimeKL : 'Still Active'),
              _detailRow('Worked Duration', record.workedHours != null ? '${record.workedHours} hrs (${record.workedMinutes} mins)' : '--'),
              const Divider(),
              _detailRow('Clock-In Dist.', record.clockInDistanceMeters != null ? '${record.clockInDistanceMeters!.toStringAsFixed(1)}m from office' : '--'),
              _detailRow('Clock-In Accuracy', record.clockInAccuracy != null ? '±${record.clockInAccuracy!.toStringAsFixed(1)}m' : '--'),
              _detailRow('Face Verified', record.faceVerified),
              if (record.faceVerificationConfidence != null && record.faceVerificationConfidence!.isNotEmpty)
                _detailRow('Match Confidence', record.faceVerificationConfidence!),
              if (record.exceptionNotes != null && record.exceptionNotes!.isNotEmpty) ...[
                const Divider(),
                _detailRow('Notes', record.exceptionNotes!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final records = attendance.historyRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance History'),
      ),
      body: attendance.isLoading
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No attendance records found yet', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final r = records[index];
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: r.isCompleted
                              ? Colors.green.shade100
                              : (r.isInProgress ? Colors.amber.shade100 : Colors.red.shade100),
                          child: Icon(
                            r.isCompleted ? Icons.check : (r.isInProgress ? Icons.access_time : Icons.error_outline),
                            color: r.isCompleted
                                ? Colors.green.shade800
                                : (r.isInProgress ? Colors.amber.shade900 : Colors.red.shade800),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(r.workDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: r.isCompleted ? Colors.green.shade50 : Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                r.attendanceStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: r.isCompleted ? Colors.green.shade800 : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('In: ${r.clockInTimeKL}'),
                            if (r.clockOutTimeKL.isNotEmpty) Text('Out: ${r.clockOutTimeKL}'),
                            if (r.workedHours != null && r.workedHours! > 0)
                              Text('Total: ${r.workedHours} hrs (${r.workedMinutes} mins)',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent)),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showSessionDetail(r),
                      ),
                    );
                  },
                ),
    );
  }
}

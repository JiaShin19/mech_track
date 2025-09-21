import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TimeTrackingService {
  final FirebaseFirestore _db;
  TimeTrackingService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _job(String jobId) =>
      _db.collection('jobs').doc(jobId);

  /// Start a new session (or resume). Fails if one already running.
  Future<void> startSession({
    required String jobId,
    required String mechanicId,
  }) async {
    final jobRef = _job(jobId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(jobRef);
      if (!snap.exists) {
        throw StateError('Job $jobId does not exist in Firestore.');
      }
      final d = snap.data()!;
      if ((d['running'] ?? false) == true) {
        throw StateError('A time session is already running.');
      }

      txn.update(jobRef, {
        'running': true,
        'startedAt': FieldValue.serverTimestamp(),
        'status': (d['status'] == 'Assigned') ? 'In Progress' : d['status'],
      });
    });
  }

  /// Pause: finalize running session, accumulate duration.
  Future<void> pauseSession(String jobId) async {
    final jobRef = _job(jobId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(jobRef);
      if (!snap.exists) return;
      final d = snap.data()!;
      if ((d['running'] ?? false) != true || d['startedAt'] == null) return;

      final startedAtTs = d['startedAt'] as Timestamp;
      final startedAt = startedAtTs.toDate();
      final now = DateTime.now();
      final secs = now.difference(startedAt).inSeconds;
      final prevAgg = (d['aggregatedDurationSeconds'] ?? 0) as int;

      final newTotal = prevAgg + secs;
      txn.update(jobRef, {
        'running': false,
        'startedAt': null,
        'aggregatedDurationSeconds': newTotal,
        'totalTimeSpent': _formatHmsFull(newTotal),
        'totalTimeSpentDisplay': _formatHoursDisplay(newTotal),
      });
    });
  }

  /// Resume = start a fresh session.
  Future<void> resumeSession({
    required String jobId,
    required String mechanicId,
  }) =>
      startSession(jobId: jobId, mechanicId: mechanicId);

  /// Complete job (auto-pause any running session).
  Future<void> completeJob(String jobId) async {
    final jobRef = _job(jobId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(jobRef);
      if (!snap.exists) return;
      final d = snap.data()!;
      int agg = (d['aggregatedDurationSeconds'] ?? 0) as int;

      if ((d['running'] ?? false) == true && d['startedAt'] != null) {
        final startedAt = (d['startedAt'] as Timestamp).toDate();
        final now = DateTime.now();
        final dur = now.difference(startedAt).inSeconds;
        agg += dur;
      }

      txn.update(jobRef, {
        'running': false,
        'startedAt': null,
        'status': 'Completed',
        'aggregatedDurationSeconds': agg,
        'totalTimeSpent': _formatHmsFull(agg),
        'totalTimeSpentDisplay': _formatHoursDisplay(agg),
      });
    });
  }

  String _formatHoursDisplay(int seconds) {
    final h = seconds / 3600.0;
    return "${h.toStringAsFixed(h < 10 ? 2 : 1)}h";
  }
  String _formatHmsFull(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
  }
}

class JobTimerProvider extends ChangeNotifier {
  final String jobId;
  final FirebaseFirestore _db;
  StreamSubscription? _jobSub;
  Timer? _ticker;

  bool _loading = true;
  bool get isLoading => _loading;

  int _aggregated = 0;
  bool _running = false;
  DateTime? _startedAt;
  String _status = 'Assigned';

  bool get isRunning => _running;
  String get status => _status;

  JobTimerProvider(this.jobId, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance {
    _listen();
  }

  void _listen() {
    _jobSub = _db.collection('jobs').doc(jobId).snapshots().listen((doc) {
      if (!doc.exists) return;
      final d = doc.data()!;
      _aggregated = (d['aggregatedDurationSeconds'] ?? 0) as int;
      _running = (d['running'] ?? false) as bool;
      _status = (d['status'] ?? 'Assigned').toString();
      if (_running && d['startedAt'] is Timestamp) {
        _startedAt = (d['startedAt'] as Timestamp).toDate();
        _startTicker();
      } else {
        _startedAt = null;
        _stopTicker();
      }
      _loading = false;
      notifyListeners();
    });
  }

  int get totalSeconds {
    if (!_running || _startedAt == null) {
      return _aggregated;
    }
    final now = DateTime.now();
    final live = now.difference(_startedAt!).inSeconds;
    return _aggregated + (live < 0 ? 0 : live);
  }

  String formatHms() {
    final secs = totalSeconds;
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _jobSub?.cancel();
    _stopTicker();
    super.dispose();
  }
}

/// =============================
/// TimeTrackingPanel (UI Widget)
/// =============================
class TimeTrackingPanel extends StatefulWidget {
  final String jobId;
  final String mechanicId;
  final EdgeInsetsGeometry margin;
  final bool showStatus;

  const TimeTrackingPanel({
    super.key,
    required this.jobId,
    required this.mechanicId,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
    this.showStatus = true,
  });

  @override
  State<TimeTrackingPanel> createState() => _TimeTrackingPanelState();
}

class _TimeTrackingPanelState extends State<TimeTrackingPanel> {
  final _svc = TimeTrackingService();
  bool _busy = false;

  Future<void> _exec(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Time tracking: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => JobTimerProvider(widget.jobId),
      child: Consumer<JobTimerProvider>(
        builder: (context, timer, _) {
          if (timer.isLoading) {
            return Card(
              margin: widget.margin,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          final running = timer.isRunning;
          final status = timer.status;

          return Card(
            elevation: 2,
            margin: widget.margin,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Time Tracking',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      if (_busy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        color: running ? Colors.green : Colors.indigo,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        timer.formatHms(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: running ? Colors.green : Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (!running && status != 'Completed')
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start / Resume'),
                          onPressed: _busy
                              ? null
                              : () => _exec(() => _svc.startSession(
                            jobId: widget.jobId,
                            mechanicId: widget.mechanicId,
                          )),
                        ),
                      if (running)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          icon: const Icon(Icons.pause),
                          label: const Text('Pause'),
                          onPressed: _busy
                              ? null
                              : () => _exec(() => _svc.pauseSession(widget.jobId)),
                        ),
                      if (!running && status != 'Completed')
                        OutlinedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Complete'),
                          onPressed: _busy
                              ? null
                              : () => _exec(() => _svc.completeJob(widget.jobId)),
                        ),
                      if (status == 'Completed')
                        const Chip(
                          label: Text('Completed'),
                          backgroundColor: Color(0xFFE0FFE4),
                        ),
                    ],
                  ),
                  if (widget.showStatus) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Status: $status',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
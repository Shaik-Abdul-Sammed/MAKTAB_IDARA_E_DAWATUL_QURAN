import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/student_repository.dart';
import '../services/cloud_sync_service.dart';

enum AttendanceStatus { initial, loading, success, error }

class AttendanceProvider extends ChangeNotifier {
  final AttendanceRepository _attendanceRepo;
  final StudentRepository _studentRepo;
  StreamSubscription<String>? _syncSub;
  bool _entryScreenActive = false;
  bool get entryScreenActive => _entryScreenActive;

  void setEntryScreenActive(bool active) {
    _entryScreenActive = active;
  }

  AttendanceProvider(this._attendanceRepo, this._studentRepo) {
    _syncSub = CloudSyncService.instance.onDataSynced.listen((col) {
      if (col == 'students' || col == 'batches' || col == 'attendance') {
        if (_isSaving || _entryScreenActive) return; // Do not reload or wipe live session while saving or while entry screen is open
        if (_selectedBatchId != null) {
          loadBatchAttendance(_selectedBatchId!);
        }
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  AttendanceStatus _status = AttendanceStatus.initial;
  AttendanceStatus get status => _status;

  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get selectedDate => _selectedDate;

  int? _selectedBatchId;
  int? get selectedBatchId => _selectedBatchId;

  List<Student> _students = [];
  List<Student> get students => List.unmodifiable(_students);

  // Search & filter
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  /// null = show all, 'Present', 'Absent', 'Leave', 'Late'
  String? _filterStatus;
  String? get filterStatus => _filterStatus;

  List<Student> get filteredStudents {
    var list = _students;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) => s.name.toLowerCase().contains(q)).toList();
    }
    if (_filterStatus != null) {
      if (_filterStatus == 'Absent') {
        list = list.where((s) => s.id != null && _studentStatuses[s.id] != 'Present').toList();
      } else {
        list = list.where((s) => s.id != null && _studentStatuses[s.id] == _filterStatus).toList();
      }
    }
    return list;
  }

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setFilterStatus(String? status) {
    _filterStatus = status;
    notifyListeners();
  }

  // Map of studentId -> status ('Present', 'Absent', 'Leave', 'Late')
  Map<int, String> _studentStatuses = {};
  Map<int, String> get studentStatuses => Map.unmodifiable(_studentStatuses);

  Map<int, String> _studentRemarks = {};
  Map<int, String> get studentRemarks => Map.unmodifiable(_studentRemarks);

  Map<int, int?> _existingAttendanceIds = {};

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  int get presentCount => _studentStatuses.values.where((v) => v == 'Present').length;
  int get absentCount => _studentStatuses.values.where((v) => v == 'Absent').length;
  int get lateCount => _studentStatuses.values.where((v) => v == 'Late').length;
  int get leaveCount => _studentStatuses.values.where((v) => v == 'Leave').length;
  int get totalCount => _students.length;

  // Time period for this session (e.g. 'Morning', 'Afternoon', 'Evening')
  String? _timePeriod;
  String? get timePeriod => _timePeriod;

  void setTimePeriod(String? period) {
    _timePeriod = period;
    notifyListeners();
  }

  void setDate(String date) {
    _selectedDate = date;
    if (_selectedBatchId != null) {
      loadBatchAttendance(_selectedBatchId!);
    }
  }

  void setBatchId(int batchId) {
    _selectedBatchId = batchId;
    loadBatchAttendance(batchId);
  }

  Future<void> loadBatchAttendance(int batchId) async {
    if (_students.isEmpty) {
      _status = AttendanceStatus.loading;
      _studentStatuses = {};
      _studentRemarks = {};
      _existingAttendanceIds = {};
      notifyListeners();
    }
    _errorMessage = '';
    try {
      final fetchedStudents = await _studentRepo.getStudentsByBatch(batchId);
      final existing = await _attendanceRepo.getAttendanceByDateAndBatch(_selectedDate, batchId);
      
      final Map<int, String> statuses = Map<int, String>.from(_studentStatuses);
      final Map<int, String> remarks = Map<int, String>.from(_studentRemarks);
      final Map<int, int?> existingIds = Map<int, int?>.from(_existingAttendanceIds);

      for (var s in fetchedStudents) {
        if (s.id != null) {
          // Keep live session status if already present, else default to Present
          statuses[s.id!] = statuses[s.id!] ?? 'Present';
        }
      }

      for (var att in existing) {
        // If DB record exists, use it unless actively modified
        statuses[att.studentId] = _studentStatuses[att.studentId] ?? att.status;
        if (att.remarks != null) remarks[att.studentId] = att.remarks!;
        existingIds[att.studentId] = att.id;
      }

      _students = fetchedStudents;
      _studentStatuses = statuses;
      _studentRemarks = remarks;
      _existingAttendanceIds = existingIds;
      _status = AttendanceStatus.success;
    } catch (e) {
      _status = AttendanceStatus.error;
      _errorMessage = 'Failed to load batch attendance.';
    }
    notifyListeners();
  }

  void markStatus(int studentId, String status) {
    _studentStatuses[studentId] = status;
    notifyListeners();
  }

  /// Cycle through Present -> Absent -> Late -> Leave -> Present
  void cycleStatus(int studentId) {
    const cycle = ['Present', 'Absent', 'Late', 'Leave'];
    final current = _studentStatuses[studentId] ?? 'Present';
    final idx = cycle.indexOf(current);
    final nextIdx = (idx == -1) ? 0 : (idx + 1) % cycle.length;
    _studentStatuses[studentId] = cycle[nextIdx];
    notifyListeners();
  }

  void setStatus(int studentId, String status) {
    _studentStatuses[studentId] = status;
    notifyListeners();
  }

  void markAllPresent() {
    for (var s in _students) {
      if (s.id != null) {
        _studentStatuses[s.id!] = 'Present';
      }
    }
    notifyListeners();
  }

  void markAllAbsent() {
    for (var s in _students) {
      if (s.id != null) {
        _studentStatuses[s.id!] = 'Absent';
      }
    }
    notifyListeners();
  }

  Future<void> saveAttendance() async {
    if (_students.isEmpty) {
      throw StateError('Cannot save attendance: No students found in this batch.');
    }
    _isSaving = true;
    notifyListeners();
    try {
      final List<Attendance> toInsert = [];
      final List<Attendance> toUpdate = [];

      for (var s in _students) {
        if (s.id == null) continue;
        final studentId = s.id!;
        final status = _studentStatuses[studentId] ?? 'Present';
        final remark = _studentRemarks[studentId];
        final existingId = _existingAttendanceIds[studentId];

        final nowTime = DateFormat('hh:mm a').format(DateTime.now());
        final att = Attendance(
          id: existingId,
          studentId: studentId,
          date: _selectedDate,
          status: status,
          remarks: remark,
          time: nowTime,
          timePeriod: _timePeriod,
        );

        if (existingId != null) {
          toUpdate.add(att);
        } else {
          toInsert.add(att);
        }
      }

      if (toInsert.isNotEmpty) {
        final created = await _attendanceRepo.insertAttendances(toInsert);
        for (var c in created) {
          if (c.id != null) {
            _existingAttendanceIds[c.studentId] = c.id;
          }
        }
      }
      if (toUpdate.isNotEmpty) {
        await _attendanceRepo.updateAttendances(toUpdate);
      }

      _isSaving = false;
      notifyListeners();
    } catch (e) {
      _isSaving = false;
      notifyListeners();
      rethrow;
    }
  }
}

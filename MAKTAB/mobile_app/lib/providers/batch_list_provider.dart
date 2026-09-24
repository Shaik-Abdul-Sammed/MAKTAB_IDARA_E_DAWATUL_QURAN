import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/batch.dart';
import '../models/user.dart';
import '../repositories/batch_repository.dart';
import '../repositories/user_repository.dart';
import '../services/cloud_sync_service.dart';

enum BatchListStatus { initial, loading, success, error }

class BatchListProvider extends ChangeNotifier {
  final BatchRepository _repo;
  final UserRepository _userRepo = UserRepository();
  StreamSubscription<String>? _syncSub;

  BatchListProvider(this._repo) {
    _syncSub = CloudSyncService.instance.onDataSynced.listen((col) {
      if (col == 'batches' || col == 'teachers') {
        fetchBatches();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  BatchListStatus _status = BatchListStatus.initial;
  BatchListStatus get status => _status;

  List<Batch> _batches = [];
  List<Batch> get batches => List.unmodifiable(_batches);

  List<User> _teachers = [];
  List<User> get teachers => List.unmodifiable(_teachers);

  String getTeacherName(int? teacherId) {
    if (teacherId == null) return 'Unassigned';
    final match = _teachers.where((t) => (t.teacherId ?? t.id) == teacherId || t.id == teacherId);
    return match.isNotEmpty ? match.first.name : 'Unassigned';
  }

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  List<Batch> get filteredBatches {
    if (_searchQuery.isEmpty) return _batches;
    final q = _searchQuery.toLowerCase();
    return _batches
        .where((b) => b.name.toLowerCase().contains(q) || b.timing.toLowerCase().contains(q))
        .toList();
  }

  int get totalCount => _batches.length;
  int get assignedCount => _batches.where((b) => b.teacherId != null).length;
  int get unassignedCount => _batches.where((b) => b.teacherId == null).length;

  Future<void> fetchBatches() async {
    _status = BatchListStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.getAllBatches(),
        _userRepo.getAllTeachers(),
      ]);
      _batches = results[0] as List<Batch>;
      _teachers = results[1] as List<User>;
      _status = BatchListStatus.success;
    } catch (e) {
      _status = BatchListStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> deleteBatch(int id) async {
    final index = _batches.indexWhere((b) => b.id == id);
    Batch? removed;
    if (index != -1) {
      removed = _batches[index];
      _batches.removeAt(index);
      notifyListeners();
    }
    try {
      await _repo.deleteBatch(id);
    } catch (e) {
      if (removed != null && index != -1) {
        _batches.insert(index, removed);
        notifyListeners();
      }
      rethrow;
    }
  }
}

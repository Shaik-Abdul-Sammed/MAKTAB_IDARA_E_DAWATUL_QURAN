import 'package:flutter/foundation.dart';
import '../models/batch.dart';
import '../repositories/batch_repository.dart';

enum BatchListStatus { initial, loading, success, error }

class BatchListProvider extends ChangeNotifier {
  final BatchRepository _repo;
  BatchListProvider(this._repo);

  BatchListStatus _status = BatchListStatus.initial;
  BatchListStatus get status => _status;

  List<Batch> _batches = [];
  List<Batch> get batches => List.unmodifiable(_batches);

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
      _batches = await _repo.getAllBatches();
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

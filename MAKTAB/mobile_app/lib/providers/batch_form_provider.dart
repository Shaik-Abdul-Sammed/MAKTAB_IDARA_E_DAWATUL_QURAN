import 'package:flutter/foundation.dart';
import '../models/batch.dart';
import '../repositories/batch_repository.dart';

enum BatchFormStatus { idle, loading, success, error }

class BatchFormProvider extends ChangeNotifier {
  final BatchRepository _repo;
  BatchFormProvider(this._repo);

  BatchFormStatus _status = BatchFormStatus.idle;
  BatchFormStatus get status => _status;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool get isLoading => _status == BatchFormStatus.loading;

  Future<void> addBatch({
    required String name,
    required String timing,
    int? teacherId,
  }) async {
    _status = BatchFormStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      final batch = Batch(
        name: name.trim(),
        timing: timing.trim(),
        teacherId: teacherId,
      );
      await _repo.insertBatch(batch);
      _status = BatchFormStatus.success;
    } catch (e) {
      _status = BatchFormStatus.error;
      _errorMessage = 'Failed to create batch. Please try again.';
    }
    notifyListeners();
  }

  Future<void> updateBatch({
    required Batch existing,
    required String name,
    required String timing,
    int? teacherId,
  }) async {
    _status = BatchFormStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      final updated = existing.copyWith(
        name: name.trim(),
        timing: timing.trim(),
        teacherId: teacherId,
      );
      await _repo.updateBatch(updated);
      _status = BatchFormStatus.success;
    } catch (e) {
      _status = BatchFormStatus.error;
      _errorMessage = 'Failed to update batch details. Please try again.';
    }
    notifyListeners();
  }

  void reset() {
    _status = BatchFormStatus.idle;
    _errorMessage = '';
    notifyListeners();
  }
}

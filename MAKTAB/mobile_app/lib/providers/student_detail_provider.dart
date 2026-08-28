import 'package:flutter/foundation.dart';
import '../models/student.dart';
import '../models/batch.dart';
import '../repositories/student_repository.dart';
import '../repositories/batch_repository.dart';

import '../models/fee_payment.dart';
import '../repositories/fee_payment_repository.dart';


class StudentDetailProvider extends ChangeNotifier {
  final StudentRepository _studentRepo;
  final BatchRepository _batchRepo;
  final FeePaymentRepository _feeRepo = FeePaymentRepository();

  StudentDetailProvider(this._studentRepo, this._batchRepo);

  Student? _student;
  Student? get student => _student;

  Batch? _batch;
  List<FeePayment> _payments = [];
  Batch? get batch => _batch;
  List<FeePayment> get payments => _payments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;
  bool get hasError => _errorMessage.isNotEmpty;
  bool get hasStudent => _student != null;

  Future<void> fetchStudent(int id) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final res = await _studentRepo.getStudentById(id);
      if (res == null) {
        _errorMessage = 'Student record not found.';
      } else {
        _student = res;
        if (_student?.batchId != null) {
          final batches = await _batchRepo.getAllBatches();
          _batch = batches.firstWhere(
            (b) => b.id == _student!.batchId,
            orElse: () => Batch(name: 'Unassigned', timing: 'N/A'),
          );
        } else {
          _batch = null;
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to load student profile.';
    }
    _isLoading = false;
    notifyListeners();
  }

  
  Future<void> addPayment(FeePayment payment) async {
    await _feeRepo.insertFeePayment(payment);
    if (_student != null) {
      _payments = await _feeRepo.getPaymentsForStudent(_student!.id!);
      notifyListeners();
    }
  }

  Future<void> updatePayment(FeePayment payment) async {
    await _feeRepo.updateFeePayment(payment);
    if (_student != null) {
      _payments = await _feeRepo.getPaymentsForStudent(_student!.id!);
      notifyListeners();
    }
  }

  Future<void> deletePayment(int id) async {
    await _feeRepo.deleteFeePayment(id);
    if (_student != null) {
      _payments = await _feeRepo.getPaymentsForStudent(_student!.id!);
      notifyListeners();
    }
  }

  Future<void> deleteCurrentStudent() async {
    if (_student?.id == null) throw Exception('No student loaded.');
    await _studentRepo.deleteStudent(_student!.id!);
  }
}

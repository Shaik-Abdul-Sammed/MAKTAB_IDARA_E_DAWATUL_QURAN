import '../dtos/batch_dto.dart';

abstract class IBatchRepository {
  Future<int> insertBatch(BatchDTO batch);
  Future<List<BatchDTO>> getAllBatches();
  Future<List<BatchDTO>> getBatchesByTeacher(int teacherId);
  Future<int> updateBatch(BatchDTO batch);
  Future<int> deleteBatch(int id);
}
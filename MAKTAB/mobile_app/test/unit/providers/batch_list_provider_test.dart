import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maktab_app/providers/batch_list_provider.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:maktab_app/models/batch.dart';

class MockBatchRepository extends Mock implements BatchRepository {}

void main() {
  late MockBatchRepository mockRepo;
  late BatchListProvider provider;

  final sampleBatches = [
    Batch(id: 1, name: 'Batch Hifz A', timing: '06:00 AM'),
    Batch(id: 2, name: 'Batch Nazira B', timing: '05:00 PM'),
  ];

  setUp(() {
    mockRepo = MockBatchRepository();
    provider = BatchListProvider(mockRepo);
  });

  tearDown(() {
    provider.dispose();
  });

  group('BatchListProvider Unit Tests', () {
    test('fetchBatches updates state on success', () async {
      when(() => mockRepo.getAllBatches()).thenAnswer((_) async => sampleBatches);

      await provider.fetchBatches();

      expect(provider.status, BatchListStatus.success);
      expect(provider.batches.length, 2);
    });

    test('deleteBatch optimistic removal', () async {
      when(() => mockRepo.getAllBatches()).thenAnswer((_) async => List.from(sampleBatches));
      when(() => mockRepo.deleteBatch(1)).thenAnswer((_) async => 1);

      await provider.fetchBatches();
      await provider.deleteBatch(1);

      verify(() => mockRepo.deleteBatch(1)).called(1);
    });
  });
}

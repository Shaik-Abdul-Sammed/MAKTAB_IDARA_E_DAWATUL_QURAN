import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/batch.dart';
import '../../repositories/batch_repository.dart';

class BatchAttendanceSelectionScreen extends StatefulWidget {
  const BatchAttendanceSelectionScreen({super.key});

  @override
  State<BatchAttendanceSelectionScreen> createState() => _BatchAttendanceSelectionScreenState();
}

class _BatchAttendanceSelectionScreenState extends State<BatchAttendanceSelectionScreen> {
  List<Batch> _batches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      final repo = BatchRepository();
      final items = await repo.getAllBatches();
      if (mounted) {
        setState(() {
          _batches = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading batches: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        title: const Text('Select Batch Attendance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF004D40),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
          : _batches.isEmpty
              ? const Center(child: Text('No batches available.', style: TextStyle(color: Colors.black54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _batches.length,
                  itemBuilder: (context, index) {
                    final batch = _batches[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          context.push('/admin/batches/${batch.id}/attendance-calendar');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.class_rounded, color: Color(0xFF004D40)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      batch.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Timing: ${batch.timing}',
                                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black26, size: 16),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

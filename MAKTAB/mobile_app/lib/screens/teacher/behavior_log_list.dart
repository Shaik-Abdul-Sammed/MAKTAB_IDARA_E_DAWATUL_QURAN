import 'package:flutter/material.dart';
import '../../../models/behavior_log.dart';
import '../../../repositories/behavior_repository.dart';

class BehaviorLogListScreen extends StatefulWidget {
  const BehaviorLogListScreen({super.key});

  @override
  State<BehaviorLogListScreen> createState() => _BehaviorLogListScreenState();
}

class _BehaviorLogListScreenState extends State<BehaviorLogListScreen> {
  List<BehaviorLog> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _repo = BehaviorRepository();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
        final records = await _repo.getAllLogs();
        if (mounted) {
            setState(() {
                _items = records;
                _isLoading = false;
            });
        }
    } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  void _showAddEditDialog([BehaviorLog? item]) {
    final isEditing = item != null;
    final incidentCtrl = TextEditingController(text: item?.incident.toString() ?? '');
    final actionTakenCtrl = TextEditingController(text: item?.actionTaken.toString() ?? '');
    final dateCtrl = TextEditingController(text: item?.date.toString() ?? DateTime.now().toIso8601String().split('T')[0]);
    final studentIdCtrl = TextEditingController(text: item?.studentId.toString() ?? '1');
    final teacherIdCtrl = TextEditingController(text: item?.teacherId.toString() ?? '1');


    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Behavior Log' : 'New Behavior Log'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: incidentCtrl, decoration: const InputDecoration(labelText: 'Incident'), keyboardType: TextInputType.text),
              TextField(controller: actionTakenCtrl, decoration: const InputDecoration(labelText: 'Action Taken'), keyboardType: TextInputType.text),
              TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'), keyboardType: TextInputType.text),
              TextField(controller: studentIdCtrl, decoration: const InputDecoration(labelText: 'Student ID'), keyboardType: TextInputType.number),
              TextField(controller: teacherIdCtrl, decoration: const InputDecoration(labelText: 'Teacher ID'), keyboardType: TextInputType.number),

            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newObj = BehaviorLog(
                id: item?.id,
                incident: incidentCtrl.text,
                actionTaken: actionTakenCtrl.text,
                date: dateCtrl.text,
                studentId: int.tryParse(studentIdCtrl.text) ?? 1,
                teacherId: int.tryParse(teacherIdCtrl.text) ?? 1,

              );
              if (isEditing) {
                await _repo.updateLog(newObj);
              } else {
                await _repo.insertLog(newObj);
              }
              if (context.mounted) {
                Navigator.pop(context);
                _loadRecords();
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _showDetailSheet(BehaviorLog item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: Text('Record Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40)))),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () {
                      Navigator.pop(context);
                      _showAddEditDialog(item);
                    }),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                      await _repo.deleteLog(item.id!);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _loadRecords();
                      }
                    }),
                  ],
                )
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  () {
                    try {
                      return (item as dynamic).toMap().entries.map((e) => '${e.key}: ${e.value}').join('\n\n');
                    } catch (_) {
                      return item.toString();
                    }
                  }(), 
                  style: const TextStyle(fontSize: 16)
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((item) => item.incident.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        title: const Text('Behavior Logs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF004D40),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFFFFD700),
        icon: const Icon(Icons.add, color: Color(0xFF004D40)),
        label: const Text('New Behavior Log', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search records...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF004D40)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black26)),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRecords,
                color: const Color(0xFF004D40),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
                    : filteredItems.isEmpty
                        ? const Center(child: Text('No matching records found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              return Card(
                                color: Colors.white,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 1,
                                child: ListTile(
                                  leading: const CircleAvatar(backgroundColor: Color(0xFF004D40), foregroundColor: Colors.white, child: Icon(Icons.report_problem, size: 18)),
                                  title: Text('Incident: ${item.incident}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Date: ${item.date} | Action: ${item.actionTaken ?? "None"}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _showDetailSheet(item),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

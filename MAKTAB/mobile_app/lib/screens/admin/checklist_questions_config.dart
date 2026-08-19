import 'package:flutter/material.dart';
import '../../../models/checklist.dart';
import '../../../repositories/checklist_repository.dart';

class ChecklistQuestionsConfigScreen extends StatefulWidget {
  const ChecklistQuestionsConfigScreen({super.key});

  @override
  State<ChecklistQuestionsConfigScreen> createState() => _ChecklistQuestionsConfigScreenState();
}

class _ChecklistQuestionsConfigScreenState extends State<ChecklistQuestionsConfigScreen> {
  List<ChecklistQuestion> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _repo = ChecklistRepository();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
        final records = await _repo.getAllQuestions();
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

  void _showAddEditDialog([ChecklistQuestion? item]) {
    final isEditing = item != null;
    final textCtrl = TextEditingController(text: item?.text.toString() ?? '');
    final categoryCtrl = TextEditingController(text: item?.category.toString() ?? 'General');
    final isActiveCtrl = TextEditingController(text: item?.isActive.toString() ?? '1');


    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Question' : 'New Question'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: textCtrl, decoration: const InputDecoration(labelText: 'Question Text'), keyboardType: TextInputType.text),
              TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category'), keyboardType: TextInputType.text),
              TextField(controller: isActiveCtrl, decoration: const InputDecoration(labelText: 'Is Active (1=Yes, 0=No)'), keyboardType: TextInputType.number),

            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newObj = ChecklistQuestion(
                id: item?.id,
                text: textCtrl.text,
                category: categoryCtrl.text,
                isActive: int.tryParse(isActiveCtrl.text) ?? 1,

              );
              if (isEditing) {
                await _repo.updateQuestion(newObj);
              } else {
                await _repo.insertQuestion(newObj);
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

  void _showDetailSheet(ChecklistQuestion item) {
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
                      await _repo.deleteQuestion(item.id!);
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
    final filteredItems = _items.where((item) => item.text.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        title: const Text('Checklist Questions Config', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF004D40),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFFFFD700),
        icon: const Icon(Icons.add, color: Color(0xFF004D40)),
        label: const Text('New Question', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
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
                                  leading: const CircleAvatar(backgroundColor: Color(0xFF004D40), foregroundColor: Colors.white, child: Icon(Icons.question_answer, size: 18)),
                                  title: Text(item.text, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Category: ${item.category} | Active: ${item.isActive == 1 ? "Yes" : "No"}'),
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

import 'package:flutter/material.dart';

class SyllabusLevelEditScreen extends StatefulWidget {
  const SyllabusLevelEditScreen({super.key});

  @override
  State<SyllabusLevelEditScreen> createState() => _SyllabusLevelEditScreenState();
}

class _SyllabusLevelEditScreenState extends State<SyllabusLevelEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inputController1 = TextEditingController();
  final _inputController2 = TextEditingController();
  String _selectedValue = 'Option A';
  bool _isSaving = false;

  @override
  void dispose() {
    _inputController1.dispose();
    _inputController2.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    
    // Simulate repository database persistence
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved securely to local storage'),
          backgroundColor: Color(0xFF004D40),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text(
          'Edit Grade Level',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF004D40), // Dark green
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Grade Level Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Modify targets and requirements for a syllabus level.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 28),
                
                // Form field 1
                const Text('Field Name 1', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _inputController1,
                  decoration: InputDecoration(
                    hintText: 'Enter value',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Required field' : null,
                ),
                const SizedBox(height: 20),
                
                // Form field 2
                const Text('Field Name 2', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _inputController2,
                  decoration: InputDecoration(
                    hintText: 'Enter details',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // Selector field
                const Text('Selection Metric', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black38),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedValue,
                      isExpanded: true,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedValue = newValue);
                        }
                      },
                      items: <String>['Option A', 'Option B', 'Option C']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submitData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700), // Gold
                      foregroundColor: const Color(0xFF004D40),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Color(0xFF004D40), strokeWidth: 2),
                          )
                        : const Text('Save Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

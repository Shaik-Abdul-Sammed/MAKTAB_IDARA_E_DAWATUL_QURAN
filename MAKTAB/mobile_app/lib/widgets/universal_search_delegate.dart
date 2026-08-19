import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/services/database_helper.dart';

class UniversalSearchDelegate extends SearchDelegate {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(child: Text('Type to search for students...'));
    }

    return FutureBuilder<List<Student>>(
      future: _searchStudents(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No students found.'));
        }

        final students = snapshot.data!;

        return ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF004D40),
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(student.name),
              subtitle: Text('ID: ${student.admissionNumber}'),
              onTap: () {
                close(context, null);
                // Depending on admin or teacher, route appropriately
                // But for now, assuming admin route is available:
                if (GoRouterState.of(context).uri.toString().contains('/admin')) {
                  context.push('/admin/students/profile', extra: student);
                }
              },
            );
          },
        );
      },
    );
  }

  Future<List<Student>> _searchStudents(String query) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'name LIKE ? OR admission_number LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 10,
    );
    return List.generate(maps.length, (i) {
      return Student.fromMap(maps[i]);
    });
  }
}

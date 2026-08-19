import 'package:flutter/foundation.dart';

class ChecklistItem {
  final String id;
  final String title;
  final String category;
  bool isCompleted;

  ChecklistItem({
    required this.id,
    required this.title,
    required this.category,
    this.isCompleted = false,
  });
}

class DailyChecklistProvider extends ChangeNotifier {
  final List<ChecklistItem> _items = [
    ChecklistItem(id: '1', title: 'Verify classroom cleanliness & seating arrangement', category: 'Environment'),
    ChecklistItem(id: '2', title: 'Check Wudhu (ablution) status of all students', category: 'Preparation'),
    ChecklistItem(id: '3', title: 'Recite Opening Dua & Surah Al-Fatiha collectively', category: 'Routine'),
    ChecklistItem(id: '4', title: 'Mark daily attendance in app', category: 'Records'),
    ChecklistItem(id: '5', title: 'Listen to Sabaq (New Lesson) for each student', category: 'Recitation'),
    ChecklistItem(id: '6', title: 'Grade Sabaqi (Recent Revision)', category: 'Recitation'),
    ChecklistItem(id: '7', title: 'Review Manzil (Old Revision)', category: 'Recitation'),
    ChecklistItem(id: '8', title: 'Conduct Tajweed rule demonstration (10 mins)', category: 'Lesson'),
    ChecklistItem(id: '9', title: 'Recite Closing Dua & Dismissal', category: 'Routine'),
  ];

  List<ChecklistItem> get items => List.unmodifiable(_items);

  int get totalCount => _items.length;
  int get completedCount => _items.where((i) => i.isCompleted).length;
  double get completionRatio => totalCount == 0 ? 0.0 : completedCount / totalCount;
  int get completionPercentage => (completionRatio * 100).round();

  void toggleItem(String id) {
    final item = _items.firstWhere((i) => i.id == id);
    item.isCompleted = !item.isCompleted;
    notifyListeners();
  }

  void markAllCompleted() {
    for (var item in _items) {
      item.isCompleted = true;
    }
    notifyListeners();
  }

  void addItem(String title, String category) {
    final newId = (DateTime.now().millisecondsSinceEpoch).toString();
    _items.add(ChecklistItem(id: newId, title: title, category: category.isEmpty ? 'Custom' : category));
    notifyListeners();
  }

  void resetChecklist() {
    for (var item in _items) {
      item.isCompleted = false;
    }
    notifyListeners();
  }
}

class Announcement {
  final int? id;
  final String title;
  final String content;
  final String date;
  final int batchId;

  Announcement({this.id, required this.title, required this.content, required this.date, required this.batchId});

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'content': content, 'date': date, 'batch_id': batchId};
  factory Announcement.fromMap(Map<String, dynamic> map) => Announcement(
    id: map['id'], title: map['title'], content: map['content'], date: map['date'], batchId: map['batch_id']
  );
}
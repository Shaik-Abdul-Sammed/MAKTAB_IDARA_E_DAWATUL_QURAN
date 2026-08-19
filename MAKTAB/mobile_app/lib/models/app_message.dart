class AppMessage {
  final int? id;
  final int senderId;
  final int? receiverId; // Null for broadcast messages
  final String content;
  final DateTime timestamp;
  final bool isRead;

  AppMessage({
    this.id,
    required this.senderId,
    this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead ? 1 : 0,
    };
  }

  factory AppMessage.fromMap(Map<String, dynamic> map) {
    return AppMessage(
      id: map['id'],
      senderId: map['sender_id'],
      receiverId: map['receiver_id'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
      isRead: map['is_read'] == 1,
    );
  }

  AppMessage copyWith({
    int? id,
    int? senderId,
    int? receiverId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return AppMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

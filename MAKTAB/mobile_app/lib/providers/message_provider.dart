import 'package:flutter/material.dart';
import 'package:maktab_app/models/app_message.dart';
import 'package:maktab_app/repositories/message_repository.dart';

class MessageProvider with ChangeNotifier {
  final MessageRepository _repository = MessageRepository();

  List<AppMessage> _userMessages = [];
  List<AppMessage> _currentConversation = [];
  bool _isLoading = false;

  List<AppMessage> get userMessages => _userMessages;
  List<AppMessage> get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;

  // Load all messages for a specific user (inbox view)
  Future<void> loadUserMessages(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userMessages = await _repository.getMessagesForUser(userId);
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load conversation between two users
  Future<void> loadConversation(int user1Id, int user2Id) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentConversation = await _repository.getConversation(user1Id, user2Id);
    } catch (e) {
      debugPrint('Error loading conversation: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load broadcast messages (Admin perspective or global list)
  Future<void> loadBroadcastMessages() async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentConversation = await _repository.getBroadcastMessages();
    } catch (e) {
      debugPrint('Error loading broadcasts: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // Send a direct message
  Future<void> sendMessage(int senderId, int receiverId, String content) async {
    final msg = AppMessage(
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      timestamp: DateTime.now(),
      isRead: false,
    );
    await _repository.insertMessage(msg);
    await loadConversation(senderId, receiverId);
  }

  // Send a broadcast message
  Future<void> sendBroadcastMessage(int senderId, String content) async {
    final msg = AppMessage(
      senderId: senderId,
      receiverId: null, // Null indicates broadcast
      content: content,
      timestamp: DateTime.now(),
      isRead: false,
    );
    await _repository.insertMessage(msg);
    // Reload broadcast messages or whatever context we are in
    await loadBroadcastMessages();
  }

  Future<void> markAsRead(int messageId) async {
    await _repository.markAsRead(messageId);
    // Re-fetch depending on the active context, for now just update the local item if possible
    final idx = _userMessages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _userMessages[idx] = _userMessages[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }
}

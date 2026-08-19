import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/providers/message_provider.dart';
import 'package:maktab_app/widgets/custom_app_bar.dart';

class ChatScreen extends StatefulWidget {
  final int otherUserId; // 0 for broadcast if admin, or 1 for admin if teacher
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
  }

  void _loadMessages() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final msgProvider = Provider.of<MessageProvider>(context, listen: false);
    
    if (widget.otherUserId == 0) {
      msgProvider.loadBroadcastMessages();
    } else {
      msgProvider.loadConversation(auth.currentUser!.id!, widget.otherUserId);
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final msgProvider = Provider.of<MessageProvider>(context, listen: false);
    final content = _controller.text.trim();
    _controller.clear();

    if (widget.otherUserId == 0 && auth.currentUser?.role == 'admin') {
      await msgProvider.sendBroadcastMessage(auth.currentUser!.id!, content);
    } else {
      await msgProvider.sendMessage(auth.currentUser!.id!, widget.otherUserId, content);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUserId = auth.currentUser?.id ?? 0;

    return Scaffold(
      appBar: CustomAppBar(title: widget.otherUserName),
      body: Column(
        children: [
          Expanded(
            child: Consumer<MessageProvider>(
              builder: (context, msgProvider, child) {
                if (msgProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = msgProvider.currentConversation;
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                return ListView.builder(
                  reverse: false, // We'll just show oldest at top, or sort them appropriately
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF004D40) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                            bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
                          ),
                        ),
                        child: Text(
                          msg.content,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                // If it's a broadcast view and the user is NOT admin, they cannot reply to broadcast
                if (!(widget.otherUserId == 0 && auth.currentUser?.role != 'admin'))
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF004D40)),
                    onPressed: _sendMessage,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/online_service.dart';
import '../theme.dart';

// ponytail: lightweight online chat panel widget for lobby and game screen

class OnlineChatWidget extends StatefulWidget {
  final OnlineService onlineService;
  final String playerName;

  const OnlineChatWidget({
    super.key,
    required this.onlineService,
    required this.playerName,
  });

  static void showChatModal(BuildContext context, OnlineService service, String playerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: OnlineChatWidget(
          onlineService: service,
          playerName: playerName,
        ),
      ),
    );
  }

  @override
  State<OnlineChatWidget> createState() => _OnlineChatWidgetState();
}

class _OnlineChatWidgetState extends State<OnlineChatWidget> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];

  static const List<String> _quickPhrases = [
    'Good luck! 🎲',
    'Nice move! 👏',
    'Ouch! 😅',
    'Play fast! ⚡',
    'GG! 🏆',
  ];

  @override
  void initState() {
    super.initState();
    _messages = widget.onlineService.currentChatMessages();
    widget.onlineService.chatStream.listen((msgs) {
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? customText]) {
    final text = customText ?? _msgController.text;
    if (text.trim().isEmpty) return;

    widget.onlineService.sendChatMessage(text, senderName: widget.playerName);
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF00E5FF), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Live Chat',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Say hi! 👋',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == widget.onlineService.localPlayerId;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 260),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                                  : AppTheme.bg3,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isMe
                                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.6)
                                    : AppTheme.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.senderName,
                                  style: TextStyle(
                                    color: isMe ? const Color(0xFFEC4899) : AppTheme.accentLight,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  msg.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Quick phrases row
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _quickPhrases.length,
              itemBuilder: (context, index) {
                final phrase = _quickPhrases[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    label: Text(
                      phrase,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    backgroundColor: AppTheme.bg3,
                    side: BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onPressed: () => _sendMessage(phrase),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Input bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textInputAction: TextInputAction.send,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 3,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type any message...',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.bg3,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC4899).withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

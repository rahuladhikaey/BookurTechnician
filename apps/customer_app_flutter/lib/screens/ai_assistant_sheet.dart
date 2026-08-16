import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../models/ai_assistant_models.dart';
import '../services/ai_assistant_service.dart';
import '../theme.dart';

class AiAssistantSheet extends ConsumerStatefulWidget {
  const AiAssistantSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiAssistantSheet(),
    );
  }

  @override
  ConsumerState<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends ConsumerState<AiAssistantSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isAssistantTyping = false;
  String? _selectedQuickActionLabel;

  @override
  void initState() {
    super.initState();
    _initWelcomeMessage();
  }

  void _initWelcomeMessage() {
    _messages.add(
      ChatMessage(
        id: 'msg_welcome',
        text: AiAssistantService.welcomeMessageText,
        sender: ChatSender.assistant,
        timestamp: DateTime.now(),
        quickActions: AiAssistantService.defaultQuickActions,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage([String? overrideText]) async {
    final text = (overrideText ?? _textController.text).trim();
    if (text.isEmpty) return;

    if (overrideText == null) {
      _textController.clear();
    }

    final userMsg = ChatMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      sender: ChatSender.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isAssistantTyping = true;
    });
    _scrollToBottom();

    final appState = ref.read(bookingProvider);
    final response = await AiAssistantService.processUserQuery(
      query: text,
      appState: appState,
      conversationHistory: _messages,
    );

    if (mounted) {
      setState(() {
        _isAssistantTyping = false;
        _messages.add(response);
      });
      _scrollToBottom();
    }
  }

  void _handleQuickActionTap(ChatQuickAction action) {
    setState(() {
      _selectedQuickActionLabel = action.label;
    });
    _handleSendMessage(action.queryText);
  }

  void _handleCardAction(ChatActionCard card) {
    Navigator.of(context).pop(); // Close assistant modal
    if (card.routeName.isNotEmpty) {
      Navigator.of(context).pushNamed(card.routeName, arguments: card.routeArguments);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    return Container(
      height: screenHeight * 0.88,
      margin: EdgeInsets.only(top: mediaQuery.padding.top),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ─── CHATBOT HEADER ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: kBrandPrimary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('💬', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bookur Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Your BookurTechnician Help',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // ─── MESSAGES LIST ───
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length + (_isAssistantTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isAssistantTyping) {
                  return _buildTypingBubble();
                }
                final msg = _messages[index];
                return _buildMessageItem(msg);
              },
            ),
          ),

          // ─── BOTTOM QUICK ACTION CHIPS (HORIZONTAL SCROLL) ───
          if (_messages.isNotEmpty && _messages.last.quickActions != null)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _messages.last.quickActions!.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final action = _messages.last.quickActions![idx];
                  final isSelected = action.label == _selectedQuickActionLabel;
                  return InkWell(
                    onTap: () => _handleQuickActionTap(action),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? kBrandPrimary : Colors.white,
                        border: Border.all(
                          color: kBrandPrimary,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        action.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : kBrandPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // ─── INPUT COMPOSER ───
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, keyboardHeight > 0 ? keyboardHeight + 8 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFD9E2F2)),
                    ),
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ask about services, prices, refunds...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _handleSendMessage(),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: kBrandPrimary,
                      shape: BoxShape.circle,
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

  Widget _buildMessageItem(ChatMessage msg) {
    final isUser = msg.sender == ChatSender.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Bubble
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? kBrandPrimary : const Color(0xFFEEF3FF),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isUser ? 14 : 2),
                bottomRight: Radius.circular(isUser ? 2 : 14),
              ),
              border: isUser ? null : Border.all(color: const Color(0xFFD9E2F2)),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF111827),
                fontSize: 13.5,
                height: 1.45,
                fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),

          // Action Card (If attached)
          if (msg.actionCard != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD9E2F2), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.actionCard!.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg.actionCard!.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () => _handleCardAction(msg.actionCard!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlack,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        msg.actionCard!.buttonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF3FF),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomRight: Radius.circular(14),
            bottomLeft: Radius.circular(2),
          ),
          border: Border.all(color: const Color(0xFFD9E2F2)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bookur Assistant is typing ', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
            Text('● ● ●', style: TextStyle(color: kBrandPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

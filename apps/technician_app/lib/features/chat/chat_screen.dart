import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/network/dio_client.dart';
import '../../core/security/secure_storage.dart';

class TechnicianChatScreen extends StatefulWidget {
  final String bookingId;
  final String? customerName;
  final String? serviceName;

  const TechnicianChatScreen({
    super.key,
    required this.bookingId,
    this.customerName,
    this.serviceName,
  });

  @override
  State<TechnicianChatScreen> createState() => _TechnicianChatScreenState();
}

class _TechnicianChatScreenState extends State<TechnicianChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DioClient _dioClient = DioClient(SecureStorage());
  Timer? _pollingTimer;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  final String _technicianId = 'tech-me';

  final List<String> _quickReplies = [
    "I have arrived at your building.",
    "On the way, estimated 10 mins.",
    "Please share flat or gate code.",
    "Please keep appliance accessible.",
    "Service completed, requesting End OTP.",
  ];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchMessages(silent: true));
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final res = await _dioClient.dio.get('/bookings/${widget.bookingId}/messages');
      if (res.data != null && res.data['success'] == true && res.data['data'] is List) {
        final fetched = List<Map<String, dynamic>>.from(res.data['data']);
        if (mounted) {
          setState(() {
            _messages = fetched;
            _isLoading = false;
          });
          if (!silent) _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Tech Chat] Fetch error: $e');
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage([String? customText]) async {
    final text = (customText ?? _msgController.text).trim();
    if (text.isEmpty) return;

    if (customText == null) {
      _msgController.clear();
    }

    final localMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'booking_id': widget.bookingId,
      'sender_id': _technicianId,
      'sender_role': 'TECHNICIAN',
      'message': text,
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(localMsg);
    });
    _scrollToBottom();

    try {
      await _dioClient.dio.post(
        '/bookings/${widget.bookingId}/messages',
        data: {'message': text},
      );
      _fetchMessages(silent: true);
    } catch (e) {
      debugPrint('⚠️ [Tech Chat] Send error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _initiateMaskedCall() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Privacy-Protected Partner Call',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Customer phone numbers are masked to protect customer privacy and partner compliance. Call connects through BookurTechnician telecom bridge.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📞 Connecting via BT Telecom Bridge: 1800-889-TECH'),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                },
                icon: const Icon(Icons.call),
                label: const Text('Call via Telecom Relay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final custName = widget.customerName ?? 'Customer';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1635),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              custName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              '${widget.serviceName ?? "Service Job"} • Secured In-App Chat',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk, color: Color(0xFF22C55E)),
            tooltip: 'Secured Masked Call',
            onPressed: _initiateMaskedCall,
          ),
        ],
      ),
      body: Column(
        children: [
          // Security disclaimer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Icon(Icons.verified_user, size: 16, color: Color(0xFF475569)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chat is monitored for partner safety and job quality dispute resolution.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Message list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Send an update to $custName',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final role = (msg['sender_role'] ?? msg['senderRole'] ?? '').toString().toUpperCase();
                          final isMe = role == 'TECHNICIAN';
                          final text = msg['message'] ?? msg['text'] ?? '';
                          final timeStr = msg['created_at'] ?? msg['createdAt'] ?? '';

                          DateTime? parsedDate;
                          try {
                            parsedDate = DateTime.parse(timeStr).toLocal();
                          } catch (_) {}

                          final displayTime = parsedDate != null ? DateFormat('hh:mm a').format(parsedDate) : '';

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF17399A) : Colors.grey.shade100,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black87,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        displayTime,
                                        style: TextStyle(
                                          color: isMe ? Colors.white70 : Colors.grey.shade500,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.done_all, size: 12, color: Colors.white70),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Quick replies
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _quickReplies.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final reply = _quickReplies[i];
                return ActionChip(
                  label: Text(reply, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(color: Colors.grey.shade300),
                  onPressed: () => _sendMessage(reply),
                );
              },
            ),
          ),

          // Text input
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message to customer...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFF17399A)),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF17399A),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

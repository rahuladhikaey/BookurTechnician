import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/api_client.dart';
import '../theme.dart';

class BookingChatScreen extends StatefulWidget {
  final String bookingId;
  final String? bookingCode;
  final String? technicianName;
  final String? technicianAvatar;

  const BookingChatScreen({
    super.key,
    required this.bookingId,
    this.bookingCode,
    this.technicianName,
    this.technicianAvatar,
  });

  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  io.Socket? _socket;
  Timer? _pollingTimer;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String _currentUserId = '';

  final List<String> _quickReplies = [
    "I'm at home.",
    "Please call when you reach.",
    "Need help finding my location?",
    "Gate passcode is 4022.",
    "Please bring spare switches.",
  ];

  @override
  void initState() {
    super.initState();
    _initUserAndChat();
  }

  Future<void> _initUserAndChat() async {
    final session = await ApiClient.getUserSession();
    _currentUserId = session['userId'] ?? 'customer-guest';

    await _fetchMessages();
    _connectSocket();

    // Fallback polling every 5s if socket disconnects
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchMessages(silent: true));
  }

  void _connectSocket() {
    try {
      final wsUrl = ApiClient.activeBaseUrl.replaceAll('/api/v1', '');
      _socket = io.io(
        wsUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      _socket?.connect();

      _socket?.onConnect((_) {
        debugPrint('💬 [Chat Socket] Connected to $wsUrl for booking ${widget.bookingId}');
        _socket?.emit('join:booking', {'bookingId': widget.bookingId});
      });

      _socket?.on('chat:message', (data) {
        if (mounted && data != null) {
          final msgData = Map<String, dynamic>.from(data);
          if (msgData['bookingId'] == widget.bookingId || msgData['booking_id'] == widget.bookingId) {
            setState(() {
              _messages.add(msgData);
            });
            _scrollToBottom();
          }
        }
      });
    } catch (e) {
      debugPrint('⚠️ [Chat Socket] Connection error: $e');
    }
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get('/bookings/${widget.bookingId}/messages');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['success'] == true && decoded['data'] is List) {
          final fetched = List<Map<String, dynamic>>.from(decoded['data']);
          if (mounted) {
            setState(() {
              _messages = fetched;
              _isLoading = false;
            });
            if (!silent) _scrollToBottom();
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Chat] Fetch error: $e');
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
      'sender_id': _currentUserId,
      'sender_role': 'CUSTOMER',
      'message': text,
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(localMsg);
    });
    _scrollToBottom();

    try {
      final res = await ApiClient.post(
        '/bookings/${widget.bookingId}/messages',
        {'message': text},
      );

      if (_socket != null && _socket!.connected) {
        _socket!.emit('chat:send', {
          'bookingId': widget.bookingId,
          'senderId': _currentUserId,
          'senderRole': 'CUSTOMER',
          'message': text,
        });
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _fetchMessages(silent: true);
      }
    } catch (e) {
      debugPrint('⚠️ [Chat] Send error: $e');
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
            const Icon(Icons.shield_outlined, color: AppColors.primary, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Privacy-Protected Call',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your personal phone number is masked. BookurTechnician connects you securely via our telecom bridge.',
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
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.call),
                label: const Text('Call via Virtual Bridge'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
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
    _socket?.disconnect();
    _socket?.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final techName = widget.technicianName ?? 'Assigned Technician';
    final code = widget.bookingCode ?? widget.bookingId;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: widget.technicianAvatar != null && widget.technicianAvatar!.isNotEmpty
                  ? ClipOval(child: Image.network(widget.technicianAvatar!, fit: BoxFit.cover, width: 36, height: 36))
                  : const Icon(Icons.handyman, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    techName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Order #$code • In-App Secured Chat',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk, color: AppColors.primary),
            tooltip: 'Secured Masked Call',
            onPressed: _initiateMaskedCall,
          ),
        ],
      ),
      body: Column(
        children: [
          // Security banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.amber.shade50,
            child: Row(
              children: [
                Icon(Icons.lock_clock, size: 16, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'End-to-end audit logged. Never share OTP or personal bank PINs.',
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
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
                              'Start conversation with $techName',
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
                          final isMe = role == 'CUSTOMER' || msg['sender_id'] == _currentUserId;
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
                                color: isMe ? AppColors.primary : Colors.grey.shade100,
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

          // Quick reply chips
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

          // Text entry field
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
                        hintText: 'Type a message to technician...',
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
                          borderSide: const BorderSide(color: AppColors.primary),
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
                      color: AppColors.primary,
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

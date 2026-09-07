import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';
import 'audio_alert_service.dart';
import 'notification_service.dart';
import '../../features/dispatch/presentation/incoming_job_alert_dialog.dart';

/// Centralized Real-time Socket.io Dispatch & Ringing Service for Technician App
class TechnicianSocketService {
  static final TechnicianSocketService _instance = TechnicianSocketService._internal();
  factory TechnicianSocketService() => _instance;
  TechnicianSocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  String? _currentTechnicianId;
  String? _currentPhone;
  String _currentCategory = 'electrician';
  int _candidateUrlIndex = 0;

  bool get isConnected => _isConnected;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Initialize and connect to Node.js Core Service Dispatch Engine
  void connect({
    required String technicianId,
    String? phone,
    String category = 'electrician',
  }) {
    _currentTechnicianId = technicianId;
    if (phone != null && phone.isNotEmpty) _currentPhone = phone;
    if (category.isNotEmpty) _currentCategory = category;

    if (_socket != null && _socket!.connected) {
      _joinRooms();
      return;
    }

    _attemptConnect();
  }

  void _attemptConnect() {
    const candidateUrls = AppConfig.candidateSocketUrls;
    if (candidateUrls.isEmpty) return;

    final url = candidateUrls[_candidateUrlIndex % candidateUrls.length];
    debugPrint('🔌 [TechnicianSocket] Connecting to dispatch socket: $url (index: $_candidateUrlIndex)');

    try {
      _socket?.dispose();
      _socket = io.io(
        url,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)
            .setTimeout(5000)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('✅ [TechnicianSocket] Connected to Dispatch Socket: ${_socket!.id} on $url');
        _joinRooms();
      });

      _socket!.onConnectError((err) {
        _isConnected = false;
        debugPrint('⚠️ [TechnicianSocket] Socket connection error ($url): $err');
        _rotateCandidateUrl();
      });

      _socket!.onConnectTimeout((_) {
        _isConnected = false;
        debugPrint('⚠️ [TechnicianSocket] Socket connection timeout ($url)');
        _rotateCandidateUrl();
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('⚠️ [TechnicianSocket] Disconnected from dispatch socket');
      });

      // ─── 1. REAL-TIME AUDIBLE DISPATCH RINGING & ASSIGNMENT EVENTS ──────────
      _socket!.on('booking:dispatch_ringing', (data) {
        debugPrint('🚨 [TechnicianSocket] Incoming Dispatch Ringing: $data');
        _handleIncomingJobAlert(data is Map ? Map<String, dynamic>.from(data) : {});
      });

      _socket!.on('booking:assigned', (data) {
        debugPrint('🎯 [TechnicianSocket] Direct Booking Assigned: $data');
        _handleIncomingJobAlert(data is Map ? Map<String, dynamic>.from(data) : {});
      });

      _socket!.on('booking:new_available', (data) {
        debugPrint('📢 [TechnicianSocket] New Job Available in Category: $data');
        _handleIncomingJobAlert(data is Map ? Map<String, dynamic>.from(data) : {});
      });

      _socket!.on('booking:dispatch', (data) {
        debugPrint('⚡ [TechnicianSocket] Booking Dispatched: $data');
        _handleIncomingJobAlert(data is Map ? Map<String, dynamic>.from(data) : {});
      });

      _socket!.on('proposal:new', (data) {
        debugPrint('📋 [TechnicianSocket] New Proposal Received: $data');
        _handleIncomingJobAlert(data is Map ? Map<String, dynamic>.from(data) : {});
      });

      _socket!.on('job:assigned', (data) {
        debugPrint('🛎️ [TechnicianSocket] Job Assigned: $data');
        _handleIncomingJobAlert(data is Map ? Map<String, dynamic>.from(data) : {});
      });

      // ─── 2. NEW SERVICE ANNOUNCEMENT NOTIFICATION ──────────────────────────
      _socket!.on('notification:new_service', (data) {
        debugPrint('🎉 [TechnicianSocket] New Service Added by Admin: $data');
        _handleNewServiceAnnouncement(data is Map ? Map<String, dynamic>.from(data) : {});
      });

      // ─── 3. BOOKING CANCELLED / TAKEN BY ANOTHER TECH ──────────────────────
      _socket!.on('booking:cancelled', (_) {
        AudioAlertService().stopAlert();
      });

      _socket!.on('booking:claimed', (_) {
        AudioAlertService().stopAlert();
      });

      _socket!.on('booking:rejected', (_) {
        AudioAlertService().stopAlert();
      });

      _socket!.on('booking:accepted', (_) {
        AudioAlertService().stopAlert();
      });

    } catch (e) {
      debugPrint('❌ [TechnicianSocket] Socket initialization error: $e');
    }
  }

  void _rotateCandidateUrl() {
    const candidateUrls = AppConfig.candidateSocketUrls;
    if (candidateUrls.isEmpty) return;
    _candidateUrlIndex = (_candidateUrlIndex + 1) % candidateUrls.length;
  }

  void _joinRooms() {
    if (_socket == null || !_socket!.connected) return;

    final techId = _currentTechnicianId;
    final phone = _currentPhone;
    final cat = _currentCategory.toLowerCase();

    debugPrint('🤝 [TechnicianSocket] Joining rooms: techId=$techId, phone=$phone, cat=$cat');

    _socket!.emit('technician:join', {
      'technicianId': techId ?? '',
      'phone': phone ?? '',
      'category': cat,
    });

    if (techId != null && techId.isNotEmpty) {
      _socket!.emit('join:room', 'tech_$techId');
    }
    if (phone != null && phone.isNotEmpty) {
      _socket!.emit('join:room', 'tech_$phone');
    }
    _socket!.emit('join:room', 'category_$cat');
    _socket!.emit('join:room', 'global_dispatch');
  }

  /// Triggers loud audio ringtone, haptic vibration, and full-screen incoming job modal
  void _handleIncomingJobAlert(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    // 1. Play loud looping incoming ringtone & vibration
    AudioAlertService().startJobAlertRingtone();

    // 2. Show system notification banner
    NotificationService().showJobAlertNotification(data);

    // 3. Pop up Full-Screen pulsating incoming job modal
    if (_navigatorKey?.currentContext != null) {
      final context = _navigatorKey!.currentContext!;
      IncomingJobAlertOverlay.show(
        context: context,
        proposalId: data['proposalId']?.toString() ?? 'prop-${DateTime.now().millisecondsSinceEpoch}',
        bookingId: data['bookingId']?.toString() ?? data['id']?.toString() ?? '',
        serviceType: data['serviceType']?.toString() ?? data['serviceName']?.toString() ?? 'Emergency Repair',
        customerName: data['customerName']?.toString() ?? 'Customer',
        customerAddress: data['customerAddress']?.toString() ?? data['address']?.toString() ?? 'Service Address',
        distanceKm: data['distanceKm']?.toString() ?? '1.8',
        payout: data['payout']?.toString() ?? '350',
        timeoutSeconds: int.tryParse(data['timeoutSeconds']?.toString() ?? '45') ?? 45,
      );
    }
  }

  /// Displays celebratory banner when Admin launches a new service
  void _handleNewServiceAnnouncement(Map<String, dynamic> data) {
    if (_navigatorKey?.currentContext != null) {
      final context = _navigatorKey!.currentContext!;
      final name = data['serviceName'] ?? data['title'] ?? 'New Service';
      final category = data['categoryName'] ?? 'General';
      final price = data['price'] ?? 199;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New Service Added by Admin!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                    Text('$name ($category) • ₹$price', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Emits real-time live GPS updates over websocket for instantaneous customer tracking
  void emitLocationUpdate({
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
    String? category,
  }) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('technician:location:update', {
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'heading': heading,
        'category': category ?? _currentCategory,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Disconnect socket
  void disconnect() {
    AudioAlertService().stopAlert();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}

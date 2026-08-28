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

  bool get isConnected => _isConnected;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Initialize and connect to Node.js Core Service Dispatch Engine
  void connect({required String technicianId, String category = 'electrician'}) {
    if (_socket != null && _socket!.connected) return;

    try {
      const String url = AppConfig.socketUrl;
      debugPrint('🔌 [TechnicianSocket] Connecting to dispatch engine: $url');

      _socket = io.io(
        url,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(999)
            .setReconnectionDelay(2000)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('✅ [TechnicianSocket] Connected to Dispatch Socket: ${_socket!.id}');

        // Join personal and category rooms
        _socket!.emit('technician:join', {
          'technicianId': technicianId,
          'category': category.toLowerCase(),
        });
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('⚠️ [TechnicianSocket] Disconnected from dispatch socket');
      });

      // ─── 1. REAL-TIME AUDIBLE DISPATCH RINGING EVENT ───────────────────────
      _socket!.on('booking:dispatch_ringing', (data) {
        debugPrint('🚨 [TechnicianSocket] Incoming Dispatch Ringing: $data');
        _handleIncomingJobAlert(data is Map ? Map<String, dynamic>.from(data) : {});
      });

      _socket!.on('booking:new_available', (data) {
        debugPrint('📢 [TechnicianSocket] New Job Available in Category: $data');
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

    } catch (e) {
      debugPrint('❌ [TechnicianSocket] Connection Error: $e');
    }
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

  /// Disconnect socket
  void disconnect() {
    AudioAlertService().stopAlert();
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
  }
}

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../network/dio_client.dart';
import 'audio_alert_service.dart';
import '../../features/dispatch/presentation/incoming_job_alert_dialog.dart';

enum BookingRequestState {
  idle,
  showingProposal,
  accepting,
  declining,
  accepted,
  declined,
  expired,
}

class JobProposalData {
  final String proposalId;
  final String bookingId;
  final String serviceType;
  final String serviceName;
  final String customerName;
  final String customerAddress;
  final String distanceKm;
  final String payout;
  final String totalAmount;
  final int timeoutSeconds;
  final String? expiresAt;
  final String? createdAt;

  const JobProposalData({
    required this.proposalId,
    required this.bookingId,
    required this.serviceType,
    required this.serviceName,
    required this.customerName,
    required this.customerAddress,
    required this.distanceKm,
    required this.payout,
    this.totalAmount = '499',
    this.timeoutSeconds = 30,
    this.expiresAt,
    this.createdAt,
  });

  factory JobProposalData.fromMap(Map<String, dynamic> data) {
    final rawPayout = data['payout'] ?? data['estimatedEarning'] ?? data['amount'] ?? '350';
    final rawTotal = data['totalAmount'] ?? data['price'] ?? '499';
    final srvType = data['serviceType'] ?? data['serviceName'] ?? data['category'] ?? 'Service Request';

    return JobProposalData(
      proposalId: data['proposalId']?.toString() ??
          data['dispatchRequestId']?.toString() ??
          data['id']?.toString() ??
          'prop-${DateTime.now().millisecondsSinceEpoch}',
      bookingId: data['bookingId']?.toString() ?? data['id']?.toString() ?? '',
      serviceType: srvType.toString(),
      serviceName: (data['serviceName'] ?? srvType).toString(),
      customerName: (data['customerName'] ?? data['customer'] ?? 'Customer').toString(),
      customerAddress: (data['customerAddress'] ?? data['address'] ?? 'Nearby Customer Address').toString(),
      distanceKm: (data['distanceKm'] ?? '1.8').toString(),
      payout: rawPayout.toString(),
      totalAmount: rawTotal.toString(),
      timeoutSeconds: int.tryParse(data['timeoutSeconds']?.toString() ?? '30') ?? 30,
      expiresAt: data['expiresAt']?.toString(),
      createdAt: data['createdAt']?.toString(),
    );
  }
}

/// Centralized Singleton Manager for Real-Time Dispatch Requests across all Technician screens
class BookingRequestManager {
  static final BookingRequestManager _instance = BookingRequestManager._internal();
  factory BookingRequestManager() => _instance;
  BookingRequestManager._internal();

  GlobalKey<NavigatorState>? _navigatorKey;
  BuildContext? _activeDialogContext;
  JobProposalData? _currentProposal;
  BookingRequestState _state = BookingRequestState.idle;

  // Deduplication set storing recently processed proposal/dispatch IDs
  final Set<String> _processedRequestIds = {};

  BookingRequestState get state => _state;
  JobProposalData? get currentProposal => _currentProposal;
  bool get isShowingPopup => _state == BookingRequestState.showingProposal;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Central entry point for incoming requests from WebSocket and FCM Push Notifications
  void handleIncomingRequest(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final proposal = JobProposalData.fromMap(data);
    if (proposal.bookingId.isEmpty && proposal.proposalId.isEmpty) return;

    final deduplicationKey = '${proposal.proposalId}_${proposal.bookingId}';

    // Deduplication check: ignore if this exact request was already handled in the last 45 seconds
    if (_processedRequestIds.contains(deduplicationKey) && isShowingPopup) {
      debugPrint('ℹ️ [BookingRequestManager] Request $deduplicationKey already active/showing. Skipping duplicate.');
      return;
    }

    _processedRequestIds.add(deduplicationKey);
    _scheduleDeduplicationCleanup(deduplicationKey);

    debugPrint('🚨 [BookingRequestManager] Processing incoming request: ${proposal.proposalId} for booking: ${proposal.bookingId}');

    // 1. Play loud incoming ringtone & emergency vibration
    AudioAlertService().startJobAlertRingtone();

    // 2. Present In-App Popup automatically
    _currentProposal = proposal;
    _state = BookingRequestState.showingProposal;

    _presentIncomingJobPopup(proposal);
  }

  void _scheduleDeduplicationCleanup(String key) {
    Timer(const Duration(seconds: 45), () {
      _processedRequestIds.remove(key);
    });
  }

  /// Safely presents the Incoming Job Alert overlay dialog using the root navigator
  void _presentIncomingJobPopup(JobProposalData proposal) {
    // If a dialog is already showing, dismiss it first
    dismissActiveDialog();

    final navContext = _navigatorKey?.currentContext;
    if (navContext == null) {
      debugPrint('⚠️ [BookingRequestManager] Navigator context unavailable, queuing dialog presentation...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final delayedContext = _navigatorKey?.currentContext;
        if (delayedContext != null && _state == BookingRequestState.showingProposal) {
          _showDialogOnContext(delayedContext, proposal);
        }
      });
      return;
    }

    _showDialogOnContext(navContext, proposal);
  }

  void _showDialogOnContext(BuildContext context, JobProposalData proposal) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Incoming Job Alert',
      barrierColor: Colors.black.withAlpha(220),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogCtx, anim1, anim2) {
        _activeDialogContext = dialogCtx;
        return IncomingJobAlertOverlay(
          proposalId: proposal.proposalId,
          bookingId: proposal.bookingId,
          serviceType: proposal.serviceType,
          customerName: proposal.customerName,
          customerAddress: proposal.customerAddress,
          distanceKm: proposal.distanceKm,
          payout: proposal.payout,
          timeoutSeconds: proposal.timeoutSeconds,
        );
      },
      transitionBuilder: (dialogCtx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    ).then((_) {
      _activeDialogContext = null;
      if (_state == BookingRequestState.showingProposal) {
        _state = BookingRequestState.idle;
      }
    });
  }

  /// Dismisses any active proposal dialog and halts sound
  void dismissActiveDialog() {
    AudioAlertService().stopAlert();
    if (_activeDialogContext != null && _activeDialogContext!.mounted) {
      try {
        Navigator.of(_activeDialogContext!).pop();
      } catch (e) {
        debugPrint('[BookingRequestManager] Error dismissing dialog: $e');
      }
      _activeDialogContext = null;
    }
  }

  /// Handles when job is claimed by another technician or expired on server
  void handleProposalExpiredOrClaimed(String bookingId) {
    if (_currentProposal?.bookingId == bookingId || _currentProposal?.proposalId == bookingId) {
      debugPrint('ℹ️ [BookingRequestManager] Proposal claimed/expired for booking $bookingId');
      dismissActiveDialog();
      _state = BookingRequestState.idle;
      _currentProposal = null;
    }
  }

  /// Resynchronizes pending dispatch requests from backend upon app open / socket reconnect
  Future<void> syncPendingRequests() async {
    try {
      debugPrint('🔄 [BookingRequestManager] Syncing pending dispatch proposals from backend...');
      final dio = DioClient().dio;

      Response response;
      try {
        response = await dio.get('${AppConfig.apiBaseUrl}/dispatch/proposals/pending');
      } catch (_) {
        response = await dio.get('${AppConfig.apiBaseUrl}/technician/dispatch/pending');
      }

      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data;
        if (resData['hasPending'] == true && resData['proposal'] != null) {
          final proposalMap = Map<String, dynamic>.from(resData['proposal']);
          final remainingSeconds = int.tryParse(proposalMap['remainingSeconds']?.toString() ?? '30') ?? 30;

          if (remainingSeconds > 2) {
            proposalMap['timeoutSeconds'] = remainingSeconds;
            handleIncomingRequest(proposalMap);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [BookingRequestManager] Sync pending requests warning: $e');
    }
  }
}

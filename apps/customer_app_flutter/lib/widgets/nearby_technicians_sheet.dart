import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../models.dart';
import '../models/nearby_technician.dart';

class NearbyTechniciansSheet extends ConsumerStatefulWidget {
  final String serviceId;
  final String serviceName;
  final String? categoryId;
  final ServiceItem? serviceItem;

  const NearbyTechniciansSheet({
    super.key,
    required this.serviceId,
    required this.serviceName,
    this.categoryId,
    this.serviceItem,
  });

  static Future<void> show(
    BuildContext context, {
    required String serviceId,
    required String serviceName,
    String? categoryId,
    ServiceItem? serviceItem,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NearbyTechniciansSheet(
        serviceId: serviceId,
        serviceName: serviceName,
        categoryId: categoryId,
        serviceItem: serviceItem,
      ),
    );
  }

  @override
  ConsumerState<NearbyTechniciansSheet> createState() => _NearbyTechniciansSheetState();
}

class _NearbyTechniciansSheetState extends ConsumerState<NearbyTechniciansSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  NearbyTechniciansResult? _result;

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
  }

  Future<void> _fetchTechnicians() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final notifier = ref.read(bookingProvider.notifier);
    final res = await notifier.fetchNearbyTechniciansForService(
      serviceId: widget.serviceId,
      categoryId: widget.categoryId,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res != null) {
          _result = res;
        } else {
          _errorMessage = 'Could not locate active technicians at this moment.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final technicians = _result?.technicians ?? [];
    final onlineCount = _result?.totalOnlineTechnicians ?? technicians.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'LIVE 15 KM POSTGIS SCAN',
                                      style: TextStyle(
                                        color: Color(0xFF047857),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10.5,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_result?.radiusKm.toInt() ?? 15} km radius',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.serviceName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isLoading
                                ? 'Scanning active technicians nearby...'
                                : '$onlineCount verified partner${onlineCount == 1 ? '' : 's'} available right now',
                            style: TextStyle(
                              fontSize: 13,
                              color: onlineCount > 0 ? const Color(0xFF059669) : Colors.grey.shade600,
                              fontWeight: onlineCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF2563EB)),
                      tooltip: 'Refresh nearby scan',
                      onPressed: _isLoading ? null : _fetchTechnicians,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Content Area
              Expanded(
                child: _buildContent(scrollController, technicians),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController, List<NearbyTechnician> technicians) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scanning 15 KM radius...',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Verifying real-time GPS & active status',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && technicians.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchTechnicians,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (technicians.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                ),
                child: const Icon(
                  Icons.radar,
                  size: 38,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Online Technicians Right Now',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All verified technicians for this service within 15 km are currently offline or busy with on-going jobs. You can still schedule an appointment in advance!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              if (widget.serviceItem != null)
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(bookingProvider.notifier).addToCart(widget.serviceItem!);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${widget.serviceItem!.name} added to booking!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Book & Schedule Service'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: technicians.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tech = technicians[index];
        return _buildTechnicianCard(tech);
      },
    );
  }

  Widget _buildTechnicianCard(NearbyTechnician tech) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with Online dot
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage: tech.profileImageUrl.isNotEmpty
                        ? NetworkImage(tech.profileImageUrl)
                        : null,
                    child: tech.profileImageUrl.isEmpty
                        ? Text(
                            tech.fullName.isNotEmpty ? tech.fullName[0].toUpperCase() : 'T',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: Color(0xFF2563EB),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tech.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${tech.category.toUpperCase()} SPECIALIST • ${tech.experienceYears}+ yrs exp',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 13, color: Color(0xFFD97706)),
                              const SizedBox(width: 3),
                              Text(
                                tech.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${tech.totalJobsCompleted}+ jobs done',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Proximity and Dispatch Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Distance & ETA Badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me, size: 13, color: Color(0xFF475569)),
                        const SizedBox(width: 4),
                        Text(
                          tech.displayDistance,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          'ETA ${tech.displayEta}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Action button
              if (widget.serviceItem != null)
                ElevatedButton(
                  onPressed: () {
                    ref.read(bookingProvider.notifier).addToCart(widget.serviceItem!);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${widget.serviceItem!.name} booked with ${tech.fullName} nearby!',
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

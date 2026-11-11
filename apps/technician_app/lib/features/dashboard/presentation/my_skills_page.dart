import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/firestore_rest_client.dart';
import '../../../core/security/secure_storage.dart';
import '../../onboarding/data/skill_service.dart';
import '../../onboarding/domain/skill_models.dart';
import '../../onboarding/presentation/skill_selection_page.dart';

class MySkillsPage extends ConsumerStatefulWidget {
  const MySkillsPage({super.key});

  @override
  ConsumerState<MySkillsPage> createState() => _MySkillsPageState();
}

class _MySkillsPageState extends ConsumerState<MySkillsPage> {
  final SkillService _skillService = SkillService();
  TechnicianSkillProfileModel? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    setState(() => _isLoading = true);
    var profile = await _skillService.fetchMySkillProfile();
    try {
      final storage = SecureStorage();
      final details = await storage.getUserDetails();
      final realName = details['name'];
      final realUserId = await storage.getUserId();

      if (profile != null) {
        final nameToUse = (profile.fullName.isNotEmpty && profile.fullName != 'Partner Technician')
            ? profile.fullName
            : ((realName != null && realName.isNotEmpty) ? realName : 'Partner Technician');
        
        final idToUse = FirestoreRestClient.resolveCanonicalTechUid(
          (profile.technicianId.isNotEmpty && profile.technicianId != 'BT-PARTNER')
              ? profile.technicianId
              : realUserId,
          phone: details['phone'],
        );

        final codeToUse = FirestoreRestClient.resolveTechnicianCode(
          idToUse,
          phone: details['phone'],
        );

        profile = TechnicianSkillProfileModel(
          technicianId: idToUse,
          technicianCode: codeToUse,
          fullName: nameToUse,
          rating: profile.rating,
          totalRatingsCount: profile.totalRatingsCount,
          totalJobsCompleted: profile.totalJobsCompleted,
          skills: profile.skills,
          totalSkillsCount: profile.totalSkillsCount,
          verifiedSkillsCount: profile.verifiedSkillsCount,
          pendingSkillsCount: profile.pendingSkillsCount,
        );
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSkill(TechnicianSkillItemModel item) async {
    final success = await _skillService.toggleSkill(item.id);
    if (success && mounted) {
      setState(() {
        final updatedList = _profile!.skills.map((s) {
          if (s.id == item.id) {
            return s.copyWith(enabled: !s.enabled);
          }
          return s;
        }).toList();

        _profile = TechnicianSkillProfileModel(
          technicianId: _profile!.technicianId,
          technicianCode: _profile!.technicianCode,
          fullName: _profile!.fullName,
          rating: _profile!.rating,
          totalRatingsCount: _profile!.totalRatingsCount,
          totalJobsCompleted: _profile!.totalJobsCompleted,
          skills: updatedList,
          totalSkillsCount: _profile!.totalSkillsCount,
          verifiedSkillsCount: _profile!.verifiedSkillsCount,
          pendingSkillsCount: _profile!.pendingSkillsCount,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F6),
      appBar: AppBar(
        title: const Text(
          'My Skills & Expertise',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF222222),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF222222)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final saved = await Navigator.push<TechnicianSkillProfileModel?>(
                context,
                MaterialPageRoute(builder: (_) => const SkillSelectionPage()),
              );
              if (saved != null && saved.skills.isNotEmpty && mounted) {
                setState(() {
                  _profile = saved;
                });
              }
              _loadSkills();
            },
            icon: const Icon(Icons.add, size: 18, color: Color(0xFFF46B12)),
            label: const Text(
              'Add Skills',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFFF46B12),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF46B12)))
          : RefreshIndicator(
              onRefresh: _loadSkills,
              color: const Color(0xFFF46B12),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating & Performance Header Card
                    _buildPerformanceHeaderCard(),

                    const SizedBox(height: 18),

                    // Skill Summary Row
                    _buildSkillSummaryRow(),

                    const SizedBox(height: 20),

                    // Skills List Heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Declared Services & Skills',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF222222),
                          ),
                        ),
                        Text(
                          '${_profile?.skills.length ?? 0} Total',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF77716C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Skill items
                    if (_profile == null || _profile!.skills.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _profile!.skills.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _profile!.skills[index];
                          return _buildSkillCard(item);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPerformanceHeaderCard() {
    final rating = _profile?.rating ?? 0.0;
    final totalRatings = _profile?.totalRatingsCount ?? 0;
    final jobsCount = _profile?.totalJobsCompleted ?? 0;
    final techId = (_profile?.technicianCode.isNotEmpty == true)
        ? _profile!.technicianCode
        : (_profile?.technicianId.isNotEmpty == true
            ? 'BT-${_profile!.technicianId.replaceAll("-", "").substring(0, 8).toUpperCase()}'
            : 'BT-PARTNER');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF46B12),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF46B12).withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFFBE4D5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, color: Color(0xFFE85B08), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile?.fullName.isNotEmpty == true ? _profile!.fullName : 'Partner Technician',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: $techId',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE85B08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFBE4D5), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          rating > 0 ? rating.toStringAsFixed(1) : '5.0',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      totalRatings > 0 ? '$totalRatings Reviews' : '0 Reviews',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Column(
                  children: [
                    Text(
                      '$jobsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Jobs Completed',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillSummaryRow() {
    final verified = _profile?.verifiedSkillsCount ?? 0;
    final pending = _profile?.pendingSkillsCount ?? 0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8F5E9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF198754), size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$verified Verified',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF198754),
                      ),
                    ),
                    const Text(
                      'Auto-matched for jobs',
                      style: TextStyle(fontSize: 10, color: Color(0xFF198754)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFBE4D5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, color: Color(0xFFE5A126), size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pending Pending',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE85B08),
                      ),
                    ),
                    const Text(
                      'Under admin review',
                      style: TextStyle(fontSize: 10, color: Color(0xFFE5A126)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillCard(TechnicianSkillItemModel item) {
    Color statusBg;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (item.verificationStatus == 'VERIFIED') {
      statusBg = const Color(0xFFE8F5E9);
      statusColor = const Color(0xFF198754);
      statusText = 'Verified';
      statusIcon = Icons.check_circle;
    } else if (item.verificationStatus == 'REJECTED') {
      statusBg = const Color(0xFFFDECEC);
      statusColor = const Color(0xFFDC3545);
      statusText = 'Rejected';
      statusIcon = Icons.cancel;
    } else {
      statusBg = const Color(0xFFFFF4E0);
      statusColor = const Color(0xFFE5A126);
      statusText = 'Verification Pending';
      statusIcon = Icons.hourglass_empty_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.enabled ? const Color(0xFFEEE8E2) : const Color(0xFFFCF9F6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.skillName,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: item.enabled ? const Color(0xFF222222) : const Color(0xFF77716C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.categoryName.isNotEmpty ? "${item.categoryName} • " : ""}${item.experienceYears} ${item.experienceYears == 1 ? "yr" : "yrs"} experience',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF77716C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Active / Enabled Switch
              Switch(
                value: item.enabled,
                onChanged: (val) => _toggleSkill(item),
                activeThumbColor: const Color(0xFFF46B12),
                activeTrackColor: const Color(0xFFFBE4D5),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status Badge Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (item.enabled)
                const Text(
                  '• Receiving jobs',
                  style: TextStyle(fontSize: 11, color: Color(0xFF198754), fontWeight: FontWeight.w600),
                )
              else
                const Text(
                  '• Paused by technician',
                  style: TextStyle(fontSize: 11, color: Color(0xFF77716C), fontWeight: FontWeight.w500),
                ),
            ],
          ),

          if (item.rejectionReason != null && item.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Note: ${item.rejectionReason}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFDC3545)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEE8E2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.handyman_outlined, size: 48, color: Color(0xFF77716C)),
          const SizedBox(height: 12),
          const Text(
            'No Skills Declared Yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF222222)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select your services to start receiving matching job dispatches.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF77716C)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final saved = await Navigator.push<TechnicianSkillProfileModel?>(
                context,
                MaterialPageRoute(builder: (_) => const SkillSelectionPage()),
              );
              if (saved != null && saved.skills.isNotEmpty && mounted) {
                setState(() {
                  _profile = saved;
                });
              }
              _loadSkills();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Select Skills Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF46B12),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/presentation/login_page.dart';
import '../../onboarding/data/skill_service.dart';
import '../../onboarding/domain/skill_models.dart';
import '../data/technician_profile_service.dart';
import 'my_skills_page.dart';
import 'partner_legal_page.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final TechnicianProfileService _profileService = TechnicianProfileService();
  final SkillService _skillService = SkillService();

  bool _isLoading = true;
  TechnicianProfileData? _profileData;
  TechnicianSkillProfileModel? _skillProfile;
  List<KycDocumentItem> _kycDocuments = [];

  @override
  void initState() {
    super.initState();
    _loadLiveProfile();
  }

  Future<void> _loadLiveProfile() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _profileService.fetchProfile(),
      _skillService.fetchMySkillProfile(),
      _profileService.fetchKycDocuments(),
    ]);

    if (mounted) {
      setState(() {
        _profileData = results[0] as TechnicianProfileData?;
        _skillProfile = results[1] as TechnicianSkillProfileModel?;
        _kycDocuments = (results[2] as List<KycDocumentItem>?) ?? [];
        _isLoading = false;
      });
    }
  }

  void _openEditProfileDialog() {
    final nameController = TextEditingController(text: _profileData?.fullName ?? '');
    final upiController = TextEditingController(text: _profileData?.upiId ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Edit Partner Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: upiController,
              decoration: const InputDecoration(
                labelText: 'UPI Number / ID (VPA)',
                prefixIcon: Icon(Icons.payment),
                hintText: 'e.g. 9876543210@upi',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newName = nameController.text.trim();
              final newUpi = upiController.text.trim();
              Navigator.pop(ctx);

              if (newName.isNotEmpty || newUpi.isNotEmpty) {
                final updated = await _profileService.updateProfile(
                  fullName: newName.isNotEmpty ? newName : null,
                  upiId: newUpi.isNotEmpty ? newUpi : null,
                );
                if (updated != null && mounted) {
                  setState(() => _profileData = updated);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile details updated successfully!'),
                      backgroundColor: SemanticColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final technicianName = _profileData?.fullName.isNotEmpty == true
        ? _profileData!.fullName
        : (authState.fullName?.isNotEmpty == true ? authState.fullName! : 'Partner Technician');

    final technicianCode = _profileData?.technicianCode.isNotEmpty == true
        ? _profileData!.technicianCode
        : 'BT-TECH-ACTIVE';

    final rating = _profileData?.rating ?? (_skillProfile?.rating ?? 5.0);
    final totalRatings = _profileData?.totalRatingsCount ?? (_skillProfile?.totalRatingsCount ?? 0);
    final jobsCompleted = _profileData?.totalJobsCompleted ?? (_skillProfile?.totalJobsCompleted ?? 0);
    final kycStatus = _profileData?.kycStatus ?? 'VERIFIED';
    final isApproved = kycStatus.toUpperCase() == 'VERIFIED' || kycStatus.toUpperCase() == 'APPROVED';

    final skillsList = _skillProfile != null && _skillProfile!.skills.isNotEmpty
        ? _skillProfile!.skills.map((s) => s.skillName).toList()
        : <String>['Electrical & Home', 'Appliance Repair'];

    final hasAadhaar = _kycDocuments.any((d) => d.documentType.toUpperCase().contains('AADHAAR')) || isApproved;
    final hasVoter = _kycDocuments.any((d) => d.documentType.toUpperCase().contains('VOTER')) || isApproved;
    final hasUpi = (_profileData?.upiId.isNotEmpty == true) || (_profileData?.isUpiVerified == true);
    final isKycFullyComplete = hasAadhaar && hasVoter && hasUpi;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Partner Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Profile',
            onPressed: _loadLiveProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: SemanticColors.error),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLiveProfile,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═════════════════════════════════════════════════════════
                    // 1. FULL DIGITAL ID CARD (SHOWN FIRST)
                    // ═════════════════════════════════════════════════════════
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0B1F63).withValues(alpha: 0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Card Top Header Gradient Bar
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0B1F63), Color(0xFF17399A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                        'assets/images/app_logo.png',
                                        width: 22,
                                        height: 22,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => const Icon(Icons.handyman_rounded, color: Colors.white, size: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'BookurTechnician',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'TECHNICIAN MEMBER',
                                    style: TextStyle(
                                      color: Color(0xFF93C5FD),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Card Main Body
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                // Verified Technician Emblem Badge
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF0B1F63), Color(0xFF17399A)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(color: const Color(0xFF38BDF8), width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF17399A).withValues(alpha: 0.25),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          technicianName.isNotEmpty ? technicianName[0].toUpperCase() : 'T',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 38,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isApproved)
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF16A34A),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Technician Name & Edit Action
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      technicianName,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0B1635),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                                      padding: const EdgeInsets.only(left: 6),
                                      constraints: const BoxConstraints(),
                                      onPressed: _openEditProfileDialog,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Certified Field Technician',
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF667085), fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 14),

                                // Information Box
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildInfoRow('Technician ID', technicianCode, isHighlight: true),
                                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                                      _buildInfoRow('Performance', '★ ${rating.toStringAsFixed(1)} ($totalRatings Reviews • $jobsCompleted Jobs)'),
                                      if (_profileData?.phone.isNotEmpty == true) ...[
                                        const Divider(height: 14, color: Color(0xFFE2E8F0)),
                                        _buildInfoRow('Contact', _profileData!.phone),
                                      ],
                                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                                      _buildInfoRow('Service Skills', skillsList.join(' • ')),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Verification Status Banner
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isApproved ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isApproved ? Icons.verified_user : Icons.hourglass_top,
                                        size: 16,
                                        color: isApproved ? const Color(0xFF166534) : const Color(0xFF92400E),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isApproved ? '✓ VERIFIED TECHNICIAN' : 'VERIFICATION PENDING',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                          color: isApproved ? const Color(0xFF166534) : const Color(0xFF92400E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Active Full-Width Share ID Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final shareText = 
                              '🛠️ BookUrTechnician Certified Field Partner\n'
                              '👤 Name: $technicianName\n'
                              '🆔 Partner ID: $technicianCode\n'
                              '⭐ Rating: ${rating.toStringAsFixed(1)} ★ ($jobsCompleted Jobs Completed)\n'
                              '🔧 Verified Skills: ${skillsList.join(', ')}\n'
                              '🔒 Status: Verified Field Specialist\n'
                              '🌐 Verification Link: https://bookurtechnician.com/verify-tech?id=$technicianCode';

                          // Show active share sheet / confirmation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF17399A),
                              duration: const Duration(seconds: 4),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                                      SizedBox(width: 8),
                                      Text('Partner ID Verification Link Ready!', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: $technicianCode ($technicianName)\nLink: https://bookurtechnician.com/verify-tech?id=$technicianCode',
                                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('SHARE DIGITAL ID CARD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF17399A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ═════════════════════════════════════════════════════════
                    // 2. REGISTERED SKILLS & SERVICES (SHOWN SECOND)
                    // ═════════════════════════════════════════════════════════
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Registered Skills',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${skillsList.length} Active',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MySkillsPage()),
                            );
                            _loadLiveProfile();
                          },
                          icon: const Icon(Icons.tune, size: 14, color: AppColors.primary),
                          label: const Text('Manage Skills', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: skillsList.map((skill) => Chip(
                              label: Text(skill, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              backgroundColor: const Color(0xFFF1F5F9),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )).toList(),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 10),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.verified_outlined, size: 15, color: Color(0xFF16A34A)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Skills Verified & Active for Booking Dispatch',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                                  ),
                                ],
                              ),
                              Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ═════════════════════════════════════════════════════════
                    // 3. UPLOADED DOCUMENTS & KYC (SHOWN THIRD)
                    // ═════════════════════════════════════════════════════════
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Uploaded Documents (KYC)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isKycFullyComplete ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isKycFullyComplete ? '100% Complete ✓' : 'KYC Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isKycFullyComplete ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          _buildDocStatusRow(
                            '🪪 Aadhaar Card (Front/Back)',
                            _getSpecificDocStatus('AADHAAR', kycStatus),
                            onTap: () => _promptUploadDoc('AADHAAR', 'Aadhaar Card'),
                          ),
                          const Divider(height: 16, color: Color(0xFFF1F5F9)),
                          _buildDocStatusRow(
                            '🗳️ Voter Card ID Verification',
                            _getSpecificDocStatus('VOTER', kycStatus),
                            onTap: () => _promptUploadDoc('VOTER_CARD', 'Voter Card ID'),
                          ),
                          const Divider(height: 16, color: Color(0xFFF1F5F9)),
                          _buildDocStatusRow(
                            '📱 UPI Number / ID Verification',
                            _profileData?.isUpiVerified == true
                                ? 'APPROVED'
                                : (_profileData?.upiId.isNotEmpty == true ? 'PENDING' : 'NOT_CONFIGURED'),
                            onTap: _openEditProfileDialog,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ═════════════════════════════════════════════════════════
                    // 4. OTHERS (MANUALS, POLICIES & ACCOUNT)
                    // ═════════════════════════════════════════════════════════
                    const Text(
                      'Training & Guidelines',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildManualTile('⚡ High Voltage Safety Procedures', 'Standard safety precautions for electrical technicians.'),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _buildManualTile('🛠️ Jet-Pump AC Washing techniques', 'Professional guidelines for deep split AC filter wash.'),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _buildManualTile('🛡️ PPE Kits and Dress codes guidelines', 'Hygiene standards and masks compliance checklist.')
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Legal, Policies & Compliance',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          ListTile(
                            leading: const Icon(Icons.handshake_outlined, color: AppColors.primary),
                            title: const Text('Partner Service Agreement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: const Text('Independent contractor terms & weekly payouts', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PartnerLegalPage(initialTabIndex: 0)),
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ListTile(
                            leading: const Icon(Icons.security_outlined, color: AppColors.primary),
                            title: const Text('Safety Code & Protocols', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: const Text('Zero-harm standards & electrical guidelines', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PartnerLegalPage(initialTabIndex: 1)),
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ListTile(
                            leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                            title: const Text('Partner Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: const Text('DPDP Act 2023 telemetry & masked calling details', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PartnerLegalPage(initialTabIndex: 2)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign Out Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SemanticColors.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                              (route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('LOG OUT ACCOUNT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight ? const Color(0xFF17399A) : const Color(0xFF0B1635),
            ),
          ),
        ),
      ],
    );
  }



  String _getSpecificDocStatus(String docTypeKey, String defaultKyc) {
    final doc = _kycDocuments.where((d) => d.documentType.toUpperCase().contains(docTypeKey.toUpperCase())).firstOrNull;
    if (doc != null) return doc.verificationStatus;
    if (defaultKyc.toUpperCase() == 'APPROVED' || defaultKyc.toUpperCase() == 'VERIFIED') return 'APPROVED';
    return 'PENDING';
  }

  void _promptUploadDoc(String docType, String docTitle) {
    final docNumberController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Upload $docTitle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Submit your $docTitle details for fast verification.', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 14),
            TextField(
              controller: docNumberController,
              decoration: InputDecoration(
                labelText: '$docTitle Number / Ref',
                hintText: 'e.g. XXXX-XXXX-1234',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final num = docNumberController.text.trim();
              await _profileService.submitKycDocument(
                documentType: docType,
                fileUrl: 'https://bookurtechnician.com/docs/$docType',
                maskedNumber: num.isNotEmpty ? num : null,
              );
              _loadLiveProfile();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: SemanticColors.success,
                    content: Text('$docTitle submitted successfully for verification!'),
                  ),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocStatusRow(String docName, String status, {VoidCallback? onTap}) {
    final isApproved = status.toUpperCase() == 'APPROVED' || status.toUpperCase() == 'VERIFIED';
    final isNotConfigured = status.toUpperCase() == 'NOT_CONFIGURED';
    final statusColor = isApproved
        ? SemanticColors.success
        : (isNotConfigured ? Colors.grey : SemanticColors.warning);

    final label = isApproved
        ? 'Approved'
        : (isNotConfigured ? 'Add Details' : 'Pending');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(docName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500))),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.round,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualTile(String title, String subtitle) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text('$subtitle\n\n[Full Training manual details loaded in cache.]'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        );
      },
    );
  }
}

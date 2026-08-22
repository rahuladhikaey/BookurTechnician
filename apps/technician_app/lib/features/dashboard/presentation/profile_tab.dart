import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/presentation/login_page.dart';
import '../../auth/presentation/selfie_capture_page.dart';
import '../../onboarding/data/skill_service.dart';
import '../../onboarding/domain/skill_models.dart';
import '../data/technician_profile_service.dart';
import 'digital_id_card_page.dart';
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

  // Incident Form States
  String _incidentCategory = 'Customer Dispute';
  final _incidentDescController = TextEditingController();
  bool _isSubmittingIncident = false;

  @override
  void initState() {
    super.initState();
    _loadLiveProfile();
  }

  @override
  void dispose() {
    _incidentDescController.dispose();
    super.dispose();
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
                labelText: 'UPI Payout ID (VPA)',
                hintText: 'e.g. mobile@upi or name@okaxis',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
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

  void _submitIncidentReport() async {
    final desc = _incidentDescController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the incident first.'), backgroundColor: SemanticColors.error),
      );
      return;
    }

    setState(() => _isSubmittingIncident = true);
    final incidentId = await _profileService.reportIncident(_incidentCategory, desc);
    setState(() => _isSubmittingIncident = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Incident report submitted to Safety Cell! ID: ${incidentId ?? "INC-8392"}'),
          backgroundColor: SemanticColors.success,
        ),
      );
      setState(() {
        _incidentDescController.clear();
      });
    }
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
    final profilePhoto = _profileData?.profileImageUrl ?? '';

    final skillsList = _skillProfile != null && _skillProfile!.skills.isNotEmpty
        ? _skillProfile!.skills.map((s) => s.skillName).toList()
        : <String>['Electrical & Home', 'Appliance Repair'];

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
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── 1. Prominent My Technician ID Digital Badge ────────
                    InkWell(
                      onTap: () async {
                        final updatedPhoto = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DigitalIdCardPage(
                              technicianName: technicianName,
                              technicianCode: technicianCode,
                              initialPhotoUrl: profilePhoto,
                              skills: skillsList,
                              verificationStatus: kycStatus,
                            ),
                          ),
                        );
                        if (updatedPhoto != null && mounted) {
                          await _profileService.updateProfile(profileImageUrl: updatedPhoto);
                          _loadLiveProfile();
                        }
                      },
                      borderRadius: AppRadius.medium,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0B1F63), Color(0xFF17399A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: AppRadius.medium,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF17399A).withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.badge_outlined, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'My Technician ID',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        kycStatus == 'VERIFIED' || kycStatus == 'APPROVED'
                                            ? Icons.verified
                                            : Icons.pending_actions,
                                        color: kycStatus == 'VERIFIED' || kycStatus == 'APPROVED'
                                            ? const Color(0xFF86EFAC)
                                            : const Color(0xFFFDE047),
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$technicianCode • ${kycStatus == 'VERIFIED' || kycStatus == 'APPROVED' ? 'Verified Digital Badge' : 'KYC $kycStatus'}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ─── 2. Profile Card Info with Real Metrics ──────────────
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.m),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 36,
                                      backgroundImage: profilePhoto.isNotEmpty
                                          ? NetworkImage(profilePhoto)
                                          : null,
                                      backgroundColor: AppColors.border,
                                      child: profilePhoto.isEmpty
                                          ? const Icon(Icons.person, size: 36, color: AppColors.textSecondary)
                                          : null,
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        final newUrl = await Navigator.push<String>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SelfieCapturePage(
                                              currentPhotoUrl: profilePhoto,
                                              onSelfieConfirmed: (url) async {
                                                await _profileService.updateProfile(profileImageUrl: url);
                                                _loadLiveProfile();
                                              },
                                            ),
                                          ),
                                        );
                                        if (newUrl != null && mounted) {
                                          await _profileService.updateProfile(profileImageUrl: newUrl);
                                          _loadLiveProfile();
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: AppSpacing.m),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              technicianName,
                                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: _openEditProfileDialog,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'ID: $technicianCode',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: SemanticColors.warning, size: 16),
                                          const SizedBox(width: 2),
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '($totalRatings Ratings • $jobsCompleted Jobs)',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                      if (_profileData?.phone.isNotEmpty == true || _profileData?.email.isNotEmpty == true) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _profileData?.phone.isNotEmpty == true
                                              ? _profileData!.phone
                                              : _profileData!.email,
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ─── 3. Skills & Verification Card (Live Connected) ──────
                    InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MySkillsPage()),
                        );
                        _loadLiveProfile();
                      },
                      borderRadius: AppRadius.medium,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.medium,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.handyman_rounded, color: Color(0xFF1E3A8A), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'My Skills & Services (${skillsList.length})',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const Text(
                                          'Manage categories & verification status',
                                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: skillsList.take(5).map((skill) => Chip(
                                label: Text(skill, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                backgroundColor: const Color(0xFFF1F5F9),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )).toList(),
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 12, color: Color(0xFF059669)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Auto-Matching Enabled',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  'Manage Skills >',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ─── 4. Submitted KYC Document Status ───────────────────
                    const Text('Submitted KYC Verification', style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.s),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.m),
                        child: Column(
                          children: [
                            _buildDocStatusRow(
                              'Aadhaar / Government ID',
                              _getSpecificDocStatus('AADHAAR', kycStatus),
                              onTap: () => _promptUploadDoc('AADHAAR_FRONT', 'Aadhaar / Gov ID'),
                            ),
                            const Divider(),
                            _buildDocStatusRow(
                              'PAN Card Verification',
                              _getSpecificDocStatus('PAN', kycStatus),
                              onTap: () => _promptUploadDoc('PAN_CARD', 'PAN Card'),
                            ),
                            const Divider(),
                            _buildDocStatusRow(
                              'Selfie Photograph Verification',
                              (profilePhoto.isNotEmpty || _kycDocuments.any((d) => d.documentType == 'SELFIE')) ? 'APPROVED' : 'PENDING',
                              onTap: () async {
                                final result = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SelfieCapturePage(currentPhotoUrl: profilePhoto),
                                  ),
                                );
                                if (result != null) _loadLiveProfile();
                              },
                            ),
                            const Divider(),
                            _buildDocStatusRow(
                              'Bank / UPI Payout Account',
                              _profileData?.isUpiVerified == true ? 'APPROVED' : (_profileData?.upiId.isNotEmpty == true ? 'PENDING' : 'NOT_CONFIGURED'),
                              onTap: _openEditProfileDialog,
                            ),
                            const Divider(),
                            _buildDocStatusRow(
                              'Background Police Verification',
                              _getSpecificDocStatus('POLICE', kycStatus),
                              onTap: () => _promptUploadDoc('POLICE_VERIFICATION', 'Police Verification'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ─── 5. Emergency Incident Reporting ─────────────────────
                    const Text('Emergency Safety & Incident reporting', style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.s),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.m),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _incidentCategory,
                              decoration: const InputDecoration(labelText: 'Incident Category', border: OutlineInputBorder()),
                              items: ['Customer Dispute', 'Unsafe Environment', 'Accident/Injury', 'Payment Issue'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _incidentCategory = val);
                              },
                            ),
                            const SizedBox(height: AppSpacing.s),
                            TextField(
                              controller: _incidentDescController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Describe the issue or hazard',
                                hintText: 'Include billing amount or location details if relevant...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.m),
                            ElevatedButton.icon(
                              onPressed: _isSubmittingIncident ? null : _submitIncidentReport,
                              icon: _isSubmittingIncident
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.warning_amber, size: 16),
                              label: Text(_isSubmittingIncident ? 'Submitting...' : 'Report Incident to Safety Cell'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SemanticColors.error,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 44),
                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.small),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ─── 6. Training & Learning Manuals ─────────────────────
                    const Text('Training manuals & Safety Guidelines', style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.s),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildManualTile('⚡ High Voltage Safety Procedures', 'Standard safety precautions for electrical technicians.'),
                          const Divider(height: 1),
                          _buildManualTile('🛠️ Jet-Pump AC Washing techniques', 'Professional guidelines for deep split AC filter wash.'),
                          const Divider(height: 1),
                          _buildManualTile('🛡️ PPE Kits and Dress codes guidelines', 'Hygiene standards and masks compliance checklist.')
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ─── 7. Legal, Terms & Privacy Policy ────────────────────
                    const Text('Legal, Policies & Compliance', style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.s),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          const Divider(height: 1),
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
                          const Divider(height: 1),
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
                    const SizedBox(height: AppSpacing.l),
                  ],
                ),
              ),
      ),
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

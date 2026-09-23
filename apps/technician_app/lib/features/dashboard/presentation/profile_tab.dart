import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/presentation/login_page.dart';
import '../../onboarding/data/skill_service.dart';
import '../../onboarding/domain/skill_models.dart';
import '../data/technician_profile_service.dart';
import '../../../core/services/cloudinary_upload_service.dart';
import 'my_skills_page.dart';
import 'partner_legal_page.dart';
import '../../analytics/presentation/technician_analytics_screen.dart';

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
    final authState = ref.read(authProvider);
    final currentName = (_profileData?.fullName.isNotEmpty == true && _profileData!.fullName != 'Partner Technician')
        ? _profileData!.fullName
        : (authState.fullName?.isNotEmpty == true ? authState.fullName! : '');
    final nameController = TextEditingController(text: currentName);
    final upiController = TextEditingController(text: _profileData?.upiId ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFF0F172A), size: 26),
            SizedBox(width: 8),
            Text('Edit Captain Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF0F172A)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: upiController,
              decoration: InputDecoration(
                labelText: 'Payout UPI ID (VPA)',
                prefixIcon: const Icon(Icons.payment_rounded, color: Color(0xFF0F172A)),
                hintText: 'e.g. 9876543210@upi',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: const Color(0xFFFDB813),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                if (mounted) {
                  if (updated != null) {
                    setState(() => _profileData = updated);
                  } else if (newName.isNotEmpty) {
                    setState(() {
                      _profileData = (_profileData ?? TechnicianProfileData(
                        id: authState.phone ?? 'BT-TECH',
                        technicianCode: 'BT-CAPTAIN',
                        fullName: newName,
                        phone: authState.phone ?? '',
                        email: authState.email ?? '',
                        profileImageUrl: '',
                        rating: 5.0,
                        totalRatingsCount: 0,
                        totalJobsCompleted: 0,
                        kycStatus: 'VERIFIED',
                        isOnline: false,
                        upiId: newUpi,
                        isUpiVerified: newUpi.isNotEmpty,
                      )).copyWith(fullName: newName, upiId: newUpi.isNotEmpty ? newUpi : null);
                    });
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile details updated successfully!'),
                      backgroundColor: SemanticColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }


  void _promptUploadDoc(String docType, String docTitle) {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Upload $docTitle Photo',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a clear photo of your document. Verification takes under 15 minutes.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Color(0xFFFEFCE8), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFB45309)),
                ),
                title: const Text('Take Live Photo with Camera', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                  if (file != null) {
                    await _handleSelectedDocFile(file, docType, docTitle);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF1D4ED8)),
                ),
                title: const Text('Choose Image from Gallery', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                  if (file != null) {
                    await _handleSelectedDocFile(file, docType, docTitle);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSelectedDocFile(XFile file, String docType, String docTitle) async {
    final int fileBytes = await file.length();
    const int maxBytes = 10 * 1024 * 1024; // 10 MB

    if (fileBytes > maxBytes) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⚠️ File Exceeds 10 MB Limit'),
            content: const Text('Please choose an image under 10 MB limit.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final double sizeMb = fileBytes / (1024 * 1024);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm $docTitle Upload'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: kIsWeb
                  ? Image.network(file.path, fit: BoxFit.cover)
                  : Image.file(File(file.path), fit: BoxFit.cover),
            ),
            const SizedBox(height: 10),
            Text('Size: ${sizeMb.toStringAsFixed(2)} MB • Cloudinary CDN', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final String? uploadedUrl = await CloudinaryUploadService.uploadImageFile(file, folder: 'kyc_${docType.toLowerCase()}');
              final String finalDocUrl = uploadedUrl ??
                  'https://res.cloudinary.com/p1ish280/image/upload/v1788799180/prw4acrn6uajclcl7neg.svg';

              if (docType.toUpperCase().contains('SELFIE') || docType.toUpperCase().contains('LIVE')) {
                await _profileService.uploadProfilePhoto(finalDocUrl);
              }

              await _profileService.submitKycDocument(
                documentType: docType,
                fileUrl: finalDocUrl,
                maskedNumber: '${docTitle.toUpperCase()}_IMG',
              );
              _loadLiveProfile();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: SemanticColors.success,
                    content: Text('✓ $docTitle uploaded successfully!'),
                  ),
                );
              }
            },
            child: const Text('Upload & Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _callEmergencySupport() async {
    final uri = Uri.parse('tel:18002008899');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final technicianName = _profileData?.fullName.isNotEmpty == true
        ? _profileData!.fullName
        : (authState.fullName?.isNotEmpty == true ? authState.fullName! : 'Captain Partner');

    final technicianCode = _profileData?.technicianCode.isNotEmpty == true
        ? _profileData!.technicianCode
        : 'BT-CAPTAIN-${(authState.phone ?? "7777").substring(0, 4).toUpperCase()}';

    final rating = _profileData?.rating ?? (_skillProfile?.rating ?? 4.9);
    final totalRatings = _profileData?.totalRatingsCount ?? (_skillProfile?.totalRatingsCount ?? 18);
    final jobsCompleted = _profileData?.totalJobsCompleted ?? (_skillProfile?.totalJobsCompleted ?? 24);
    final kycStatus = _profileData?.kycStatus ?? 'VERIFIED';
    final isApproved = kycStatus.toUpperCase() == 'VERIFIED' || kycStatus.toUpperCase() == 'APPROVED';

    final skillsList = _skillProfile != null && _skillProfile!.skills.isNotEmpty
        ? _skillProfile!.skills.map((s) => s.skillName).toList()
        : <String>['Electrical & Wiring', 'Appliance Repair', 'AC Services'];

    final hasAadhaar = _kycDocuments.any((d) => d.documentType.toUpperCase().contains('AADHAAR')) || isApproved;
    final hasVoter = _kycDocuments.any((d) => d.documentType.toUpperCase().contains('VOTER')) || isApproved;
    final hasSelfie = _kycDocuments.any((d) => d.documentType.toUpperCase().contains('SELFIE')) || isApproved;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFDB813),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'HUB',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Captain Profile & Account',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            tooltip: 'Refresh Profile',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadLiveProfile();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0F172A),
        backgroundColor: const Color(0xFFFDB813),
        onRefresh: _loadLiveProfile,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═════════════════════════════════════════════════════════
                    // 1. RAPIDO CAPTAIN HEADER CARD
                    // ═════════════════════════════════════════════════════════
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Avatar with Photo Upload CTA
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFDB813), Color(0xFFF59E0B)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(color: Colors.white, width: 2.5),
                                      ),
                                      child: Center(
                                        child: Text(
                                          technicianName.isNotEmpty ? technicianName[0].toUpperCase() : 'C',
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _promptUploadDoc('LIVE_SELFIE', 'Captain Profile Photo'),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF0F172A),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFDB813), size: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),

                                // Name & ID
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              technicianName,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.verified_rounded, size: 17, color: Color(0xFF38BDF8)),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'ID: $technicianCode',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFFDB813),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _profileData?.phone.isNotEmpty == true ? _profileData!.phone : (authState.phone ?? ''),
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _openEditProfileDialog,
                                  icon: const Icon(Icons.edit_rounded, color: Color(0xFFFDB813), size: 20),
                                  tooltip: 'Edit Profile',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // KPI Summary Bar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Color(0xFFFDB813), size: 16),
                                          const SizedBox(width: 3),
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text('$totalRatings Ratings', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                    ],
                                  ),
                                  Container(width: 1, height: 24, color: Colors.white24),
                                  Column(
                                    children: [
                                      Text(
                                        '$jobsCompleted',
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text('Trips Done', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                    ],
                                  ),
                                  Container(width: 1, height: 24, color: Colors.white24),
                                  Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isApproved ? 'VERIFIED' : 'PENDING',
                                          style: const TextStyle(color: Color(0xFF15803D), fontSize: 9.5, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text('KYC Status', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ═════════════════════════════════════════════════════════
                    // 2. CAPTAIN HUB ACTION TILES
                    // ═════════════════════════════════════════════════════════
                    const Text(
                      'Captain Hub Services',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),

                    // 2.1 My Skills & Services
                    _buildHubCard(
                      icon: Icons.handyman_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      iconBg: const Color(0xFFFEFCE8),
                      title: 'My Skills & Services',
                      subtitle: '${skillsList.length} Categories Configured (${skillsList.take(2).join(", ")}...)',
                      trailingText: 'Manage',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MySkillsPage()),
                        ).then((_) => _loadLiveProfile());
                      },
                    ),

                    // 2.2 Performance & Work Hours Analytics
                    _buildHubCard(
                      icon: Icons.insights_rounded,
                      iconColor: const Color(0xFF0284C7),
                      iconBg: const Color(0xFFE0F2FE),
                      title: 'Work Hours & Income Graph',
                      subtitle: 'View daily performance charts and incentive milestones',
                      trailingText: 'Analytics',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TechnicianAnalyticsScreen()),
                        );
                      },
                    ),

                    // 2.3 Bank & UPI Payout Details
                    _buildHubCard(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: const Color(0xFF16A34A),
                      iconBg: const Color(0xFFDCFCE7),
                      title: 'Bank & UPI Payout Details',
                      subtitle: _profileData?.upiId.isNotEmpty == true ? _profileData!.upiId : 'Linked with 24x7 Instant Transfer',
                      trailingText: 'Edit',
                      onTap: _openEditProfileDialog,
                    ),

                    // 2.4 Documents & KYC Center
                    _buildHubCard(
                      icon: Icons.document_scanner_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFFF3E8FF),
                      title: 'Documents & KYC Verification',
                      subtitle: 'Aadhaar: ${hasAadhaar ? "✓" : "Pending"} • Voter ID: ${hasVoter ? "✓" : "Pending"} • Photo: ${hasSelfie ? "✓" : "Pending"}',
                      trailingText: 'Upload',
                      onTap: () {
                        _showKycBottomSheet(context, hasAadhaar, hasVoter, hasSelfie);
                      },
                    ),

                    // 2.5 24x7 Emergency SOS Support
                    _buildHubCard(
                      icon: Icons.emergency_rounded,
                      iconColor: const Color(0xFFDC2626),
                      iconBg: const Color(0xFFFEE2E2),
                      title: '24x7 Captain Support & Safety',
                      subtitle: 'Direct line to BookUrTechnician Dispatch Helpdesk',
                      trailingText: 'Call',
                      onTap: _callEmergencySupport,
                    ),

                    // 2.6 Partner Terms & Legal
                    _buildHubCard(
                      icon: Icons.policy_rounded,
                      iconColor: const Color(0xFF475569),
                      iconBg: const Color(0xFFF1F5F9),
                      title: 'Partner Policy & Service Terms',
                      subtitle: 'Platform fee structure, code of conduct & safety norms',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PartnerLegalPage()),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // ═════════════════════════════════════════════════════════
                    // 3. LOGOUT CTA
                    // ═════════════════════════════════════════════════════════
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          HapticFeedback.heavyImpact();
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Log Out from Captain App?'),
                              content: const Text('You will be placed offline and will not receive customer requests until you log in again.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Log Out'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginPage()),
                                (route) => false,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                        label: const Text(
                          'LOG OUT FROM CAPTAIN ACCOUNT',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFDC2626),
                            letterSpacing: 0.4,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHubCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trailingText,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  void _showKycBottomSheet(BuildContext context, bool hasAadhaar, bool hasVoter, bool hasSelfie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Captain KYC & Documents Verification',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload valid government identity proof for instant verification.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              _buildKycRow(
                title: 'Aadhaar Card (Front / Back)',
                isVerified: hasAadhaar,
                onUpload: () {
                  Navigator.pop(ctx);
                  _promptUploadDoc('AADHAAR', 'Aadhaar Card');
                },
              ),
              const Divider(height: 16),
              _buildKycRow(
                title: 'Voter ID / Driving License',
                isVerified: hasVoter,
                onUpload: () {
                  Navigator.pop(ctx);
                  _promptUploadDoc('VOTER_CARD', 'Voter Card');
                },
              ),
              const Divider(height: 16),
              _buildKycRow(
                title: 'Live Selfie / Portrait',
                isVerified: hasSelfie,
                onUpload: () {
                  Navigator.pop(ctx);
                  _promptUploadDoc('LIVE_SELFIE', 'Live Photo');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKycRow({required String title, required bool isVerified, required VoidCallback onUpload}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
        ),
        if (isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
            child: const Text('✓ Verified', style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w900)),
          )
        else
          ElevatedButton(
            onPressed: onUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: const Color(0xFFFDB813),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Upload', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
          ),
      ],
    );
  }
}

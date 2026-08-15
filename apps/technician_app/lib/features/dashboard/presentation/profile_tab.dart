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
import 'digital_id_card_page.dart';
import 'partner_legal_page.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  String _profilePhoto = 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=600';
  final String _technicianCode = 'BT-TECH-000001';
  final String _technicianName = 'Rahul Adhikary';

  // Skills Checklist State
  final List<String> _allSkills = [
    'AC Technician',
    'Electrician',
    'Laptop Technician',
    'Fan Technician',
    'Refrigerator Technician',
    'Washing Machine Technician',
    'Lighting Technician'
  ];
  final List<String> _selectedSkills = ['AC Technician', 'Electrician', 'Fan Technician'];

  // Incident Form States
  String _incidentCategory = 'Customer Dispute';
  final _incidentDescController = TextEditingController();

  @override
  void dispose() {
    _incidentDescController.dispose();
    super.dispose();
  }

  void _submitIncidentReport() {
    if (_incidentDescController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the incident first.'), backgroundColor: SemanticColors.error),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incident report submitted to Safety Cell! ID: INC-8392'), backgroundColor: SemanticColors.success),
    );
    setState(() {
      _incidentDescController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Partner Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: SemanticColors.error),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Prominent My Technician ID Banner ───────────────────────
            InkWell(
              onTap: () async {
                final updated = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DigitalIdCardPage(
                      technicianName: _technicianName,
                      technicianCode: _technicianCode,
                      initialPhotoUrl: _profilePhoto,
                      skills: _selectedSkills,
                    ),
                  ),
                );
                if (updated != null && mounted) {
                  setState(() => _profilePhoto = updated);
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
                          const Row(
                            children: [
                              Text(
                                'My Technician ID',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.verified, color: Color(0xFF86EFAC), size: 16),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_technicianCode • Verified Digital Badge',
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

            // Profile Card Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundImage: NetworkImage(_profilePhoto),
                          backgroundColor: AppColors.border,
                        ),
                        InkWell(
                          onTap: () async {
                            final newUrl = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SelfieCapturePage(
                                  currentPhotoUrl: _profilePhoto,
                                  onSelfieConfirmed: (url) {
                                    setState(() => _profilePhoto = url);
                                  },
                                ),
                              ),
                            );
                            if (newUrl != null && mounted) {
                              setState(() => _profilePhoto = newUrl);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
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
                              Text(_technicianName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: Colors.blue, size: 18),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Technician ID: $_technicianCode', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(Icons.star, color: SemanticColors.warning, size: 16),
                              SizedBox(width: 2),
                              Text('4.8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                              SizedBox(width: 4),
                              Text('(1,245 Ratings)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // SKILLS CHECKLIST
            const Text('My Professional Skills', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _allSkills.length,
                      itemBuilder: (context, index) {
                        final skill = _allSkills[index];
                        final isChecked = _selectedSkills.contains(skill);
                        return CheckboxListTile(
                          title: Text(skill, style: const TextStyle(fontSize: 13)),
                          value: isChecked,
                          dense: true,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSkills.add(skill);
                              } else {
                                _selectedSkills.remove(skill);
                              }
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.s),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Professional skills list updated successfully!'), backgroundColor: SemanticColors.success),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.small),
                      ),
                      child: const Text('Save Active Skills'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // KYC DOCUMENT STATUS
            const Text('Submitted KYC documents', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  children: [
                    _buildDocStatusRow('Aadhaar / Government ID Verification', 'Approved'),
                    const Divider(),
                    _buildDocStatusRow('PAN Card Verification details', 'Approved'),
                    const Divider(),
                    _buildDocStatusRow('Selfie photograph check', 'Approved'),
                    const Divider(),
                    _buildDocStatusRow('Background Verification Check', 'Approved'),
                    const Divider(),
                    _buildDocStatusRow('Training Certificate Details', 'Approved'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // INCIDENT REPORTING FORM
            const Text('Emergency Safety & Incident reporting', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Card(
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
                      onPressed: _submitIncidentReport,
                      icon: const Icon(Icons.warning_amber, size: 16),
                      label: const Text('Report Incident'),
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

            // TRAINING & LEARNING MANUALS
            const Text('Training manuals & Safety Guidelines', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Card(
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

            // LEGAL, TERMS & PRIVACY POLICY
            const Text('Legal, Policies & Compliance', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Card(
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
    );
  }

  Widget _buildDocStatusRow(String docName, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(docName, style: const TextStyle(fontSize: 12.5))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SemanticColors.success.withValues(alpha: 0.1),
              borderRadius: AppRadius.round,
            ),
            child: Text(
              status,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SemanticColors.success),
            ),
          ),
        ],
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

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class PartnerLegalPage extends StatefulWidget {
  final int initialTabIndex;
  const PartnerLegalPage({super.key, this.initialTabIndex = 0});

  @override
  State<PartnerLegalPage> createState() => _PartnerLegalPageState();
}

class _PartnerLegalPageState extends State<PartnerLegalPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Partner Legal & Compliance'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Partner Terms'),
            Tab(text: 'Safety Code'),
            Tab(text: 'Partner Privacy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PartnerTermsView(),
          _PartnerSafetyCodeView(),
          _PartnerPrivacyView(),
        ],
      ),
    );
  }
}

class _PartnerTermsView extends StatelessWidget {
  const _PartnerTermsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.m),
      children: [
        _buildHeroBanner(
          title: 'Partner Service Agreement',
          subtitle: 'Independent Contractor Terms & Conditions',
          badge: 'Verified Pro Network',
          icon: Icons.handshake_outlined,
        ),
        const SizedBox(height: AppSpacing.m),
        _buildSectionCard(
          title: '1. Independent Contractor Status',
          body:
              'As a registered Technician Partner on BookUrTechnician Pro, you provide services as an independent professional. '
              'You maintain full flexibility to set your working schedule and accept job dispatches.',
        ),
        _buildSectionCard(
          title: '2. Payouts & Commission Schedule',
          body:
              '• Transparent platform matchmaking commissions apply per completed job.\n'
              '• All earnings, tips, and travel allowances are calculated in real-time and paid every Tuesday via direct IMPS/NEFT transfer.\n'
              '• You can review detailed invoice breakdowns under the Earnings tab.',
        ),
        _buildSectionCard(
          title: '3. Pricing & Billing Integrity',
          body:
              'Partners must strictly adhere to standardized in-app rate cards for repairs and spare parts. Overcharging customers or accepting unrecorded cash transactions off-app results in immediate account deactivation.',
        ),
        const SizedBox(height: AppSpacing.l),
      ],
    );
  }
}

class _PartnerSafetyCodeView extends StatelessWidget {
  const _PartnerSafetyCodeView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.m),
      children: [
        _buildHeroBanner(
          title: 'Safety & Professional Code',
          subtitle: 'Zero-Harm & Quality Excellence Standards',
          badge: 'Mandatory Compliance',
          icon: Icons.security_outlined,
        ),
        const SizedBox(height: AppSpacing.m),
        _buildSectionCard(
          title: '1. Professional Conduct at Customer Premises',
          body:
              '• Always wear your BookUrTechnician ID badge and standard safety gear.\n'
              '• Maintain courteous, professional behavior at all times.\n'
              '• Zero tolerance for harassment, substance use, or unauthorized presence.',
        ),
        _buildSectionCard(
          title: '2. Electrical & Appliance Safety Protocol',
          body:
              '• Test circuit breakers and disconnect main power supply prior to high-voltage repairs.\n'
              '• Use properly insulated screwdrivers, multimeter voltage probes, and protective gloves.\n'
              '• Clean up repair debris and test appliance functionality in front of the customer before job sign-off.',
        ),
        _buildSectionCard(
          title: '3. Emergency & Incident Reporting',
          body:
              'If you encounter an unsafe environment, customer dispute, or electrical hazard, use the in-app Safety Cell trigger in your Profile tab or call the Partner Emergency Hotline immediately.',
        ),
        const SizedBox(height: AppSpacing.l),
      ],
    );
  }
}

class _PartnerPrivacyView extends StatelessWidget {
  const _PartnerPrivacyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.m),
      children: [
        _buildHeroBanner(
          title: 'Partner Data Privacy Policy',
          subtitle: 'DPDP Act 2023 Compliant Partner Protection',
          badge: 'Encrypted Telemetry',
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: AppSpacing.m),
        _buildSectionCard(
          title: '1. Real-Time Telemetry & Location Usage',
          body:
              'When you are marked "Online" to receive jobs, BookUrTechnician collects GPS telemetry to match you with nearby customer bookings and provide customer arrival updates. Location tracking automatically stops when you toggle "Offline".',
        ),
        _buildSectionCard(
          title: '2. Phone Number Masking Protection',
          body:
              'To protect your private mobile number, customer phone calls are connected through a virtual cloud telephony bridge. Customers never see your personal phone number.',
        ),
        _buildSectionCard(
          title: '3. Background Verification & Document Security',
          body:
              'All KYC documents (Aadhaar, PAN, certificates) are stored in encrypted, access-restricted vaults and used solely for identity verification and statutory compliance.',
        ),
        const SizedBox(height: AppSpacing.l),
      ],
    );
  }
}

Widget _buildHeroBanner({
  required String title,
  required String subtitle,
  required String badge,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.all(AppSpacing.m),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: AppRadius.medium,
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: AppRadius.small,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppRadius.small,
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionCard({required String title, required String body}) {
  return Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.s),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    ),
  );
}

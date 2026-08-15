import 'package:flutter/material.dart';
import '../theme.dart';

class LegalScreen extends StatefulWidget {
  final int initialTabIndex;

  const LegalScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
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
      backgroundColor: kBackgroundLight,
      appBar: AppBar(
        title: const Text('Legal & Policies'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: kBrandPrimary,
          unselectedLabelColor: kSecondaryText,
          indicatorColor: kBrandPrimary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Privacy Policy'),
            Tab(text: 'Terms of Service'),
            Tab(text: 'Cancellation & Refunds'),
            Tab(text: '30-Day Warranty'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PrivacyPolicyView(),
          _TermsOfServiceView(),
          _CancellationPolicyView(),
          _WarrantyPolicyView(),
        ],
      ),
    );
  }
}

// ─── 1. Privacy Policy Tab ───────────────────────────────────────────────────

class _PrivacyPolicyView extends StatelessWidget {
  const _PrivacyPolicyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(
          title: 'Privacy Policy',
          subtitle: 'DPDP Act 2023 & IT Act 2000 Compliant',
          badge: 'Effective Aug 2026',
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: '1. Introduction',
          content:
              'BookUrTechnician Technologies Private Limited ("BookUrTechnician", "we", "us") values your privacy. '
              'This Privacy Policy describes how we collect, use, and share personal data when you use our mobile applications and doorstep services.',
        ),
        _buildSectionCard(
          title: '2. Information We Collect',
          content:
              '• Contact & Identity: Name, phone number, email address, service addresses.\n'
              '• Real-time GPS Location: Used solely for calculating technician ETA, matching nearby service pros, and live navigation telemetry.\n'
              '• Appliance & Diagnosis Data: Appliance model, issue description, diagnostic photos.\n'
              '• Payment Reference Tokens: Processed securely via RBI-authorized PCI-DSS Level 1 payment gateways (Razorpay/Stripe). We never store raw card or CVV details.',
        ),
        _buildSectionCard(
          title: '3. Privacy-Safe Masked Calling',
          content:
              'To protect your personal mobile number from unsolicited contact, all direct phone calls between you and assigned technician partners are routed through a secure cloud telephony bridge. Phone numbers remain masked on both ends.',
        ),
        _buildSectionCard(
          title: '4. Third-Party Sharing',
          content:
              'We never sell your personal information. Data is shared exclusively with:\n'
              '• Assigned Technicians (Name and address to fulfill booked service).\n'
              '• Cloud & Gateway Vendors (AWS/Google Cloud, Razorpay, Brevo for transactional email OTPs, Mapbox for navigation).\n'
              '• Legal Authorities only when compelled by lawful governmental court order.',
        ),
        _buildSectionCard(
          title: '5. Your Rights & Account Deletion',
          content:
              'Under the DPDP Act 2023, you have the right to access, correct, or permanently delete your account data. You can request account deletion directly from the profile screen or by writing to privacy@bookurtechnician.com.',
        ),
        _buildGrievanceCard(),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── 2. Terms of Service Tab ─────────────────────────────────────────────────

class _TermsOfServiceView extends StatelessWidget {
  const _TermsOfServiceView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(
          title: 'Terms of Service',
          subtitle: 'Binding Contract for Doorstep Services',
          badge: 'Version 2.4',
          icon: Icons.gavel_outlined,
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: '1. Acceptance & Eligibility',
          content:
              'By accessing or placing a booking on BookUrTechnician, you represent that you are at least 18 years old and legally capable of entering into binding contracts under the Indian Contract Act, 1872.',
        ),
        _buildSectionCard(
          title: '2. Intermediary Platform Role',
          content:
              'BookUrTechnician operates a technology marketplace connecting customers with verified independent service partners. While we perform thorough KYC, background checks, and quality supervision, technician partners deliver services as independent contractors.',
        ),
        _buildSectionCard(
          title: '3. Visiting Fee & Standardized Rate Card',
          content:
              '• A standard visiting/inspection fee applies for doorstep diagnostics.\n'
              '• If you approve the repair quotation, the visiting fee is adjusted into the final invoice.\n'
              '• If you decline repairs after on-site physical inspection, the visiting fee compensates the technician for travel and diagnostic time.\n'
              '• Spare parts are billed strictly against transparent in-app rate cards.',
        ),
        _buildSectionCard(
          title: '4. Code of Conduct',
          content:
              'Customers must provide a safe environment with an adult (18+) present. BookUrTechnician maintains zero tolerance for verbal abuse, harassment, or unsafe premises.',
        ),
        _buildSectionCard(
          title: '5. Limitation of Liability',
          content:
              'To the maximum extent permitted under law, BookUrTechnician\'s total aggregate liability for any service booking shall not exceed the invoice amount paid for that booking or ₹5,000, whichever is lower.',
        ),
        _buildSectionCard(
          title: '6. Jurisdiction & Dispute Redressal',
          content:
              'These terms are governed by the laws of India. Any legal disputes shall be subject to the exclusive jurisdiction of the civil courts in Bengaluru, Karnataka, India.',
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── 3. Cancellation & Refund Tab ───────────────────────────────────────────

class _CancellationPolicyView extends StatelessWidget {
  const _CancellationPolicyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(
          title: 'Cancellation & Refunds',
          subtitle: 'Transparent, Fair & Automated',
          badge: 'Instant UPI Refund',
          icon: Icons.currency_rupee_outlined,
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cancellation Fee Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _buildFeeRow('> 2 Hours before slot', '₹0 (Free)', '100% Refund', kSuccessGreen),
                const Divider(),
                _buildFeeRow('< 2 Hours (Tech not en-route)', '₹0 (Free)', '100% Refund', kSuccessGreen),
                const Divider(),
                _buildFeeRow('After Tech is En-Route', '₹50 Travel Fee', 'Balance Refunded', kWarningAmber),
                const Divider(),
                _buildFeeRow('After Tech Arrives Doorstep', 'Visiting Fee (₹99)', 'Balance Refunded', kErrorRed),
                const Divider(),
                _buildFeeRow('Cancelled by BookUrTechnician', '₹0 + ₹50 Credit', '100% Instant Refund', kSuccessGreen),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Refund Timelines',
          content:
              '• UPI / Wallet: 1 to 2 hours (Maximum 24 hours).\n'
              '• Debit Cards & Net Banking: 3 to 5 banking working days.\n'
              '• Credit Cards: 5 to 7 billing cycle business days.',
        ),
        _buildSectionCard(
          title: 'Free Rescheduling',
          content:
              'You can reschedule your appointment free of charge up to 1 hour before the scheduled slot directly from your Booking History screen.',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFeeRow(String condition, String fee, String refund, Color feeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(condition, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fee, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: feeColor)),
              Text(refund, style: const TextStyle(fontSize: 11, color: kSecondaryText)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 4. 30-Day Guarantee Tab ─────────────────────────────────────────────────

class _WarrantyPolicyView extends StatelessWidget {
  const _WarrantyPolicyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(
          title: '30-Day Service Guarantee',
          subtitle: 'Peace of Mind On Every Repair',
          badge: '100% Quality Assured',
          icon: Icons.verified_outlined,
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'How It Works',
          content:
              'If the exact same issue recurs within 30 days of service completion, BookUrTechnician will dispatch a senior certified technician for re-inspection and rework at ₹0 additional labor charge.',
        ),
        _buildSectionCard(
          title: 'What Is Covered',
          content:
              '• Recurrence of the diagnostic fault fixed in the original invoice.\n'
              '• Workmanship defects related to technician installation or assembly.\n'
              '• Genuine spare parts sourced through BookUrTechnician (carry manufacturer part warranty).',
        ),
        _buildSectionCard(
          title: 'Exclusions',
          content:
              '• Subsequent physical damage, water spill, or high voltage electrical surges.\n'
              '• Repairs or tampering attempted by unauthorized third-party technicians after our visit.\n'
              '• New or unrelated mechanical failures.',
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Common Helper Widgets ───────────────────────────────────────────────────

Widget _buildHeaderCard({
  required String title,
  required String subtitle,
  required String badge,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [kBrandPrimary, Color(0xFF1D4ED8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
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

Widget _buildSectionCard({required String title, required String content}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: kPrimaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: kSecondaryText,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildGrievanceCard() {
  return Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: kLightBlue,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBrandPrimary.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.contact_mail_outlined, color: kBrandPrimary, size: 20),
            SizedBox(width: 8),
            Text(
              'Grievance Redressal Officer',
              style: TextStyle(fontWeight: FontWeight.bold, color: kBrandPrimary, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'In accordance with the DPDP Act 2023 & IT Rules:\n'
          'Name: Grievance Officer, BookUrTechnician Pvt. Ltd.\n'
          'Email: privacy@bookurtechnician.com\n'
          'Address: HSR Layout, Sector 7, Bengaluru, 560102, India\n'
          'Response Timeline: Acknowledged within 24h, resolved within 15 days.',
          style: TextStyle(fontSize: 12, color: kPrimaryText, height: 1.4),
        ),
      ],
    ),
  );
}

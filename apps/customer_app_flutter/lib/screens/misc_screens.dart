import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../booking_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(bookingProvider);
    final isGuest = appState.isGuest;

    if (isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // Guest Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: kBrandPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline, size: 36, color: kBrandPrimary),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Welcome to BookUrTechnician',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: kPrimaryText),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Log in or register to book services, track certified technicians, and view history.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kSecondaryText, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrandPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('LOG IN / SIGN UP', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Benefits of joining card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.stars_rounded, color: kBrandPrimary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Member Benefits',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPrimaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildBenefitRow('⚡ Real-time GPS technician tracking at doorstep'),
                  _buildBenefitRow('🛡️ 30-Day Hassle-Free Service Warranty'),
                  _buildBenefitRow('🧾 Official GST Invoices & Verified Technicians'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Legal & Support', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kSecondaryText)),
            const SizedBox(height: 8),
            _ProfileTile(Icons.help_outline, 'Help & Support', () => Navigator.pushNamed(context, '/support')),
            _ProfileTile(Icons.privacy_tip_outlined, 'Privacy Policy', () => Navigator.pushNamed(context, '/privacy')),
            _ProfileTile(Icons.description_outlined, 'Terms of Service', () => Navigator.pushNamed(context, '/terms')),
            _ProfileTile(Icons.assignment_return_outlined, 'Cancellation & Refund Policy', () => Navigator.pushNamed(context, '/legal', arguments: 2)),
            _ProfileTile(Icons.verified_outlined, '30-Day Guarantee & Warranties', () => Navigator.pushNamed(context, '/legal', arguments: 3)),
          ],
        ),
      );
    }

    final profile = appState.profile;
    final is100 = profile.isProfileComplete;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: kPrimaryText,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── USER HEADER ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD9E2F2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: kBrandPrimary,
                  backgroundImage: profile.profilePhotoUrl != null ? NetworkImage(profile.profilePhotoUrl!) : null,
                  child: profile.profilePhotoUrl == null
                      ? Text(
                          profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName.isNotEmpty ? profile.fullName : 'Valued Customer',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kPrimaryText),
                      ),
                      const SizedBox(height: 2),
                      Text(profile.phone, style: const TextStyle(color: kSecondaryText, fontSize: 12.5)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                            child: const Text('✓ Verified Customer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, '/profile_details'),
                  icon: const Icon(Icons.edit_outlined, color: kBrandPrimary, size: 20),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── DYNAMIC PROFILE COMPLETION CARD ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: is100 ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: is100 ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          is100 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: is100 ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          is100 ? '✓ Profile complete' : '⚠ Incomplete profile',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: is100 ? const Color(0xFF15803D) : const Color(0xFFC2410C),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${profile.profileCompletion}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: is100 ? const Color(0xFF15803D) : const Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: profile.profileCompletion / 100.0,
                    minHeight: 6,
                    backgroundColor: Colors.white,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      is100 ? const Color(0xFF22C55E) : const Color(0xFFF97316),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        is100
                            ? 'Your profile is ready'
                            : 'Your profile is ${profile.profileCompletion}% complete. Add your ${profile.missingFieldsReadable}.',
                        style: TextStyle(
                          fontSize: 12,
                          color: is100 ? const Color(0xFF166534) : const Color(0xFF9A3412),
                        ),
                      ),
                    ),
                    if (!is100) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/profile_completion_wizard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: const Size(60, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Complete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── NAV TILES ───
          _ProfileTile(Icons.person_outline, 'Profile Details', () => Navigator.pushNamed(context, '/profile_details')),
          _ProfileTile(Icons.location_on_outlined, 'My Addresses (${profile.addresses.length})', () => Navigator.pushNamed(context, '/saved_addresses')),
          _ProfileTile(Icons.history, 'My Bookings', () => Navigator.pushNamed(context, '/history')),
          _ProfileTile(Icons.notifications_outlined, 'Notifications', () => Navigator.pushNamed(context, '/notifications')),
          _ProfileTile(Icons.help_outline, 'Help & Support', () => Navigator.pushNamed(context, '/support')),
          _ProfileTile(Icons.privacy_tip_outlined, 'Privacy Policy', () => Navigator.pushNamed(context, '/privacy')),
          _ProfileTile(Icons.description_outlined, 'Terms of Service', () => Navigator.pushNamed(context, '/terms')),
          _ProfileTile(Icons.assignment_return_outlined, 'Cancellation & Refund Policy', () => Navigator.pushNamed(context, '/legal', arguments: 2)),
          _ProfileTile(Icons.verified_outlined, '30-Day Guarantee & Warranties', () => Navigator.pushNamed(context, '/legal', arguments: 3)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRedError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ref.read(bookingProvider.notifier).setGuestMode(true);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  static Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: kBrandPrimary, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: kPrimaryText))),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ProfileTile(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: kBrandPrimary),
      title: Text(label),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kTextGray),
      onTap: onTap,
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      _Notif('Booking Confirmed 🎉', 'Your AC service booking has been confirmed!', '2h ago'),
      _Notif('Technician Assigned', 'Rahul Sharma will be at your place tomorrow.', '1d ago'),
      _Notif('Special Offer 🏷️', 'Use FIRST100 for ₹100 off your first service.', '2d ago'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (_, i) {
          final n = notifications[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: kBrandPrimary)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(n.body, style: const TextStyle(fontSize: 12, color: kTextGray)),
                  const SizedBox(height: 4),
                  Text(n.time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Notif {
  final String title, body, time;
  const _Notif(this.title, this.body, this.time);
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  final _faqs = const [
    _Faq('How do I book a service?', 'Browse categories on the Home screen, add services to cart, and proceed to checkout.'),
    _Faq('Can I reschedule my booking?', 'Yes, you can reschedule from the Booking History screen up to 2 hours before the appointment.'),
    _Faq('What payment methods are accepted?', 'We accept UPI, Credit/Debit Cards, and Net Banking.'),
    _Faq('What is the cancellation policy?', 'Free cancellation up to 4 hours before the appointment. After that, a ₹50 fee applies.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [kBrandPrimary, Color(0xFF1D4ED8)]),
                borderRadius: BorderRadius.circular(14)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('We\'re here to help!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height: 8),
              Text('Reach out via call or chat anytime.', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('Frequently Asked Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ..._faqs.map((f) => ExpansionTile(
            title: Text(f.question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            children: [Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(f.answer, style: const TextStyle(color: kTextGray)),
            )],
          )),
        ],
      ),
    );
  }
}

class _Faq {
  final String question, answer;
  const _Faq(this.question, this.answer);
}

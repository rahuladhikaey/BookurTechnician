import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../theme.dart';
import 'saved_addresses_screen.dart';

class ProfileCompletionWizardScreen extends ConsumerStatefulWidget {
  final bool returnToCartOnComplete;
  const ProfileCompletionWizardScreen({super.key, this.returnToCartOnComplete = false});

  @override
  ConsumerState<ProfileCompletionWizardScreen> createState() => _ProfileCompletionWizardScreenState();
}

class _ProfileCompletionWizardScreenState extends ConsumerState<ProfileCompletionWizardScreen> {
  final _nameCtrl = TextEditingController();
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(bookingProvider).profile;
    _nameCtrl.text = profile.fullName;
    _isEditingName = profile.fullName.trim().isEmpty;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveName() {
    final name = _nameCtrl.text.trim();
    if (name.length < 2 || RegExp(r'^[0-9]+$').hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid full name (at least 2 characters, non-numeric).')),
      );
      return;
    }

    ref.read(bookingProvider.notifier).updateProfileDetails(fullName: name);
    setState(() {
      _isEditingName = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Name saved! Profile score updated.')),
    );
  }

  void _openAddAddressModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddAddressBottomSheet(),
    );
  }

  void _handleContinue() {
    final profile = ref.read(bookingProvider).profile;
    if (!profile.isProfileComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete missing fields (${profile.missingFieldsReadable}) to reach 100%.'),
          backgroundColor: kRedError,
        ),
      );
      return;
    }

    if (widget.returnToCartOnComplete) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(bookingProvider);
    final profile = appState.profile;
    final percentage = profile.profileCompletion;
    final is100 = profile.isProfileComplete;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete your profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: kPrimaryText,
        elevation: 0,
        actions: [
          if (!is100)
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              child: const Text('Skip for now', style: TextStyle(color: kSecondaryText, fontSize: 13)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── PROGRESS HEADER CARD ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: is100 ? const Color(0xFFF0FDF4) : const Color(0xFFEEF3FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: is100 ? const Color(0xFFBBF7D0) : const Color(0xFFD9E2F2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        is100 ? '✓ Profile Complete' : 'Profile Completion',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: is100 ? const Color(0xFF15803D) : kBrandPrimary,
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: is100 ? const Color(0xFF15803D) : kBrandPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentage / 100.0,
                      minHeight: 10,
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        is100 ? const Color(0xFF22C55E) : kBrandPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    is100
                        ? 'Your profile is ready. You are all set to book certified doorstep technicians!'
                        : 'Add your details below to reach 100% and unlock seamless booking & warranty.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: is100 ? const Color(0xFF166534) : const Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Required Profile Details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kPrimaryText),
            ),
            const SizedBox(height: 4),
            const Text(
              'All 4 core items are necessary for doorstep service dispatch.',
              style: TextStyle(fontSize: 12, color: kSecondaryText),
            ),
            const SizedBox(height: 16),

            // ─── 1. FULL NAME ───
            _buildChecklistCard(
              isDone: !profile.missingFields.contains('FULL_NAME'),
              title: 'Full Name',
              subtitle: profile.fullName.isNotEmpty ? profile.fullName : 'Please enter your real full name',
              actionWidget: _isEditingName
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Enter your full name',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: _saveName,
                            style: ElevatedButton.styleFrom(backgroundColor: kBlack),
                            child: const Text('Save Name', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    )
                  : TextButton(
                      onPressed: () => setState(() => _isEditingName = true),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                      child: Text(profile.fullName.isEmpty ? 'Add Name' : 'Edit', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ),

            const SizedBox(height: 12),

            // ─── 2. VERIFIED PHONE ───
            _buildChecklistCard(
              isDone: profile.isPhoneVerified,
              title: 'Mobile Number',
              subtitle: profile.phone.isNotEmpty ? profile.phone : 'Not provided',
              badgeText: '✓ Verified via OTP',
            ),

            const SizedBox(height: 12),

            // ─── 3. VERIFIED EMAIL ───
            _buildChecklistCard(
              isDone: profile.isEmailVerified,
              title: 'Email Address',
              subtitle: profile.email.isNotEmpty ? profile.email : 'Not provided',
              badgeText: profile.isEmailVerified ? '✓ Verified via OTP' : 'Verification Required',
            ),

            const SizedBox(height: 12),

            // ─── 4. SERVICE ADDRESS ───
            _buildChecklistCard(
              isDone: profile.addresses.isNotEmpty,
              title: 'Service Address',
              subtitle: profile.primaryAddress != null
                  ? '${profile.primaryAddress!.typeLabel}: ${profile.primaryAddress!.formattedAddress}'
                  : 'Add your doorstep service location',
              actionWidget: TextButton(
                onPressed: _openAddAddressModal,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                child: Text(profile.addresses.isEmpty ? '+ Add Address' : 'Manage', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 28),

            // ─── OPTIONAL PREFERENCES ACCORDION ───
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: kSecondaryText),
                  SizedBox(width: 8),
                  Text('Optional Details (Does not affect 100%)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: kSecondaryText)),
                ],
              ),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date of Birth & Anniversary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Receive special discounts on your birthday & anniversary', style: TextStyle(fontSize: 11.5, color: kSecondaryText)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.pushNamed(context, '/profile_details'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ─── BOTTOM CTA ───
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: is100 ? kBrandPrimary : const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  is100
                      ? (widget.returnToCartOnComplete ? 'Return to My Cart' : 'Start Booking Services ✓')
                      : 'Complete Profile to Continue',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistCard({
    required bool isDone,
    required String title,
    required String subtitle,
    Widget? actionWidget,
    String? badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDone ? const Color(0xFFD9E2F2) : const Color(0xFFFED7AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check_rounded : Icons.priority_high_rounded,
              color: isDone ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kPrimaryText)),
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isDone ? const Color(0xFF15803D) : kRedError,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 12.5, color: kSecondaryText)),
                ?actionWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

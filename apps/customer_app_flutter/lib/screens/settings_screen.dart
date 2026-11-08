import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../services/api_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _whatsAppEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _emailEnabled = true;
  bool _smsEnabled = true;
  bool _voiceCallsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF222222)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF222222),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // ─── 1. NOTIFICATIONS & REMINDERS SECTION ───
          const Text(
            'Notifications & reminders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF222222),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),

          // Alert Card: Push Notifications off
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E0).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFBE4D5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Push Notifications',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Notifications are currently off. You can enable them from settings.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF222222),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening device system notification settings...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFF222222),
                    side: const BorderSide(color: Color(0xFF222222), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(120, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Go to Settings',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── TOGGLE LIST ───
          _buildToggleRow(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'WhatsApp',
            value: _whatsAppEnabled,
            onChanged: (val) => setState(() => _whatsAppEnabled = val),
          ),
          const Divider(height: 1, color: Color(0xFFFCF9F6)),

          _buildToggleRow(
            icon: Icons.notifications_none_rounded,
            title: 'Push Notifications',
            value: _pushNotificationsEnabled,
            onChanged: (val) => setState(() => _pushNotificationsEnabled = val),
          ),
          const Divider(height: 1, color: Color(0xFFFCF9F6)),

          _buildToggleRow(
            icon: Icons.mail_outline_rounded,
            title: 'Email',
            value: _emailEnabled,
            onChanged: (val) => setState(() => _emailEnabled = val),
          ),
          const Divider(height: 1, color: Color(0xFFFCF9F6)),

          _buildToggleRow(
            icon: Icons.sms_outlined,
            title: 'SMS',
            value: _smsEnabled,
            onChanged: (val) => setState(() => _smsEnabled = val),
          ),
          const Divider(height: 1, color: Color(0xFFFCF9F6)),

          _buildToggleRow(
            icon: Icons.phone_outlined,
            title: 'Voice calls',
            value: _voiceCallsEnabled,
            onChanged: (val) => setState(() => _voiceCallsEnabled = val),
          ),
          const SizedBox(height: 16),

          // Order Related Messages Info Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFCF9F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order related messages',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Order related messages can\'t be turned off as they are important for service experience',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF77716C),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ─── 2. PRIVACY & DATA SECTION ───
          const Text(
            'Privacy & data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF222222),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Delete account',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF77716C)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyCenterScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF222222)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF198754),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFEEE8E2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── PRIVACY CENTER: ACCOUNT DELETION SCREEN ─────────────────────────────────

class PrivacyCenterScreen extends ConsumerStatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  ConsumerState<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends ConsumerState<PrivacyCenterScreen> {
  bool _isDeleting = false;

  void _confirmAccountDeletion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Account permanently?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF222222)),
        ),
        content: const Text(
          'This action is irreversible. All your profile data, active warranties, history, and saved addresses will be deleted immediately.',
          style: TextStyle(fontSize: 13, color: Color(0xFF77716C), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF77716C), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC3545),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isDeleting = true);
              try {
                await ApiClient.deleteAccount(reason: 'Customer initiated in-app account deletion');
                await ref.read(bookingProvider.notifier).logoutUser();
                if (mounted) {
                  setState(() => _isDeleting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your account and personal data have been deleted successfully.'),
                      backgroundColor: Color(0xFF222222),
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isDeleting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deletion notice: ${e.toString().replaceAll("Exception: ", "")}'),
                      backgroundColor: const Color(0xFFDC3545),
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEEE8E2)),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF222222)),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Privacy Center',
          style: TextStyle(
            color: Color(0xFF222222),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account Deletion Policy',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF222222),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 24),

              // Bullet Points matching Image 2
              _buildBulletPoint('You\'ll no longer be able to access your saved professionals'),
              const SizedBox(height: 16),
              _buildBulletPoint('Your customer rating will be reset'),
              const SizedBox(height: 16),
              _buildBulletPoint('All your memberships will be cancelled'),
              const SizedBox(height: 16),
              _buildBulletPoint('You\'ll not be able to claim under any active warranty or insurance'),
              const SizedBox(height: 16),
              _buildBulletPoint('The changes are irreversible'),

              const SizedBox(height: 36),

              // Delete Account Outlined Button
              OutlinedButton(
                onPressed: _isDeleting ? null : _confirmAccountDeletion,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFDC3545),
                  side: const BorderSide(color: Color(0xFFEEE8E2), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC3545)),
                      )
                    : const Text(
                        'Delete Account',
                        style: TextStyle(
                          color: Color(0xFFDC3545),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '• ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF222222),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

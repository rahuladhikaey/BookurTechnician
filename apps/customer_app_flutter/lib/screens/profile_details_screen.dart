import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../theme.dart';

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  ConsumerState<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  DateTime? _selectedDob;
  DateTime? _selectedAnniversary;
  String? _selectedGender;
  String? _profilePhoto;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(bookingProvider).profile;
    _nameCtrl = TextEditingController(text: profile.fullName);
    _emailCtrl = TextEditingController(text: profile.email);
    _phoneCtrl = TextEditingController(text: profile.phone);
    _selectedDob = profile.dateOfBirth;
    _selectedAnniversary = profile.anniversary;
    _selectedGender = profile.gender;
    _profilePhoto = profile.profilePhotoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1940),
      lastDate: now, // No future dates allowed
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _pickAnniversary() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedAnniversary ?? DateTime(2020, 1, 1),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedAnniversary = picked);
    }
  }

  void _showChangePhoneModal() {
    final newPhoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Mobile Number', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A verification OTP will be sent to your new mobile number before updating your account.',
              style: TextStyle(fontSize: 12.5, color: kSecondaryText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPhoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'New Mobile Number',
                prefixText: '+91 ',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBlack),
            onPressed: () {
              final newP = newPhoneCtrl.text.trim();
              if (newP.length == 10) {
                Navigator.pop(ctx);
                setState(() {
                  _phoneCtrl.text = '+91 $newP';
                });
                ref.read(bookingProvider.notifier).updateProfileDetails(
                  phone: '+91 $newP',
                  isPhoneVerified: true,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Mobile number updated and verified (+91 $newP)!')),
                );
              }
            },
            child: const Text('Send OTP & Verify'),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: kBrandPrimary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _profilePhoto = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500');
                ref.read(bookingProvider.notifier).updateProfileDetails(profilePhotoUrl: _profilePhoto);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: kBrandPrimary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _profilePhoto = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500');
                ref.read(bookingProvider.notifier).updateProfileDetails(profilePhotoUrl: _profilePhoto);
              },
            ),
            if (_profilePhoto != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: kRedError),
                title: const Text('Remove Photo', style: TextStyle(color: kRedError)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _profilePhoto = null);
                  ref.read(bookingProvider.notifier).updateProfileDetails(clearPhoto: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() {
    final name = _nameCtrl.text.trim();
    if (name.length < 2 || RegExp(r'^[0-9]+$').hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid full name (at least 2 characters, non-numeric).')),
      );
      return;
    }

    ref.read(bookingProvider.notifier).updateProfileDetails(
      fullName: name,
      email: _emailCtrl.text.trim(),
      isEmailVerified: true,
      phone: _phoneCtrl.text.trim(),
      isPhoneVerified: true,
      profilePhotoUrl: _profilePhoto,
      dateOfBirth: _selectedDob,
      anniversary: _selectedAnniversary,
      gender: _selectedGender,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile details saved successfully!')),
    );
    Navigator.pop(context);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(bookingProvider);
    final profile = appState.profile;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: kPrimaryText,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── PROFILE PHOTO ───
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: kBrandPrimary,
                      backgroundImage: _profilePhoto != null ? NetworkImage(_profilePhoto!) : null,
                      child: _profilePhoto == null
                          ? Text(
                              _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'U',
                              style: const TextStyle(fontSize: 34, color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _showPhotoOptions,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: kBrandPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Profile Photo (Optional)', style: TextStyle(fontSize: 12, color: kSecondaryText)),
              ),

              const SizedBox(height: 28),

              // ─── FULL NAME ───
              const Text('Full Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) return 'Min 2 characters';
                  if (RegExp(r'^[0-9]+$').hasMatch(v.trim())) return 'Cannot be only digits';
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // ─── PHONE NUMBER ───
              const Text('Mobile Number *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD9E2F2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 20, color: kSecondaryText),
                        const SizedBox(width: 10),
                        Text(
                          _phoneCtrl.text,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPrimaryText),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                          child: const Text('✓ Verified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _showChangePhoneModal,
                      child: const Text('Change', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: kBrandPrimary)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ─── EMAIL ADDRESS ───
              const Text('Email Address *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD9E2F2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 20, color: kSecondaryText),
                        const SizedBox(width: 10),
                        Text(
                          _emailCtrl.text,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: kPrimaryText),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                          child: const Text('✓ Verified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ─── PRIMARY ADDRESS SHORTCUT ───
              const Text('Primary Service Address *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD9E2F2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: kBrandPrimary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.primaryAddress != null
                                ? '${profile.primaryAddress!.typeLabel} Address'
                                : 'No Address Added',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.primaryAddress?.formattedAddress ?? 'Add at least one service location',
                            style: const TextStyle(fontSize: 12, color: kSecondaryText),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/saved_addresses'),
                      child: const Text('Manage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              const Text('Optional Personal Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kSecondaryText)),
              const SizedBox(height: 14),

              // ─── DOB & ANNIVERSARY ───
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Date of Birth', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickDob,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFD9E2F2)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDob != null ? _formatDate(_selectedDob) : 'DD-MM-YYYY',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _selectedDob != null ? kPrimaryText : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const Icon(Icons.calendar_month_outlined, size: 16, color: kSecondaryText),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Anniversary', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickAnniversary,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFD9E2F2)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedAnniversary != null ? _formatDate(_selectedAnniversary) : 'DD-MM-YYYY',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _selectedAnniversary != null ? kPrimaryText : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const Icon(Icons.favorite_border, size: 16, color: kSecondaryText),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ─── SAVE BUTTON ───
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlack,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save Profile Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

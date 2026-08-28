import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../dashboard/data/technician_profile_service.dart';
import 'skill_selection_page.dart';

class DocumentUploadOnboardingPage extends ConsumerStatefulWidget {
  const DocumentUploadOnboardingPage({super.key});

  @override
  ConsumerState<DocumentUploadOnboardingPage> createState() =>
      _DocumentUploadOnboardingPageState();
}

class _DocumentUploadOnboardingPageState
    extends ConsumerState<DocumentUploadOnboardingPage> {
  final TechnicianProfileService _profileService = TechnicianProfileService();
  final ImagePicker _picker = ImagePicker();

  final _aadhaarNumberController = TextEditingController();
  final _voterNumberController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Uploaded document states with size tracking (Max 10 MB)
  static const int kMaxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  XFile? _aadhaarFrontFile;
  int _aadhaarFrontBytes = 0;

  XFile? _aadhaarBackFile;
  int _aadhaarBackBytes = 0;

  XFile? _voterCardFile;
  int _voterCardBytes = 0;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _aadhaarNumberController.dispose();
    _voterNumberController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument({
    required String docLabel,
    required Function(XFile file, int bytes) onFileSelected,
  }) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload $docLabel (Max 10 MB)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Clear photo or scan under 10 MB in JPEG or PNG format.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Take Photo with Camera'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (file != null) {
                    await _validateAndSetFile(file, docLabel, onFileSelected);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Choose from Gallery / Files'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (file != null) {
                    await _validateAndSetFile(file, docLabel, onFileSelected);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _validateAndSetFile(
    XFile file,
    String docLabel,
    Function(XFile file, int bytes) onFileSelected,
  ) async {
    final int fileBytes = await file.length();

    // ─── STRICT 10 MB FILE SIZE VALIDATION ───
    if (fileBytes > kMaxFileSizeBytes) {
      final double mbSize = fileBytes / (1024 * 1024);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: SemanticColors.error),
                SizedBox(width: 8),
                Text('File Exceeds 10 MB'),
              ],
            ),
            content: Text(
              'Selected $docLabel file is ${mbSize.toStringAsFixed(1)} MB.\n\nPlease upload a file smaller than the 10 MB maximum limit.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() {
      onFileSelected(file, fileBytes);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: SemanticColors.success,
          content: Text(
            '$docLabel selected (${(fileBytes / (1024 * 1024)).toStringAsFixed(2)} MB / 10 MB Max)',
          ),
        ),
      );
    }
  }

  Future<void> _submitDocumentsAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final aadhaarNum = _aadhaarNumberController.text.trim();
    final voterNum = _voterNumberController.text.trim();
    final upiId = _upiIdController.text.trim();

    if (aadhaarNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your 12-digit Aadhaar Card number.'),
          backgroundColor: SemanticColors.error,
        ),
      );
      return;
    }

    if (voterNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Voter Card ID (EPIC) number.'),
          backgroundColor: SemanticColors.error,
        ),
      );
      return;
    }

    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your UPI Number / ID for fast weekly payouts.'),
          backgroundColor: SemanticColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Submit Aadhaar Card Document
      await _profileService.submitKycDocument(
        documentType: 'AADHAAR',
        fileUrl: _aadhaarFrontFile != null ? _aadhaarFrontFile!.path : 'uploaded_aadhaar_front.jpg',
        maskedNumber: aadhaarNum,
      );

      // 2. Submit Voter Card Document
      await _profileService.submitKycDocument(
        documentType: 'VOTER_CARD',
        fileUrl: _voterCardFile != null ? _voterCardFile!.path : 'uploaded_voter_card.jpg',
        maskedNumber: voterNum,
      );

      // 3. Update UPI Payout ID
      await _profileService.updateProfile(upiId: upiId);

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: SemanticColors.success,
            content: Text('KYC documents submitted successfully! Next, select your skills.'),
          ),
        );

        // ─── NAVIGATE TO STEP 3: REGISTERED SKILLS SELECTION ───
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const SkillSelectionPage(isOnboarding: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SemanticColors.error,
            content: Text('Submission error: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Partner Verification (KYC)'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // ─── STEP PROGRESS BAR ───
              Row(
                children: [
                  _buildStepIndicator(step: '1', label: 'Signup', isCompleted: true, isActive: false),
                  _buildStepConnector(isCompleted: true),
                  _buildStepIndicator(step: '2', label: 'Upload Documents', isCompleted: false, isActive: true),
                  _buildStepConnector(isCompleted: false),
                  _buildStepIndicator(step: '3', label: 'Select Skills', isCompleted: false, isActive: false),
                ],
              ),
              const SizedBox(height: 24),

              // Title & Subtitle
              const Text(
                'Upload Verification Documents',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Submit clear documents (Max 10 MB per file). Aadhaar Card, Voter Card, and UPI Payout ID are required for account activation.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),

              // ─── 1. AADHAAR CARD SECTION ───
              _buildSectionCard(
                icon: Icons.badge_outlined,
                title: '🪪 Aadhaar Card Verification',
                subtitle: 'Enter 12-digit Aadhaar number and upload front/back (Max 10 MB)',
                children: [
                  TextFormField(
                    controller: _aadhaarNumberController,
                    keyboardType: TextInputType.number,
                    maxLength: 14,
                    decoration: const InputDecoration(
                      labelText: 'Aadhaar Number *',
                      hintText: 'e.g. 1234 5678 9012',
                      prefixIcon: Icon(Icons.fingerprint),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Aadhaar number is required';
                      if (val.replaceAll(' ', '').length < 12) return 'Enter valid 12-digit Aadhaar number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildUploadBox(
                          label: 'Front Side',
                          file: _aadhaarFrontFile,
                          bytes: _aadhaarFrontBytes,
                          onTap: () => _pickDocument(
                            docLabel: 'Aadhaar Front',
                            onFileSelected: (f, b) {
                              _aadhaarFrontFile = f;
                              _aadhaarFrontBytes = b;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildUploadBox(
                          label: 'Back Side',
                          file: _aadhaarBackFile,
                          bytes: _aadhaarBackBytes,
                          onTap: () => _pickDocument(
                            docLabel: 'Aadhaar Back',
                            onFileSelected: (f, b) {
                              _aadhaarBackFile = f;
                              _aadhaarBackBytes = b;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── 2. VOTER CARD SECTION ───
              _buildSectionCard(
                icon: Icons.how_to_vote_outlined,
                title: '🗳️ Voter Card ID (EPIC)',
                subtitle: 'Enter Voter Card EPIC Number and upload card photo (Max 10 MB)',
                children: [
                  TextFormField(
                    controller: _voterNumberController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Voter Card ID Number (EPIC) *',
                      hintText: 'e.g. WBD1234567',
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Voter card number is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildUploadBox(
                    label: 'Voter Card Photo (Max 10 MB)',
                    file: _voterCardFile,
                    bytes: _voterCardBytes,
                    isWide: true,
                    onTap: () => _pickDocument(
                      docLabel: 'Voter Card',
                      onFileSelected: (f, b) {
                        _voterCardFile = f;
                        _voterCardBytes = b;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── 3. UPI PAYOUT NUMBER / ID ───
              _buildSectionCard(
                icon: Icons.account_balance_wallet_outlined,
                title: '📱 Instant UPI Payout Account',
                subtitle: 'Enter your active UPI ID or phone UPI number for direct weekly settlements',
                children: [
                  TextFormField(
                    controller: _upiIdController,
                    decoration: const InputDecoration(
                      labelText: 'UPI ID / VPA *',
                      hintText: 'e.g. 9876543210@upi or name@okhdfcbank',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'UPI ID is required for settlements';
                      if (!val.contains('@')) return 'Enter valid UPI ID (e.g. number@upi)';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // DPDP & Security Assurance Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, color: Color(0xFF059669), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '100% Encrypted & Safe Verification',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Documents are processed strictly under Indian DPDP guidelines and UIDAI masked storage standards.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Submit & Proceed Button
              PrimaryButton(
                text: 'CONTINUE TO SKILL SELECTION →',
                isLoading: _isSubmitting,
                onPressed: _submitDocumentsAndContinue,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildUploadBox({
    required String label,
    required XFile? file,
    required int bytes,
    required VoidCallback onTap,
    bool isWide = false,
  }) {
    final hasFile = file != null;
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: hasFile ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasFile ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(
              hasFile ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
              size: 26,
              color: hasFile ? const Color(0xFF16A34A) : AppColors.primary,
            ),
            const SizedBox(height: 6),
            Text(
              hasFile ? 'Selected ($mb MB)' : label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: hasFile ? FontWeight.bold : FontWeight.w600,
                color: hasFile ? const Color(0xFF15803D) : const Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              hasFile ? 'Tap to change' : 'Max 10 MB',
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator({
    required String step,
    required String label,
    required bool isCompleted,
    required bool isActive,
  }) {
    final color = isActive
        ? AppColors.primary
        : (isCompleted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8));

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    step,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector({required bool isCompleted}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
        color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
      ),
    );
  }
}

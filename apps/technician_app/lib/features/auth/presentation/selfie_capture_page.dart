import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../dashboard/data/technician_profile_service.dart';

class SelfieCapturePage extends StatefulWidget {
  final String currentPhotoUrl;
  final ValueChanged<String>? onSelfieConfirmed;

  const SelfieCapturePage({
    super.key,
    this.currentPhotoUrl = '',
    this.onSelfieConfirmed,
  });

  @override
  State<SelfieCapturePage> createState() => _SelfieCapturePageState();
}

class _SelfieCapturePageState extends State<SelfieCapturePage> {
  final ImagePicker _picker = ImagePicker();
  final TechnicianProfileService _profileService = TechnicianProfileService();

  bool _isCaptured = false;
  bool _isUploading = false;
  String? _localPhotoPath;
  String _networkPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    _networkPhotoUrl = widget.currentPhotoUrl;
    if (_networkPhotoUrl.isNotEmpty) {
      _isCaptured = true;
    }
  }

  Future<void> _capturePhoto({ImageSource source = ImageSource.camera}) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _localPhotoPath = photo.path;
          _isCaptured = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Camera error: $e. Try selecting from gallery.'),
          ),
        );
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _localPhotoPath = null;
      _isCaptured = false;
    });
  }

  Future<void> _confirmPhoto() async {
    final photoRef = _localPhotoPath ?? _networkPhotoUrl;
    if (photoRef.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture a selfie first.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Sync with backend profile & KYC document vault
      await _profileService.submitKycDocument(
        documentType: 'SELFIE',
        fileUrl: photoRef,
      );
      await _profileService.uploadProfilePhoto(photoRef);

      widget.onSelfieConfirmed?.call(photoRef);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Live selfie verified & synced with Digital ID Card!'),
          ),
        );
        Navigator.pop(context, photoRef);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync selfie: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Take Live Selfie',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Subtitle instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _isCaptured
                    ? 'Review your selfie below. Make sure your face is clearly lit and visible.'
                    : 'Position your face inside the oval frame. Ensure good lighting and look directly at the front camera.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),

            // Camera Viewport & Oval Guide Frame
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  constraints: const BoxConstraints(maxWidth: 320, maxHeight: 380),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Camera Preview or Captured Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(160),
                        child: Container(
                          width: 280,
                          height: 360,
                          color: const Color(0xFF1E293B),
                          child: _localPhotoPath != null
                              ? Image.file(
                                  File(_localPhotoPath!),
                                  fit: BoxFit.cover,
                                )
                              : (_networkPhotoUrl.isNotEmpty
                                  ? Image.network(
                                      _networkPhotoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.person, size: 100, color: Colors.white24),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.person, size: 100, color: Colors.white24),
                                    )),
                        ),
                      ),

                      // Oval Frame Border with Guide Marks
                      Container(
                        width: 284,
                        height: 364,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(162),
                          border: Border.all(
                            color: _isCaptured ? const Color(0xFF16A34A) : const Color(0xFF38BDF8),
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isCaptured ? const Color(0xFF16A34A) : const Color(0xFF38BDF8)).withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),

                      // Guide helper badge
                      Positioned(
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isCaptured ? Icons.check_circle : Icons.face,
                                color: _isCaptured ? const Color(0xFF16A34A) : const Color(0xFF38BDF8),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isCaptured ? 'Selfie Captured' : 'Keep Face Centered',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Selfie Rules & Instructions Box
            if (!_isCaptured)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: AppRadius.medium,
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _RuleItem(icon: Icons.light_mode_outlined, label: 'Good Light'),
                        _RuleItem(icon: Icons.visibility_outlined, label: 'Eyes Open'),
                        _RuleItem(icon: Icons.do_not_disturb_on_outlined, label: 'No Glasses'),
                        _RuleItem(icon: Icons.face_retouching_natural_outlined, label: 'No Mask'),
                      ],
                    ),
                  ],
                ),
              ),

            // Action Buttons (Shutter / Retake / Confirm)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _isUploading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  : (_isCaptured
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _retakePhoto,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white38),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('RETAKE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _confirmPhoto,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text(
                                  'USE THIS PHOTO',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: () => _capturePhoto(source: ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                                label: const Text(
                                  'CAPTURE LIVE SELFIE',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _capturePhoto(source: ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined, size: 18, color: Colors.white70),
                              label: const Text('Or select photo from gallery', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                            ),
                          ],
                        )),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RuleItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF38BDF8), size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

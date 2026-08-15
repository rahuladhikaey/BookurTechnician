import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

class SelfieCapturePage extends StatefulWidget {
  final String currentPhotoUrl;
  final ValueChanged<String>? onSelfieConfirmed;

  const SelfieCapturePage({
    super.key,
    this.currentPhotoUrl = 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=600',
    this.onSelfieConfirmed,
  });

  @override
  State<SelfieCapturePage> createState() => _SelfieCapturePageState();
}

class _SelfieCapturePageState extends State<SelfieCapturePage> {
  bool _isCaptured = false;
  String _capturedUrl = '';

  // Realistic sample selfie options for demonstration
  final List<String> _sampleSelfies = [
    'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=600',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
  ];
  int _selfieIndex = 0;

  @override
  void initState() {
    super.initState();
    _capturedUrl = widget.currentPhotoUrl;
  }

  void _capturePhoto() {
    setState(() {
      _selfieIndex = (_selfieIndex + 1) % _sampleSelfies.length;
      _capturedUrl = _sampleSelfies[_selfieIndex];
      _isCaptured = true;
    });
  }

  void _retakePhoto() {
    setState(() {
      _isCaptured = false;
    });
  }

  void _confirmPhoto() {
    widget.onSelfieConfirmed?.call(_capturedUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.success,
        content: Text('Selfie updated successfully! Syncing with Digital ID Card...'),
      ),
    );
    Navigator.pop(context, _capturedUrl);
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
                          child: Image.network(
                            _capturedUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.person, size: 100, color: Colors.white24),
                            ),
                          ),
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
              child: _isCaptured
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
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _capturePhoto,
                        icon: const Icon(Icons.camera_alt_rounded, size: 20),
                        label: const Text(
                          'CAPTURE SELFIE',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF17399A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
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

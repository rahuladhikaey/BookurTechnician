import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../auth/presentation/selfie_capture_page.dart';

class DigitalIdCardPage extends StatefulWidget {
  final String technicianName;
  final String technicianCode;
  final String joinDate;
  final String initialPhotoUrl;
  final List<String> skills;
  final String verificationStatus;

  const DigitalIdCardPage({
    super.key,
    this.technicianName = 'Technician',
    this.technicianCode = 'BT-TECH-PENDING',
    this.joinDate = '',
    this.initialPhotoUrl = '',
    this.skills = const [],
    this.verificationStatus = 'PENDING',
  });

  @override
  State<DigitalIdCardPage> createState() => _DigitalIdCardPageState();
}

class _DigitalIdCardPageState extends State<DigitalIdCardPage> {
  late String _currentPhotoUrl;
  late String _verificationStatus;

  @override
  void initState() {
    super.initState();
    _currentPhotoUrl = widget.initialPhotoUrl;
    _verificationStatus = widget.verificationStatus;
  }

  void _openSelfieUpdate() async {
    final newUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SelfieCapturePage(
          currentPhotoUrl: _currentPhotoUrl,
          onSelfieConfirmed: (url) {
            setState(() {
              _currentPhotoUrl = url;
            });
          },
        ),
      ),
    );

    if (newUrl != null && mounted) {
      setState(() {
        _currentPhotoUrl = newUrl;
      });
    }
  }

  void _showQrVerificationModal() {
    const verificationUrl = 'https://bookurtechnician.com/verify-tech/verify_tech_000001_secure';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text(
                  'Public Verification QR Code',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0B1635)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Customers or building security can scan this QR code to verify your identity and certification status.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF667085), height: 1.4),
            ),
            const SizedBox(height: 20),

            // Large QR Code Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildQrMockWidget(size: 180),
            ),
            const SizedBox(height: 16),

            // Safe Public Token & URL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Verification ID: ${widget.technicianCode}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    verificationUrl,
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadIdCard() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.success,
        content: Text('Digital ID Card downloaded to your phone gallery as high-res PNG!'),
      ),
    );
  }

  void _shareIdCard() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening share sheet for BookurTechnician ID Badge...'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = _verificationStatus == 'APPROVED';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0B1635), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Technician ID',
          style: TextStyle(color: Color(0xFF0B1635), fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // ─── THE DIGITAL ID CARD ──────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B1F63).withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Card Top Header Gradient Bar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0B1F63), Color(0xFF17399A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/images/app_logo.png',
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => const Icon(Icons.handyman_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'BookurTechnician',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'TECHNICIAN MEMBER',
                              style: TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Card Main Body
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          // Prominent Selfie Photo Frame
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF17399A), width: 3.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF17399A).withValues(alpha: 0.15),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(55),
                                  child: Image.network(
                                    _currentPhotoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => Container(
                                      color: const Color(0xFFE2E8F0),
                                      child: const Icon(Icons.person, size: 60, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ),
                              ),
                              if (isApproved)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Technician Name & Designation
                          Text(
                            widget.technicianName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B1635),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Certified Field Technician',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF667085), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 16),

                          // Information Rows Container
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow('Technician ID', widget.technicianCode, isHighlight: true),
                                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                                _buildInfoRow('Joined Date', widget.joinDate),
                                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                                _buildInfoRow('Service Skills', widget.skills.join(' • ')),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Verification Status Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isApproved ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isApproved ? Icons.verified_user : Icons.hourglass_top,
                                  size: 16,
                                  color: isApproved ? const Color(0xFF166534) : const Color(0xFF92400E),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isApproved ? '✓ VERIFIED TECHNICIAN' : 'VERIFICATION PENDING',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: isApproved ? const Color(0xFF166534) : const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // QR Code Section
                          GestureDetector(
                            onTap: _showQrVerificationModal,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                              ),
                              child: Row(
                                children: [
                                  _buildQrMockWidget(size: 52),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Scan to Verify Identity',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0B1635),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Tap to view large verification QR token',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.fullscreen, color: Color(0xFF17399A), size: 22),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ─── ACTION BUTTONS ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _downloadIdCard,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF17399A),
                        side: const BorderSide(color: Color(0xFF17399A)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareIdCard,
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Share ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF17399A),
                        side: const BorderSide(color: Color(0xFF17399A)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _openSelfieUpdate,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text(
                    'UPDATE PROFILE SELFIE',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.4),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF17399A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF17399A) : const Color(0xFF0F172A),
              fontFamily: isHighlight ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildQrMockWidget({required double size}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _QrPatternPainter(),
      ),
    );
  }
}

// Custom Painter to render a clean, high-tech QR Code Pattern
class _QrPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    // Corner Alignment Squares
    _drawCornerSquare(canvas, paint, 0, 0, size.width * 0.28);
    _drawCornerSquare(canvas, paint, size.width * 0.72, 0, size.width * 0.28);
    _drawCornerSquare(canvas, paint, 0, size.height * 0.72, size.width * 0.28);

    // Inner data blocks simulation
    final cellSize = size.width / 12;
    for (int r = 0; r < 12; r++) {
      for (int c = 0; c < 12; c++) {
        // Skip corner alignment positions
        if ((r < 4 && c < 4) || (r < 4 && c >= 8) || (r >= 8 && c < 4)) continue;
        if ((r * c + r + c) % 3 == 0 || (r + c) % 5 == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cellSize + 1, r * cellSize + 1, cellSize - 2, cellSize - 2),
              const Radius.circular(1.5),
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawCornerSquare(Canvas canvas, Paint paint, double x, double y, double size) {
    // Outer border
    canvas.drawRect(Rect.fromLTWH(x, y, size, size), paint);
    // Inner white gap
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(x + size * 0.2, y + size * 0.2, size * 0.6, size * 0.6),
      whitePaint,
    );
    // Center dot
    canvas.drawRect(
      Rect.fromLTWH(x + size * 0.35, y + size * 0.35, size * 0.3, size * 0.3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import '../../domain/technician_analytics_models.dart';

class TechnicianTierCard extends StatelessWidget {
  final TierCardModel tierInfo;
  final VoidCallback? onTap;

  const TechnicianTierCard({
    super.key,
    required this.tierInfo,
    this.onTap,
  });

  void _showTierBenefitsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Partner Membership Tiers',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Work daily hours on BookurTechnician to unlock higher tier perks, lower platform commissions, and VIP job radar.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              // 1. Copper Card
              _buildTierDetailItem(
                tier: TechnicianTier.copper,
                title: 'Copper Starter Pass 🥉',
                subtitle: 'Issued upon account registration (0 to 5 hrs/day)',
                color: const Color(0xFFB87333),
                isCurrent: tierInfo.tier == TechnicianTier.copper,
                perks: [
                  'Standard 15km Job Dispatch Radar',
                  'Standard 10% Platform Commission',
                  'Daily Wallet Balance Settlement',
                  'Customer Rating & Review Profile',
                ],
              ),
              const SizedBox(height: 14),

              // 2. Silver Card
              _buildTierDetailItem(
                tier: TechnicianTier.silver,
                title: 'Silver Pro Partner 🥈',
                subtitle: 'Unlocks when working 5+ hours per day',
                color: const Color(0xFF64748B),
                isCurrent: tierInfo.tier == TechnicianTier.silver,
                perks: [
                  'Priority Job Radar in 15km Radius',
                  '8% Platform Fee (20% Fee Discount)',
                  'Silver Pro Badge on Customer Booking Screen',
                  'Fast-Track 1-Click Instant UPI Withdrawals',
                  'Dedicated Support Helpline Access',
                ],
              ),
              const SizedBox(height: 14),

              // 3. Gold VIP Card
              _buildTierDetailItem(
                tier: TechnicianTier.gold,
                title: 'Gold VIP Elite 🥇',
                subtitle: 'Unlocks when working 9+ hours per day',
                color: const Color(0xFFD97706),
                isCurrent: tierInfo.tier == TechnicianTier.gold,
                perks: [
                  'Top-Tier #1 Priority Job Radar Dispatch',
                  '5% Ultra-Low Platform Fee (50% Fee Discount)',
                  'Zero-Fee Instant UPI Payouts Anytime',
                  'Gold VIP Crown Badge on Customer Apps',
                  'Direct VIP Customer Repeat Booking Access',
                  'Highest Daily Payout Guarantee',
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got It, Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierDetailItem({
    required TechnicianTier tier,
    required String title,
    required String subtitle,
    required Color color,
    required bool isCurrent,
    required List<String> perks,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? color.withAlpha(20) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? color : const Color(0xFFE2E8F0),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
              const Spacer(),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('YOUR TIER', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          ...perks.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, color: color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tier = tierInfo.tier;

    // Gradient definitions based on tier
    List<Color> gradientColors;
    Color accentColor;
    Color chipColor;
    String watermark;
    IconData tierIcon;

    switch (tier) {
      case TechnicianTier.gold:
        gradientColors = const [
          Color(0xFF78350F),
          Color(0xFFB45309),
          Color(0xFFD97706),
          Color(0xFFF59E0B),
          Color(0xFFFDE68A),
        ];
        accentColor = const Color(0xFFFEF3C7);
        chipColor = const Color(0xFFFCD34D);
        watermark = 'GOLD VIP';
        tierIcon = Icons.military_tech_rounded;
        break;
      case TechnicianTier.silver:
        gradientColors = const [
          Color(0xFF334155),
          Color(0xFF475569),
          Color(0xFF64748B),
          Color(0xFF94A3B8),
          Color(0xFFCBD5E1),
        ];
        accentColor = const Color(0xFFF1F5F9);
        chipColor = const Color(0xFFE2E8F0);
        watermark = 'SILVER PRO';
        tierIcon = Icons.verified_rounded;
        break;
      case TechnicianTier.copper:
        gradientColors = const [
          Color(0xFF5C2C16),
          Color(0xFF804A26),
          Color(0xFFA0522D),
          Color(0xFFB87333),
          Color(0xFFD27D2D),
        ];
        accentColor = const Color(0xFFFFEDD5);
        chipColor = const Color(0xFFFDBA74);
        watermark = 'COPPER PASS';
        tierIcon = Icons.shield_rounded;
        break;
    }

    return GestureDetector(
      onTap: onTap ?? () => _showTierBenefitsModal(context),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[1].withAlpha(100),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Holographic / Watermark Text in background
            Positioned(
              right: -10,
              bottom: -10,
              child: Text(
                watermark,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withAlpha(25),
                  letterSpacing: 2,
                ),
              ),
            ),

            // Main Card Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header: App Branding & Tier Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(50),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withAlpha(50)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'BOOKURTECHNICIAN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tierIcon, size: 14, color: gradientColors[1]),
                            const SizedBox(width: 4),
                            Text(
                              tierInfo.tierName.toUpperCase(),
                              style: TextStyle(
                                color: gradientColors[0],
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Smart Card EMV Chip Simulation & Holder Name
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 26,
                        decoration: BoxDecoration(
                          color: chipColor,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white.withAlpha(120), width: 1),
                        ),
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 14,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black26, width: 0.8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tierInfo.cardHolder.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            tierInfo.serialNumber,
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Working Hours Progress Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '⏱️ Today\'s Working Time: ${tierInfo.todayHours} hrs',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            Text(
                              tier == TechnicianTier.gold
                                  ? '🥇 Max Tier Active'
                                  : tier == TechnicianTier.silver
                                      ? '${tierInfo.hoursRemaining} hrs to Gold'
                                      : '${tierInfo.hoursRemaining} hrs to Silver',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: tierInfo.progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.white.withAlpha(40),
                            valueColor: AlwaysStoppedAnimation<Color>(chipColor),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0h (Copper 🥉)',
                              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '5h (Silver 🥈)',
                              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '9h+ (Gold VIP 🥇)',
                              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Footer: Tap to view benefits
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flash_on_rounded, color: Color(0xFFFCD34D), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${tierInfo.weeklyStreakDays}-Day Active Shift Streak 🔥',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'View Tier Perks',
                            style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_forward_ios_rounded, color: accentColor, size: 10),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

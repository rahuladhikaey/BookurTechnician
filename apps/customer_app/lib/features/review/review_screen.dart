import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ReviewScreen extends StatefulWidget {
  final String bookingId;
  final String technicianName;

  const ReviewScreen({
    super.key,
    required this.bookingId,
    required this.technicianName,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _selectedStars = 5;
  final TextEditingController _commentController = TextEditingController();

  final List<String> _tags = [
    '⚡ Quick Response',
    '🔧 Professional Tools',
    '🛡️ Clean Wiring',
    '🤝 Polite Behavior',
    '🎁 Transparent Pricing',
    '💡 Expert Advice',
  ];

  final Set<String> _selectedTags = {'⚡ Quick Response', '🔧 Professional Tools'};
  int _selectedTip = 50;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    switch (_selectedStars) {
      case 5:
        return 'Outstanding & Flawless! 🌟';
      case 4:
        return 'Very Good Work! 👍';
      case 3:
        return 'Average Service 😐';
      case 2:
        return 'Below Expectations 👎';
      default:
        return 'Poor Experience ⚠️';
    }
  }

  void _submitReview() {
    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showThankYouDialog();
      }
    });
  }

  void _showThankYouDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.electricGold, width: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emeraldGreen,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Thank You!',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your feedback helps ${widget.technicianName} maintain master electrician certification.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('BACK TO HOME'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianBlack,
      appBar: AppBar(
        title: const Text('RATE & REVIEW'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Technician Avatar & Name
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceLight,
                  border: Border.all(color: AppColors.electricGold, width: 2),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.pureWhite,
                  size: 42,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.technicianName,
                style: const TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Booking ID: ${widget.bookingId}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 24),

              // Star Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  final isSelected = starNum <= _selectedStars;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStars = starNum),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Icon(
                        Icons.star_rounded,
                        size: 44,
                        color: isSelected
                            ? AppColors.electricGold
                            : AppColors.surfaceLight,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Text(
                _ratingLabel,
                style: const TextStyle(
                  color: AppColors.electricGold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 28),

              // Compliments Chips Header
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'WHAT WENT WELL?',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Wrap chips
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _tags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(
                      tag,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.pureWhite
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                    backgroundColor: AppColors.cardSurface,
                    selectedColor: AppColors.surfaceElevated,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.electricGold
                          : AppColors.borderGlow,
                      width: isSelected ? 1.5 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // Tip Technician Section
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ADD A TIP FOR EXCELLENT SERVICE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [0, 30, 50, 100].map((amount) {
                  final isSelected = _selectedTip == amount;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTip = amount),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.electricGold.withValues(alpha: 0.15)
                              : AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.electricGold
                                : AppColors.borderGlow,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            amount == 0 ? 'No Tip' : '₹$amount',
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.electricGold
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // Comment Box
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'DETAILED FEEDBACK',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _commentController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.pureWhite, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Share more details about the service quality...',
                ),
              ),

              const SizedBox(height: 36),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.obsidianBlack,
                          ),
                        )
                      : const Text(
                          'SUBMIT REVIEW & RATING',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../screens/ai_assistant_sheet.dart';
import '../theme.dart';

class FloatingAssistantButton extends StatefulWidget {
  final double bottomOffset;
  const FloatingAssistantButton({super.key, this.bottomOffset = 80});

  @override
  State<FloatingAssistantButton> createState() => _FloatingAssistantButtonState();
}

class _FloatingAssistantButtonState extends State<FloatingAssistantButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatAnimController;
  late Animation<double> _floatAnim;
  bool _showFirstTimeHint = true;

  @override
  void initState() {
    super.initState();
    _floatAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _floatAnimController, curve: Curves.easeInOut),
    );

    // Auto-dismiss the first-time prompt after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showFirstTimeHint = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _floatAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Automatically lift button if keyboard is active
    final effectiveBottom = mediaQuery.viewInsets.bottom > 0
        ? mediaQuery.viewInsets.bottom + 16
        : widget.bottomOffset;

    return Positioned(
      right: 16,
      bottom: effectiveBottom,
      child: AnimatedBuilder(
        animation: _floatAnim,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnim.value),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // First time temporary hint pill
            if (_showFirstTimeHint)
              AnimatedOpacity(
                opacity: _showFirstTimeHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Need help? Ask Bookur Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _showFirstTimeHint = false),
                        child: const Icon(Icons.close, color: Colors.white70, size: 14),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── FLOATING 2D BADGE (ROYAL BLUE + BLACK) ───
            InkWell(
              onTap: () {
                setState(() => _showFirstTimeHint = false);
                AiAssistantSheet.show(context);
              },
              borderRadius: BorderRadius.circular(30),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: kBrandPrimary,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFF17357F), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x332146A8),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '💬',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bookur Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'AI Help & Policy',
                          style: TextStyle(
                            color: Color(0xFFEEF3FF),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

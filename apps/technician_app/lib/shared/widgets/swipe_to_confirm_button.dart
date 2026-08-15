import 'package:flutter/material.dart';

class SwipeToConfirmButton extends StatefulWidget {
  final String text;
  final VoidCallback onConfirm;
  final Color? trackColor;
  final Color? thumbColor;
  final Color? textColor;
  final IconData thumbIcon;
  final bool isCompleted;

  const SwipeToConfirmButton({
    super.key,
    required this.text,
    required this.onConfirm,
    this.trackColor,
    this.thumbColor,
    this.textColor,
    this.thumbIcon = Icons.arrow_forward,
    this.isCompleted = false,
  });

  @override
  State<SwipeToConfirmButton> createState() => _SwipeToConfirmButtonState();
}

class _SwipeToConfirmButtonState extends State<SwipeToConfirmButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  double _dragValue = 0.0;
  bool _isTriggered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animationController.addListener(() {
      setState(() {
        _dragValue = _slideAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SwipeToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCompleted != oldWidget.isCompleted) {
      if (!widget.isCompleted) {
        setState(() {
          _dragValue = 0.0;
          _isTriggered = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = widget.trackColor ?? theme.primaryColor.withValues(alpha: 0.15);
    final thumbColor = widget.thumbColor ?? theme.primaryColor;
    final textColor = widget.textColor ?? theme.primaryColor;

    const double buttonHeight = 60.0;
    const double padding = 4.0;
    const double thumbSize = buttonHeight - (padding * 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDragDistance = constraints.maxWidth - thumbSize - (padding * 2);

        return Container(
          width: double.infinity,
          height: buttonHeight,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(30.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Center Text hint
              Center(
                child: Opacity(
                  opacity: (1.0 - (_dragValue / maxDragDistance)).clamp(0.2, 1.0),
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.0,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // Animated Chevron indicators overlay
              Positioned(
                right: 24,
                child: Opacity(
                  opacity: (1.0 - (_dragValue / maxDragDistance)).clamp(0.0, 0.6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      2,
                      (index) => Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: textColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),

              // Active track fill color as you swipe
              Container(
                width: _dragValue + thumbSize + padding,
                height: buttonHeight,
                decoration: BoxDecoration(
                  color: thumbColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),

              // Swipe Thumb handle
              Positioned(
                left: _dragValue + padding,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isTriggered) return;
                    setState(() {
                      _dragValue = (_dragValue + details.delta.dx).clamp(0.0, maxDragDistance);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isTriggered) return;
                    if (_dragValue >= maxDragDistance * 0.92) {
                      // Lock at the end
                      setState(() {
                        _dragValue = maxDragDistance;
                        _isTriggered = true;
                      });
                      // Trigger callback
                      widget.onConfirm();
                    } else {
                      // Bounce back animation
                      _slideAnimation = Tween<double>(begin: _dragValue, end: 0.0).animate(
                        CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
                      );
                      _animationController.reset();
                      _animationController.forward();
                    }
                  },
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: thumbColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isCompleted || _isTriggered ? Icons.check : widget.thumbIcon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

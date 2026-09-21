import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/technician_analytics_models.dart';

class AnalyticsDualChart extends StatefulWidget {
  final List<ChartDataPoint> dataPoints;
  final String filterTitle;

  const AnalyticsDualChart({
    super.key,
    required this.dataPoints,
    this.filterTitle = 'Earnings & Work Hours',
  });

  @override
  State<AnalyticsDualChart> createState() => _AnalyticsDualChartState();
}

class _AnalyticsDualChartState extends State<AnalyticsDualChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.dataPoints.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const Text('No analytics data recorded for this period.', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    final maxEarnings = widget.dataPoints.map((e) => e.earnings).fold<double>(0.0, max);
    final maxHours = widget.dataPoints.map((e) => e.workHours).fold<double>(0.0, max);

    final safeMaxEarnings = maxEarnings > 0 ? maxEarnings * 1.25 : 1000.0;
    final safeMaxHours = maxHours > 0 ? maxHours * 1.3 : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart Header & Legends
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Income (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(width: 16),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Work Time (hrs)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            if (_selectedIndex != null && _selectedIndex! < widget.dataPoints.length)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.dataPoints[_selectedIndex!].label}: ₹${widget.dataPoints[_selectedIndex!].earnings.toStringAsFixed(0)} • ${widget.dataPoints[_selectedIndex!].workHours.toStringAsFixed(1)}h',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),

        const SizedBox(height: 14),

        // Custom Painted Dual Chart
        GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final width = box.size.width;
            final itemWidth = width / widget.dataPoints.length;
            final idx = (details.localPosition.dx / itemWidth).floor().clamp(0, widget.dataPoints.length - 1);
            setState(() => _selectedIndex = idx);
          },
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: _DualChartPainter(
                dataPoints: widget.dataPoints,
                maxEarnings: safeMaxEarnings,
                maxHours: safeMaxHours,
                selectedIndex: _selectedIndex,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // X-Axis Labels Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: widget.dataPoints.asMap().entries.map((entry) {
            final idx = entry.key;
            final pt = entry.value;
            final isSelected = _selectedIndex == idx;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = idx),
                child: Text(
                  pt.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DualChartPainter extends CustomPainter {
  final List<ChartDataPoint> dataPoints;
  final double maxEarnings;
  final double maxHours;
  final int? selectedIndex;

  _DualChartPainter({
    required this.dataPoints,
    required this.maxEarnings,
    required this.maxHours,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    final int count = dataPoints.length;
    final double stepX = width / count;
    final double barWidth = min(28.0, stepX * 0.45);

    // 1. Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // 2. Draw Income Bars
    for (int i = 0; i < count; i++) {
      final pt = dataPoints[i];
      final centerX = (i * stepX) + (stepX / 2);
      final isSelected = selectedIndex == i;

      final barHeight = (pt.earnings / maxEarnings) * (height - 20);
      final topY = height - barHeight;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(centerX - (barWidth / 2), topY, centerX + (barWidth / 2), height),
        const Radius.circular(6),
      );

      final barPaint = Paint()
        ..shader = LinearGradient(
          colors: isSelected
              ? const [Color(0xFF1D4ED8), Color(0xFF3B82F6)]
              : const [Color(0xFF3B82F6), Color(0xFF93C5FD)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(centerX - (barWidth / 2), topY, centerX + (barWidth / 2), height));

      canvas.drawRRect(barRect, barPaint);

      // Value label on top of bar if selected
      if (isSelected && pt.earnings > 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '₹${pt.earnings.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(centerX - (textPainter.width / 2), topY - 14));
      }
    }

    // 3. Draw Work Hours Curve & Points (Amber Line)
    final linePath = Path();
    final List<Offset> points = [];

    for (int i = 0; i < count; i++) {
      final pt = dataPoints[i];
      final centerX = (i * stepX) + (stepX / 2);
      final hoursNorm = (pt.workHours / maxHours).clamp(0.0, 1.0);
      final pointY = height - (hoursNorm * (height - 30)) - 10;

      final pos = Offset(centerX, pointY);
      points.add(pos);

      if (i == 0) {
        linePath.moveTo(pos.dx, pos.dy);
      } else {
        final prev = points[i - 1];
        final midX = (prev.dx + pos.dx) / 2;
        linePath.cubicTo(midX, prev.dy, midX, pos.dy, pos.dx, pos.dy);
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // Draw circular dots for hours
    final dotPaint = Paint()..color = const Color(0xFFF59E0B);
    final dotInnerPaint = Paint()..color = Colors.white;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isSelected = selectedIndex == i;
      canvas.drawCircle(p, isSelected ? 6 : 4, dotPaint);
      canvas.drawCircle(p, isSelected ? 3 : 2, dotInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DualChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.maxEarnings != maxEarnings ||
        oldDelegate.maxHours != maxHours;
  }
}

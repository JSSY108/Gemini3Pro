import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DivergenceWarningBanner extends StatelessWidget {
  const DivergenceWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFC107).withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Warning Stripes Background Overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _WarningStripePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFFC107),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "⚠️ Low Authority Warning: The AI is confident, but evidence relies entirely on low-tier sources or social media.",
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFFC107),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

class _WarningStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    const double stripeWidth = 20.0;
    const double spacing = 40.0;

    for (double i = -size.height; i < size.width; i += spacing) {
      final path = Path()
        ..moveTo(i, 0)
        ..lineTo(i + stripeWidth, 0)
        ..lineTo(i + stripeWidth + size.height, size.height)
        ..lineTo(i + size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReliabilityCard extends StatelessWidget {
  final double score;
  final double baseGrounding;
  final double consistencyBonus;

  const ReliabilityCard({
    super.key,
    required this.score,
    required this.baseGrounding,
    required this.consistencyBonus,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (score * 100).toInt();

    Color accentColor;
    if (score < 0.4) {
      accentColor = Colors.red;
    } else if (score < 0.7) {
      accentColor = Colors.orange;
    } else {
      accentColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined, color: accentColor, size: 16),
              const SizedBox(width: 8),
              Text(
                "EVIDENCE STRENGTH",
                style: GoogleFonts.outfit(
                  color: accentColor.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "$percentage%",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Segmented Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (baseGrounding > 0)
                    Flexible(
                      flex: (baseGrounding * 100).toInt(),
                      child: Container(color: const Color(0xFFD4AF37)),
                    ),
                  if (consistencyBonus > 0)
                    Flexible(
                      flex: (consistencyBonus * 100).toInt(),
                      child: Container(color: Colors.pinkAccent),
                    ),
                  if (1.0 - (baseGrounding + consistencyBonus) > 0)
                    Flexible(
                      flex: ((1.0 - (baseGrounding + consistencyBonus)) * 100)
                          .toInt(),
                      child: Container(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Evidence Strength",
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

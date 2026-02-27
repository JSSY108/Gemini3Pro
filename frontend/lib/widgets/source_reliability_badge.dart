import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class SourceReliabilityBadge extends StatelessWidget {
  final int sourceId;
  final bool isActive;
  final double? score;
  final double? confidence;
  final double? authority;

  const SourceReliabilityBadge({
    super.key,
    required this.sourceId,
    this.isActive = false,
    this.score,
    this.confidence,
    this.authority,
  });

  Color _getRingColor(double s) {
    if (s >= 0.85) return const Color(0xFF00FF9D); // Teal
    if (s >= 0.50) return const Color(0xFFFFB020); // Amber
    return const Color(0xFFFF453A); // Red
  }

  void _showFactualBreakdown(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFFD4AF37)),
            const SizedBox(width: 10),
            Text(
              "Factual Breakdown",
              style: GoogleFonts.outfit(
                color: const Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Contextual Reliability",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Math.tex(
                  r'Score_{seg} = \max(Conf_{i} \times Auth_{j})',
                  textStyle: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (confidence != null && authority != null && score != null) ...[
              Text(
                "• AI Confidence (Match): ${(confidence! * 100).toStringAsFixed(1)}%",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                "• Domain Authority Weight: ${(authority!).toStringAsFixed(2)}",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                "• Final Reliability: ${(score! * 100).toStringAsFixed(1)}%",
                style: GoogleFonts.outfit(
                  color: _getRingColor(score!),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              Text(
                "Metrics unavailable for this segment.",
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "CLOSE",
              style: GoogleFonts.outfit(color: const Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (sourceId > 0) {
          _showFactualBreakdown(context);
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (score != null)
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: score,
                backgroundColor: isActive
                    ? Colors.black12
                    : Colors.white.withOpacity(0.05),
                color: _getRingColor(score!),
                strokeWidth: 2.0,
              ),
            ),
          Container(
            padding: const EdgeInsets.all(6),
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sourceId > 0
                  ? (isActive
                        ? const Color(0xFFD4AF37)
                        : const Color(0xFFD4AF37).withOpacity(0.1))
                  : const Color(0xFFD4AF37).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: sourceId > 0 && score == null
                    ? const Color(0xFFD4AF37)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: sourceId > 0
                ? Text(
                    sourceId.toString(),
                    style: GoogleFonts.outfit(
                      color: isActive
                          ? Colors.black
                          : (score != null
                                ? Colors.white
                                : const Color(0xFFD4AF37)),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFD4AF37),
                    size: 14,
                  ),
          ),
        ],
      ),
    );
  }
}

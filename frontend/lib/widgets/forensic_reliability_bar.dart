import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';

class ForensicReliabilityBar extends StatelessWidget {
  final ReliabilityMetrics metrics;
  final String verdict;

  const ForensicReliabilityBar({
    super.key,
    required this.metrics,
    required this.verdict,
  });

  @override
  Widget build(BuildContext context) {
    bool isDisabled = verdict == 'NOT_A_CLAIM' || verdict == 'UNVERIFIABLE';

    if (isDisabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "FORENSIC RELIABILITY",
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              "N/A - Claim Cannot Be Scored",
              style: GoogleFonts.outfit(
                color: Colors.grey.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    final double score = metrics.reliabilityScore.clamp(0.0, 1.0);
    Color barColor;
    if (score < 0.4) {
      barColor = Colors.red;
    } else if (score < 0.7) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "FORENSIC RELIABILITY",
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Gemini Self-Reported Confidence: ${(metrics.aiConfidence * 100).toInt()}%",
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            Text(
              "${(score * 100).toInt()}%",
              style: GoogleFonts.outfit(
                color: barColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            color: barColor,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMetricItem(
              Icons.travel_explore,
              "Search Grounding",
              "${(metrics.baseGrounding * 100).toInt()}%",
            ),
            _buildMetricItem(
              Icons.rule,
              "Consistency",
              "${(metrics.consistencyBonus * 100).toInt()}%",
            ),
            if (metrics.multimodalBonus > 0)
              _buildMetricItem(
                Icons.image_search,
                "Multimodal",
                "+${(metrics.multimodalBonus * 100).toInt()}%",
                color: Colors.blueAccent,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricItem(IconData icon, String label, String value,
      {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.white70),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: color ?? Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

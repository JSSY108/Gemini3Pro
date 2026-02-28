import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_math_fork/flutter_math.dart';
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "FORENSIC RELIABILITY",
                    softWrap: true,
                    maxLines: 2,
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
          child: SizedBox(
            height: 8,
            width: double.infinity,
            child: Row(
              children: [
                if (metrics.baseGrounding > 0)
                  Flexible(
                    flex: (metrics.baseGrounding * 100).toInt(),
                    child: Container(color: const Color(0xFFD4AF37)),
                  ),
                if (metrics.consistencyBonus > 0)
                  Flexible(
                    flex: (metrics.consistencyBonus * 100).toInt(),
                    child: Container(color: Colors.pinkAccent),
                  ),
                if (metrics.multimodalBonus > 0)
                  Flexible(
                    flex: (metrics.multimodalBonus * 100).toInt(),
                    child: Container(color: Colors.blueAccent),
                  ),
                if (1.0 - score > 0)
                  Flexible(
                    flex: ((1.0 - score) * 100).toInt(),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildMetricItem(
              context: context,
              icon: Icons.travel_explore,
              label: "Base Grounding",
              value: "${(metrics.baseGrounding * 100).toInt()}%",
              dialogTitle: "✨ Base Grounding",
              dialogContent: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Represents the core factual density."),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Math.tex(
                        r'BaseScore = \frac{1}{n} \sum_{i=1}^{n} \max(Conf_i \times Auth_j)',
                        textStyle: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Segment Confidence is metadata from Grounding Support, separate from Model Certainty. Authority is a weight based on domain reputation.",
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(
                        "https://docs.cloud.google.com/vertex-ai/generative-ai/docs/reference/rest/v1beta1/GroundingMetadata#GroundingSupport",
                      ),
                    ),
                    icon: const Icon(
                      Icons.link,
                      size: 16,
                      color: Colors.lightBlueAccent,
                    ),
                    label: Text(
                      "Vertex AI Grounding Docs",
                      style: GoogleFonts.outfit(color: Colors.lightBlueAccent),
                    ),
                  ),
                ],
              ),
            ),
            _buildMetricItem(
              context: context,
              icon: Icons.rule,
              label: "Consistency Bonus",
              value: "+${(metrics.consistencyBonus * 100).toInt()}%",
              color: Colors.pinkAccent,
              dialogTitle: "🔗 Consistency Bonus",
              dialogContent: const Text(
                "A +0.05 bonus is applied when a single factual segment is supported by at least three distinct domains.\n\nGoal: Mitigate Single-Source Bias and reward broad consensus.",
              ),
            ),
            if (metrics.multimodalBonus > 0)
              _buildMetricItem(
                context: context,
                icon: Icons.image_search,
                label: "Multimodal Bonus",
                value: "+${(metrics.multimodalBonus * 100).toInt()}%",
                color: Colors.blueAccent,
                dialogTitle: "📸 Multimodal Bonus",
                dialogContent: const Text(
                  "A +0.05 bonus is applied if the textual claim is cross-referenced and confirmed by Gemini vision models analyzing user-uploaded images/videos.",
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    Color? color,
    required String dialogTitle,
    required Widget dialogContent,
  }) {
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
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.info_outline, size: 12, color: Colors.white54),
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                title: Text(
                  dialogTitle,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: DefaultTextStyle(
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  child: dialogContent,
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
          },
        ),
      ],
    );
  }
}

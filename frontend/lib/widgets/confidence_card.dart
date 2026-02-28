import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConfidenceCard extends StatelessWidget {
  final double score;
  final GlobalKey? gaugeKey;

  const ConfidenceCard({super.key, required this.score, this.gaugeKey});

  @override
  Widget build(BuildContext context) {
    final percentage = (score * 100).toInt();

    return Container(
      key: gaugeKey,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.psychology_outlined,
                color: Colors.indigoAccent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "AI REASONING CERTAINTY",
                  softWrap: true,
                  maxLines: 2,
                  style: GoogleFonts.outfit(
                    color: Colors.indigoAccent.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.white54,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      title: Text(
                        "AI Certainty",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          "Represents the model's internal statistical certainty of its generated response. High certainty indicates consistent logical patterns but does not inherently guarantee factual truth (handled by Forensic Reliability).",
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "CLOSE",
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFD4AF37),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: score,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  color: Colors.indigoAccent,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                "$percentage%",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Confidence Score",
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

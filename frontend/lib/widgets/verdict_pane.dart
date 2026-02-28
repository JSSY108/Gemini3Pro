import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';
// import 'confidence_gauge.dart'; // Removed unused import
import 'forensic_reliability_bar.dart';
import 'confidence_card.dart';
import 'verdict_card.dart';
import 'community_vote_box.dart';

class VerdictPane extends StatelessWidget {
  final AnalysisResponse? result;

  const VerdictPane({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Text(
              "Ready for Analysis",
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final unusedSources = result!.reliabilityMetrics?.unusedSources ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      // Removed LayoutBuilder to allow the SingleChildScrollView to naturally
      // size the content. This permanently fixes the "overflowing pixels" error.
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // 1. Verdict Card
            VerdictCard(verdict: result!.verdict),

            const SizedBox(height: 24),

            // 2. AI Certainty Card
            ConfidenceCard(score: result!.confidenceScore),

            const SizedBox(height: 16),

            // 3. Forensic Details (only if metrics exist)
            if (result!.reliabilityMetrics != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: ForensicReliabilityBar(
                  metrics: result!.reliabilityMetrics!,
                  verdict: result!.verdict,
                ),
              ),

            const SizedBox(height: 16),

            // Removed Key Findings section
            if (unusedSources.isNotEmpty) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "OTHER SOURCES SCANNED",
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: unusedSources.map((source) {
                      return Tooltip(
                        message: source.title,
                        textStyle: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24, width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Chip(
                          label: Text(
                            source.domain,
                            style: GoogleFonts.outfit(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Colors.transparent,
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            // ==========================================
            // 3. COMMUNITY VOTE BOX
            // ==========================================
            CommunityVoteBox(
              claimText: result?.analysis,
              aiVerdict: result?.verdict,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

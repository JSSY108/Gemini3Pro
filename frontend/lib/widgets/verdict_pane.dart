import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';
import 'confidence_gauge.dart';
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
            Icon(Icons.shield_outlined,
                size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              "Ready for Analysis",
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final bool isReal = result!.verdict == 'REAL';
    final Color accentColor =
        isReal ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      // Removed LayoutBuilder to allow the SingleChildScrollView to naturally 
      // size the content. This permanently fixes the "overflowing pixels" error.
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // 1. COMBINED VERDICT & TRUST GAUGE BOX
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.3), 
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.05),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ]
              ),
              child: Row(
                children: [
                  // --- LEFT SIDE: VERDICT ---
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "VERDICT",
                          style: GoogleFonts.outfit(
                            color: accentColor.withValues(alpha: 0.8),
                            letterSpacing: 2.0,
                            fontSize: 14, // Made label bigger
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            isReal
                                ? "REAL"
                                : (result!.verdict == "UNVERIFIED"
                                    ? "UNVERIFIED"
                                    : "FAKE"),
                            style: GoogleFonts.outfit(
                              color: accentColor,
                              fontSize: 52, // <--- MUCH BIGGER TEXT
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // --- VERTICAL DIVIDER LINE ---
                  Container(
                    height: 80,
                    width: 1,
                    color: accentColor.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                  ),

                  // --- RIGHT SIDE: TRUST GAUGE ---
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Text(
                          "TRUST SCORE",
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            letterSpacing: 1.5,
                            fontSize: 12, // Made label bigger
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Force the gauge to be 30% larger 
                        Transform.scale(
                          scale: 1.3, 
                          child: ConfidenceGauge(score: result!.confidenceScore),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==========================================
            // 2. KEY FINDINGS (DYNAMIC HEIGHT)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("KEY FINDINGS",
                      style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  
                  // Replaced ListView.builder with a mapped Column to prevent
                  // scroll-conflicts inside the SingleChildScrollView
                  ...result!.keyFindings.map((finding) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6.0),
                            child: Icon(Icons.circle,
                                size: 6, color: Color(0xFFD4AF37)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              finding,
                              style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 15, // Made readable text slightly bigger
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==========================================
            // 3. COMMUNITY VOTE BOX
            // ==========================================
            CommunityVoteBox(
              claimText: result?.analysis,
              aiVerdict: result?.verdict,
            ),
            
            const SizedBox(height: 40), // Extra padding at the bottom for scroll comfort
          ],
        ),
      ),
    );
  }
}
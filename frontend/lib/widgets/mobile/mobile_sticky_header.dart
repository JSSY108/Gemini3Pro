import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/grounding_models.dart';
import '../confidence_gauge.dart';
import '../verdict_card.dart';

class MobileStickyHeader extends StatelessWidget {
  final AnalysisResponse? result;

  const MobileStickyHeader({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return _HeaderContent(result: result);
  }
}

class MobileStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final AnalysisResponse? result;

  MobileStickyHeaderDelegate({required this.result});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Use a Stack to add a background blur effect when sticky
    return Material(
      color: Colors.black.withValues(alpha: shrinkOffset > 0 ? 0.9 : 1.0),
      child: _HeaderContent(result: result),
    );
  }

  @override
  double get maxExtent => 140.0;

  @override
  double get minExtent => 140.0;

  @override
  bool shouldRebuild(covariant MobileStickyHeaderDelegate oldDelegate) {
    return result != oldDelegate.result;
  }
}

class _HeaderContent extends StatelessWidget {
  final AnalysisResponse? result;

  const _HeaderContent({required this.result});

  @override
  Widget build(BuildContext context) {
    final bool hasResult = result != null;

    return Container(
      height: 140, // Fixed height for constraints
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Prevent horizontal pushing
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verdict Card (45%)
          Expanded(
            flex: 45,
            child: VerdictCard(
              verdict: hasResult ? result!.verdict : "---",
              isSmall: true,
            ),
          ),
          const SizedBox(width: 12),
          // Trust Score Card (55%)
          Expanded(
            flex: 55,
            child: Container(
              height: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  // Reliability
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          child: Text(
                            "RELIABILITY",
                            style: GoogleFonts.outfit(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          "${(hasResult ? (result!.reliabilityMetrics?.reliabilityScore ?? (result!.confidenceScore * 0.8)) * 100 : 0).toInt()}%",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.white10),
                  // Confidence
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          child: Text(
                            "CONFIDENCE",
                            style: GoogleFonts.outfit(
                              color: Colors.indigoAccent.withOpacity(0.8),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          "${((hasResult ? result!.confidenceScore : 0.0) * 100).toInt()}%",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

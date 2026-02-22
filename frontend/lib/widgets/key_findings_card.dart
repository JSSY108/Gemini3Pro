import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';

class KeyFindingsCard extends StatelessWidget {
  final List<String> findings;
  final List<SegmentAudit> segmentAudits;
  final Function(String query) onScrollToEvidence;

  const KeyFindingsCard({
    super.key,
    required this.findings,
    required this.segmentAudits,
    required this.onScrollToEvidence,
  });

  Color _getReliabilityColor(double score) {
    if (score >= 0.8) return const Color(0xFF4CAF50); // High
    if (score >= 0.5) return const Color(0xFFFFA000); // Medium
    return const Color(0xFFE53935); // Low
  }

  double _getMatchingScore(String finding) {
    double maxScore = 0.0;
    for (var audit in segmentAudits) {
      if (finding.contains(audit.text) || audit.text.contains(finding)) {
        if (audit.topSourceScore > maxScore) {
          maxScore = audit.topSourceScore;
        }
      }
    }
    return maxScore;
  }

  List<int> _getMatchingCitationIds(String finding) {
    Set<int> ids = {};
    for (var audit in segmentAudits) {
      if (finding.contains(audit.text) || audit.text.contains(finding)) {
        for (var source in audit.sources) {
          ids.add(source.id + 1);
        }
      }
    }
    final sortedIds = ids.toList()..sort();
    return sortedIds;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: Color(0xFFD4AF37), size: 18),
              const SizedBox(width: 10),
              Text(
                "KEY FINDINGS",
                style: GoogleFonts.outfit(
                  color: const Color(0xFFD4AF37),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...findings.map((finding) {
            final score = _getMatchingScore(finding);
            final ids = _getMatchingCitationIds(finding);
            final bracketText = ids.isNotEmpty ? ' [${ids.join(', ')}]' : '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getReliabilityColor(score),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  _getReliabilityColor(score).withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            text: finding,
                            style: GoogleFonts.outfit(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 15,
                              height: 1.5,
                            ),
                            children: [
                              if (bracketText.isNotEmpty)
                                TextSpan(
                                  text: bracketText,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFD4AF37),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  mouseCursor: SystemMouseCursors.click,
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => onScrollToEvidence(finding),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

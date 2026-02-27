import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VerdictCard extends StatelessWidget {
  final String verdict;
  final bool isSmall;

  const VerdictCard({super.key, required this.verdict, this.isSmall = false});

  Color _getVerdictColor(String v) {
    final cleanV = v.toUpperCase().trim();
    switch (cleanV) {
      case 'TRUE':
      case 'MOSTLY_TRUE':
        return Colors.teal;
      case 'MIXTURE':
        return Colors.amber;
      case 'MISLEADING':
        return Colors.orange;
      case 'MOSTLY_FALSE':
      case 'FALSE':
        return Colors.redAccent;
      case 'UNVERIFIABLE':
      case 'NOT_A_CLAIM':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getVerdictColor(verdict);
    final displayVerdict = verdict.toUpperCase().trim();

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmall ? 16 : 20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: isSmall ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  "VERDICT",
                  softWrap: true,
                  maxLines: 2,
                  style: GoogleFonts.outfit(
                    color: color.withOpacity(0.8),
                    letterSpacing: 2.0,
                    fontSize: isSmall ? 9 : 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: isSmall ? 4 : 8),
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  size: isSmall ? 10 : 14,
                  color: color.withOpacity(0.8),
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: () => _showGlossary(context),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 4 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              displayVerdict,
              style: GoogleFonts.outfit(
                color: isSmall ? Colors.white : color,
                fontSize: isSmall ? 24 : 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGlossary(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Text(
          "8-Tier Verdict Glossary",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGlossaryItem(
                  "TRUE",
                  "Fully supported by all high-authority sources.",
                  Colors.teal,
                ),
                _buildGlossaryItem(
                  "MOSTLY_TRUE",
                  "Accurate but requires minor context.",
                  Colors.teal,
                ),
                _buildGlossaryItem(
                  "MIXTURE",
                  "Significant factual truth mixed with inaccuracies.",
                  Colors.amber,
                ),
                _buildGlossaryItem(
                  "MISLEADING",
                  "Facts used out of context for a false conclusion.",
                  Colors.orange,
                ),
                _buildGlossaryItem(
                  "MOSTLY_FALSE",
                  "Contains a kernel of truth but largely inaccurate.",
                  Colors.redAccent,
                ),
                _buildGlossaryItem(
                  "FALSE",
                  "Flatly contradicted by multiple high-authority sources.",
                  Colors.redAccent,
                ),
                _buildGlossaryItem(
                  "UNVERIFIABLE",
                  "Insufficient evidence to confirm/deny.",
                  Colors.grey,
                ),
                _buildGlossaryItem(
                  "NOT_A_CLAIM",
                  "Input is not a factual claim (greeting/opinion).",
                  Colors.grey,
                ),
              ],
            ),
          ),
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

  Widget _buildGlossaryItem(String title, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            desc,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

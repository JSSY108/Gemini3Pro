import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';

class ReliabilityIndexBar extends StatefulWidget {
  final ReliabilityMetrics metrics;

  const ReliabilityIndexBar({super.key, required this.metrics});

  @override
  State<ReliabilityIndexBar> createState() => _ReliabilityIndexBarState();
}

class _ReliabilityIndexBarState extends State<ReliabilityIndexBar> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsed State: Segmented Summary Bar
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: _isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "TECHNICAL RELIABILITY INDEX",
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSegmentedBar(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "${(widget.metrics.reliabilityScore * 100).toInt()}%",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFD4AF37),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expanded State: Forensic Breakdown
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white10),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildBreakdownRow(
                    "Base Grounding",
                    widget.metrics.baseGrounding,
                    const Color(0xFFD4AF37), // Gold
                    "Derived from the average truth score across all sentences, utilizing the single highest-authority source per claim.",
                  ),
                  const SizedBox(height: 12),
                  _buildBreakdownRow(
                    "Cross-Reference Bonus",
                    widget.metrics.consistencyBonus,
                    const Color(0xFFFFC107), // Amber
                    "Triggered (+0.05) because evidence was corroborated across multiple independent domains.",
                    isBonus: true,
                  ),
                  const SizedBox(height: 12),
                  _buildBreakdownRow(
                    "Multimodal Bonus",
                    widget.metrics.multimodalBonus,
                    Colors.white70, // Metallic/White
                    "Triggered (+0.05) because uploaded visual context aligns with the web evidence.",
                    isBonus: true,
                  ),
                  const SizedBox(height: 12),
                  _buildBreakdownRow(
                    "AI Reasoning Confidence",
                    widget.metrics.aiConfidence,
                    Colors.cyanAccent,
                    "The AI model's self-reported internal confidence in the reasoning and extraction process.",
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentedBar() {
    // Ensure total flex adds up to 100 for proper visual representation
    final int baseFlex = (widget.metrics.baseGrounding * 100).toInt();
    final int crossFlex = (widget.metrics.consistencyBonus * 100).toInt();
    final int multiFlex = (widget.metrics.multimodalBonus * 100).toInt();

    // Handle the Edge Case: If total score is 0, render a solid gray container
    if (baseFlex == 0 && crossFlex == 0 && multiFlex == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    // Calculate remaining empty space
    final int emptyFlex =
        100 - (baseFlex + crossFlex + multiFlex).clamp(0, 100);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (baseFlex > 0)
              Flexible(
                flex: baseFlex,
                child: Container(color: const Color(0xFFD4AF37)),
              ),
            if (crossFlex > 0)
              Flexible(
                flex: crossFlex,
                child: Container(color: const Color(0xFFFFC107)),
              ),
            if (multiFlex > 0)
              Flexible(
                flex: multiFlex,
                child: Container(color: Colors.white70),
              ),
            if (emptyFlex > 0)
              Flexible(
                flex: emptyFlex,
                child: Container(color: Colors.white10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(
      String label, double score, Color color, String tooltipText,
      {bool isBonus = false}) {
    // For progress bar visuals: [▓▓▓▓▓▓▓▓▓▓▓▓▓░░] style representation
    final int flexScore = (score * 100).toInt();
    // Bonuses are usually small (e.g., +5%), so we scale them up visually relative to a 100% max for their row
    // Base is out of 1.0. Bonuses are typically max 0.05.
    // To make bonuses visible in a progress bar context, we'll represent them relative to their max potential.
    // Assuming max bonus is 0.05 (from standard logic).
    final int displayFlex =
        isBonus ? (score / 0.05 * 100).clamp(0, 100).toInt() : flexScore;
    final int emptyFlex = 100 - displayFlex;

    final String displayScoreText = isBonus ? "+$flexScore%" : "$flexScore%";

    return Row(
      children: [
        // Label & Tooltip
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: tooltipText,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 20),
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
                textStyle: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white38,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
        // Progress Bar
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  if (displayFlex > 0)
                    Flexible(
                      flex: displayFlex,
                      child: Container(color: color),
                    ),
                  if (emptyFlex > 0)
                    Flexible(
                      flex: emptyFlex,
                      child: Container(color: Colors.white10),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Score Text
        SizedBox(
          width: 40,
          child: Text(
            displayScoreText,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

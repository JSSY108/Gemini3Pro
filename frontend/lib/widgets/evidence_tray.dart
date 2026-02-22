import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';

class EvidenceTray extends StatelessWidget {
  final GroundingSupport support;
  final SegmentAudit? audit;

  const EvidenceTray({
    super.key,
    required this.support,
    this.audit,
  });

  @override
  Widget build(BuildContext context) {
    if (audit == null || audit!.sources.isEmpty) return const SizedBox.shrink();

    // Group sources by sourceIndex map citation IDs to a list of chunks
    final Map<int, List<SourceAudit>> groupedSources = {};
    for (var source in audit!.sources) {
      groupedSources.putIfAbsent(source.sourceIndex, () => []).add(source);
    }

    final List<Widget> chipWidgets = [];
    bool isFirst = true;
    int citationDisplayIndex = 0;

    // We iterate over grouped sources. For each group, we show chips.
    // If a group has multiple chunks, we label them [Citation.1], [Citation.2]
    // We sort the keys to maintain citation order
    final sortedKeys = groupedSources.keys.toList()..sort();

    for (var srcIndex in sortedKeys) {
      final chunks = groupedSources[srcIndex]!;
      citationDisplayIndex++; // Represents roughly the local ordinal for display

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];

        // Label logic
        // Only use the citation-style index if available, otherwise fallback.
        // We use chunk.sourceIndex + 1 as the base Citation ID.
        // If sourceIndex is -1 (unknown), we use the visual display index.
        final baseCitationId = chunk.sourceIndex != -1
            ? chunk.sourceIndex + 1
            : citationDisplayIndex;

        String label = "[$baseCitationId";
        if (chunks.length > 1) {
          label += ".${i + 1}";
        }
        label += " |";

        chipWidgets.add(_buildSourceChip(context, chunk, isFirst, label));
        isFirst = false;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.saved_search,
                  color: Color(0xFFD4AF37), size: 16),
              const SizedBox(width: 8),
              Text(
                "MICRO-AUDIT TRAY",
                style: GoogleFonts.outfit(
                  color: const Color(0xFFD4AF37),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chipWidgets,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceChip(
      BuildContext context, SourceAudit source, bool isChampion, String label) {
    final double authority = (source.domain.contains('universetoday') ||
            source.domain.contains('wtamu'))
        ? 1.0
        : 0.5; // Example logic based on current model behavior
    final double confidence = source.score / authority;

    Widget chip = Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isChampion ? 0.05 : 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isChampion ? const Color(0xFFD4AF37) : Colors.white24,
            width: isChampion ? 1.5 : 1.0),
        boxShadow: isChampion
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.language, color: Colors.white70, size: 12),
          ),
          const SizedBox(width: 6),
          Text(
            source.domain,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Container(
            height: 16,
            width: 1,
            color: Colors.white24,
          ),
          const SizedBox(width: 8),
          Tooltip(
            richMessage: TextSpan(
              style: GoogleFonts.outfit(
                  color: Colors.white, fontSize: 12, height: 1.5),
              children: [
                const TextSpan(
                    text: "Segment Score = Confidence × Authority\n",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                TextSpan(text: "Score: ${(source.score * 100).toInt()}%\n"),
                TextSpan(
                    text:
                        "${confidence.toStringAsFixed(2)} × ${authority.toStringAsFixed(1)}",
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: SizedBox(
              width: 16,
              height: 16,
              child: Stack(
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.1)),
                  ),
                  CircularProgressIndicator(
                    value: source.score,
                    strokeWidth: 2,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "]",
            style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );

    return Tooltip(
      message: source.quoteText.isNotEmpty
          ? source.quoteText
          : "No clear snippet provided.",
      textStyle:
          GoogleFonts.outfit(color: Colors.white, fontSize: 13, height: 1.4),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: chip,
    );
  }
}

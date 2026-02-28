import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';
import 'evidence_card.dart';
import 'source_tile.dart';
import '../utils/demo_manager.dart';

class EvidenceTray extends StatelessWidget {
  final List<GroundingCitation> citedSources;
  final List<ScannedSource> scannedSources;
  final List<int> activeChunkIndices;
  final List<SourceAttachment> attachments;
  final ReliabilityMetrics? reliabilityMetrics;
  final GroundingSupport? activeSupport;
  final VoidCallback onClose;
  final GlobalKey? evidenceTrayKey;

  const EvidenceTray({
    super.key,
    required this.citedSources,
    required this.scannedSources,
    required this.activeChunkIndices,
    required this.attachments,
    this.reliabilityMetrics,
    this.activeSupport,
    required this.onClose,
    this.evidenceTrayKey,
  });

  @override
  Widget build(BuildContext context) {
    // Filter scanned sources based on active chunk indices
    final displayedScanned = scannedSources.where((s) {
      if (s.isCited) return false;
      // The Tray must only render "Scanned" chips whose index exists
      // in the current segment's groundingChunkIndices array.
      if (activeChunkIndices.isNotEmpty) {
        return activeChunkIndices.contains(s.id - 1);
      }
      return false; // Show nothing if no segment active (or show all? User said "only render... whose index exists")
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (citedSources.isNotEmpty)
                    Column(
                      key: evidenceTrayKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("CITED SOURCES"),
                        ...citedSources.map((citation) {
                          double? computedScore;
                          double? sourceConfidence;
                          double? sourceAuthority;

                          if (activeSupport != null &&
                              reliabilityMetrics != null &&
                              reliabilityMetrics!.segments.isNotEmpty) {
                            try {
                              final currentSegmentText =
                                  activeSupport!.segment.text;
                              final segmentAudit = reliabilityMetrics!.segments
                                  .firstWhere(
                                      (s) => s.text == currentSegmentText);

                              final sourceAudit =
                                  segmentAudit.sources.firstWhere(
                                (s) => s.id == citation.id,
                              );

                              // Find confidence score index
                              final chunkIndexInSupport = activeSupport!
                                  .groundingChunkIndices
                                  .indexOf(citation.id - 1);

                              if (chunkIndexInSupport != -1 &&
                                  chunkIndexInSupport <
                                      activeSupport!.confidenceScores.length) {
                                sourceConfidence = activeSupport!
                                    .confidenceScores[chunkIndexInSupport];
                                sourceAuthority = sourceAudit.authority;

                                computedScore =
                                    sourceConfidence * sourceAuthority;
                              }
                            } catch (e) {
                              // Ignore if metrics missing
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: EvidenceCard(
                              title: citation.title,
                              snippet: citation.snippet,
                              url: citation.url,
                              sourceFile: citation.sourceFile,
                              attachments: attachments,
                              status: citation.status,
                              sourceId: citation.id,
                              isActive: true,
                              score: computedScore,
                              confidence: sourceConfidence,
                              authority: sourceAuthority,
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: (displayedScanned.isNotEmpty)
                        ? Column(
                            key: ValueKey(activeChunkIndices.join(',')),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              _buildSectionTitle("SEARCH CONTEXT (SCANNED)"),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: displayedScanned
                                    .map((s) => ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 200),
                                          child: SourceTile(
                                            title: s.title,
                                            url: s.url,
                                            attachments: attachments,
                                            status: 'live',
                                            sourceId: s.id,
                                            isActive: false,
                                            snippet: s.snippet,
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFFD4AF37),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                "MICRO-AUDIT TRAY",
                style: GoogleFonts.outfit(
                  color: const Color(0xFFD4AF37),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white38, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        if (title == "CITED SOURCES" && DemoManager.isDemoMode) ...[
          const SizedBox(width: 6),
          Tooltip(
            message:
                "This demo showcases verified historical snippets. Actual claims ingest real-time live data.",
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            textStyle: GoogleFonts.outfit(color: Colors.white, fontSize: 11),
            child: const Icon(
              Icons.info_outline,
              size: 14,
              color: Colors.amber,
            ),
          ),
        ],
      ],
    );
  }
}

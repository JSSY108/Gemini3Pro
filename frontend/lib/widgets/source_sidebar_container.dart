import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';
import 'source_tile.dart';

class SourceSidebarContainer extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<GroundingCitation> citations;
  final List<ScannedSource> scannedSources;
  final List<SourceAttachment> uploadedAttachments;
  final List<int> activeIndices;
  final Function(int) onCitationSelected;
  final Function(String) onDeleteAttachment;
  final ScrollController scrollController;

  const SourceSidebarContainer({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.citations,
    required this.scannedSources,
    required this.uploadedAttachments,
    this.activeIndices = const [],
    required this.onCitationSelected,
    required this.onDeleteAttachment,
    required this.scrollController,
  });

  @override
  State<SourceSidebarContainer> createState() => _SourceSidebarContainerState();
}

class _SourceSidebarContainerState extends State<SourceSidebarContainer> {
  bool _showEvidence = true;
  final Map<String, GlobalKey> _sourceKeys = {};

  @override
  void didUpdateWidget(SourceSidebarContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndices.isNotEmpty &&
        widget.activeIndices != oldWidget.activeIndices) {
      _scrollToActiveSource();
    }
  }

  void _scrollToActiveSource() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final index in widget.activeIndices) {
        // We use 'cited_' prefix for the auto-scroll target in the top section
        final key = _sourceKeys['cited_$index'];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.5,
          );
          break; // Scroll to the first active one
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
      width: widget.isExpanded ? 350 : 60,
      color: Colors.black,
      child: Column(
        children: [
          // Header / Toggle
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isExpanded ? 16 : 0,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: widget.isExpanded ? 318 : 60,
                child: Row(
                  mainAxisAlignment: widget.isExpanded
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.center,
                  children: [
                    if (widget.isExpanded) ...[_buildTabSwitcher()],
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        widget.isExpanded
                            ? Icons.keyboard_double_arrow_left
                            : Icons.keyboard_double_arrow_right,
                        color: const Color(0xFFD4AF37),
                        size: 20,
                      ),
                      onPressed: widget.onToggle,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: widget.isExpanded
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _showEvidence
                        ? _buildTieredEvidenceList()
                        : _buildUploadedList(),
                  )
                : Column(
                    children: [
                      const SizedBox(height: 20),
                      RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          "SOURCE MATERIAL",
                          style: GoogleFonts.outfit(
                            color: Colors.white24,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton("Uploaded", !_showEvidence),
          _buildTabButton("Evidence", _showEvidence),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _showEvidence = label == "Evidence"),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.black : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTieredEvidenceList() {
    // 1. Identify "Verified" (Cited) vs "Context" (Scanned but not cited)
    final List<ScannedSource> citedSources = widget.scannedSources
        .where((s) => s.isCited)
        .toList();
    final List<ScannedSource> contextSources = widget.scannedSources
        .where((s) => !s.isCited)
        .toList();

    return CustomScrollView(
      key: const ValueKey("evidence"),
      controller: widget.scrollController,
      slivers: [
        // --- SECTION 1: VERIFIED EVIDENCE ---
        if (citedSources.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified,
                    color: Color(0xFFD4AF37),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "VERIFIED EVIDENCE",
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFD4AF37),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final source = citedSources[index];
              final isActive = widget.activeIndices.contains(source.id - 1);

              // Enrich with citation info if available
              final citation = widget.citations.firstWhere(
                (c) => c.url == source.url,
                orElse: () =>
                    GroundingCitation(title: '', url: '', snippet: ''),
              );

              final String keyStr = 'cited_${source.id - 1}';
              _sourceKeys[keyStr] =
                  _sourceKeys[keyStr] ?? GlobalKey(debugLabel: keyStr);

              return Padding(
                key: ValueKey('sidebar_cited_${source.url}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: AnimatedContainer(
                  key: _sourceKeys[keyStr],
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFD4AF37)
                          : const Color(0xFFD4AF37).withValues(alpha: 0.3),
                      width: isActive ? 2.0 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFD4AF37,
                              ).withValues(alpha: 0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: SourceTile(
                    title: source.title.isNotEmpty
                        ? source.title
                        : citation.title,
                    url: source.url.isNotEmpty ? source.url : citation.url,
                    attachments: widget.uploadedAttachments,
                    status: citation.status,
                    sourceId: source.id,
                    isActive: isActive,
                    onTap: () => widget.onCitationSelected(source.id - 1),
                  ),
                ),
              );
            }, childCount: citedSources.length),
          ),
        ],

        // --- SECTION 2: SEARCH CONTEXT (SCANNED) ---
        if (contextSources.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white38, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    "SEARCH CONTEXT (SCANNED)",
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final source = contextSources[index];
              final isActive = widget.activeIndices.contains(source.id - 1);

              final String keyStr = 'scanned_${source.id - 1}';
              _sourceKeys[keyStr] =
                  _sourceKeys[keyStr] ?? GlobalKey(debugLabel: keyStr);

              return Padding(
                key: ValueKey('sidebar_scanned_${source.url}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: AnimatedContainer(
                  key: _sourceKeys[keyStr],
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.05)
                        : Colors.transparent,
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFD4AF37)
                          : Colors.white.withValues(alpha: 0.1),
                      width: isActive ? 2.0 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFD4AF37,
                              ).withValues(alpha: 0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: SourceTile(
                    title: source.title,
                    url: source.url,
                    attachments: widget.uploadedAttachments,
                    status: 'live',
                    sourceId: source.id,
                    isActive: isActive,
                    onTap: () => widget.onCitationSelected(source.id - 1),
                  ),
                ),
              );
            }, childCount: contextSources.length),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildUploadedList() {
    return ListView.builder(
      key: const ValueKey("uploaded"),
      padding: const EdgeInsets.all(16),
      itemCount: widget.uploadedAttachments.length,
      itemBuilder: (context, index) {
        final attachment = widget.uploadedAttachments[index];
        return Hero(
          tag: 'attachment_${attachment.id}',
          child: Material(
            color: Colors.transparent,
            child: SourceTile(
              title: attachment.title,
              url: attachment.url ?? "",
              attachments: widget.uploadedAttachments,
              isActive: false,
              onDelete: () => widget.onDeleteAttachment(attachment.id),
            ),
          ),
        );
      },
    );
  }
}

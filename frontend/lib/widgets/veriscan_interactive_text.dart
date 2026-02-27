import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/grounding_models.dart';
import '../utils/grounding_parser.dart';
import 'evidence_tray.dart';

class VeriscanInteractiveText extends StatefulWidget {
  final String analysisText;
  final List<GroundingSupport> groundingSupports;
  final List<GroundingCitation> groundingCitations;
  final List<ScannedSource> scannedSources;
  final List<SourceAttachment> attachments;
  final GroundingSupport? activeSupport;
  final Function(GroundingSupport?)? onSupportSelected;

  const VeriscanInteractiveText({
    super.key,
    required this.analysisText,
    required this.groundingSupports,
    required this.groundingCitations,
    required this.scannedSources,
    required this.attachments,
    this.activeSupport,
    this.onSupportSelected,
  });

  @override
  State<VeriscanInteractiveText> createState() =>
      _VeriscanInteractiveTextState();
}

class _VeriscanInteractiveTextState extends State<VeriscanInteractiveText> {
  static const double kFontSize = 15.0;
  static const double kStrutHeight = 2.0;
  static const Color kGold = Color(0xFFD4AF37);

  GroundingSupport? _hoveredSupport;

  @override
  Widget build(BuildContext context) {
    if (widget.analysisText.isEmpty) return const SizedBox();

    final chunks = GroundingParser.parse(
      widget.analysisText,
      widget.groundingSupports,
    );
    final theme = Theme.of(context);

    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: kFontSize,
          height: 1.0,
        ) ??
        const TextStyle(fontSize: kFontSize, height: 1.0);

    const strutStyle = StrutStyle(
      fontSize: kFontSize,
      height: kStrutHeight,
      forceStrutHeight: true,
      leading: 0.5,
    );

    // Identify if we need to split the text to insert a card
    int activeChunkIndex = -1;
    if (widget.activeSupport != null) {
      activeChunkIndex = chunks.indexWhere(
        (c) =>
            c.support != null &&
            c.support!.segment.startIndex ==
                widget.activeSupport!.segment.startIndex,
      );
    }

    // Always split or treat as single block to keep AnimatedSwitcher in tree for transition
    final int splitIndex =
        activeChunkIndex != -1 ? activeChunkIndex + 1 : chunks.length;
    final beforeChunks = chunks.sublist(0, splitIndex);
    final afterChunks = chunks.sublist(splitIndex);

    return RepaintBoundary(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRichTextBlock(beforeChunks, baseStyle, strutStyle),
            if (activeChunkIndex != -1)
              Padding(
                key: ValueKey(widget.activeSupport!.segment.startIndex),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: EvidenceTray(
                  citedSources: _getReferencedCitations(widget.activeSupport!),
                  scannedSources: widget.scannedSources,
                  activeChunkIndices:
                      widget.activeSupport!.groundingChunkIndices,
                  attachments: widget.attachments,
                  onClose: () => widget.onSupportSelected?.call(null),
                ),
              ),
            if (afterChunks.isNotEmpty)
              _buildRichTextBlock(afterChunks, baseStyle, strutStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildRichTextBlock(
    List<TextChunk> chunks,
    TextStyle baseStyle,
    StrutStyle strutStyle,
  ) {
    final List<InlineSpan> spans = [];
    bool isBold = false;

    for (final chunk in chunks) {
      final bool isSelected = widget.activeSupport != null &&
          chunk.support != null &&
          chunk.support!.segment.startIndex ==
              widget.activeSupport!.segment.startIndex;

      final isHovered = _hoveredSupport == chunk.support;
      final bool shouldUnderline = isSelected || isHovered;

      final Color decorationColor = isSelected
          ? kGold
          : (isHovered ? kGold.withValues(alpha: 0.4) : Colors.transparent);

      final double decorationThickness = isSelected ? 3.0 : 1.0;
      final double lineHeight = isSelected ? 1.8 : 1.0;

      final String text = chunk.text;
      final boldRegex = RegExp(r'\*\*');
      int currentIndex = 0;

      for (final match in boldRegex.allMatches(text)) {
        if (match.start > currentIndex) {
          spans.add(
            _createTextSpan(
              text.substring(currentIndex, match.start),
              baseStyle.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
              chunk.type,
              shouldUnderline,
              decorationColor,
              decorationThickness,
              lineHeight,
              chunk.support,
            ),
          );
        }
        // Toggle bold state when we hit **
        isBold = !isBold;
        currentIndex = match.end;
      }

      if (currentIndex < text.length) {
        spans.add(
          _createTextSpan(
            text.substring(currentIndex),
            baseStyle.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            chunk.type,
            shouldUnderline,
            decorationColor,
            decorationThickness,
            lineHeight,
            chunk.support,
          ),
        );
      }

      // Add citations icon at the end of support chunks
      if (chunk.type == ChunkType.support && chunk.support != null) {
        final indices = chunk.support!.groundingChunkIndices;
        if (indices.isNotEmpty) {
          final formattedCitations =
              '[${indices.map((i) => i + 1).join(', ')}]';
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Padding(
                padding: const EdgeInsets.only(left: 2.0, top: 2.0),
                child: GestureDetector(
                  onTap: () {
                    widget.onSupportSelected?.call(chunk.support);
                  },
                  child: Text(
                    formattedCitations,
                    style: baseStyle.copyWith(
                      fontSize: kFontSize * 0.7,
                      height: 1.0,
                      color: decorationColor == Colors.transparent
                          ? kGold.withValues(alpha: 0.7)
                          : kGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return RichText(
      strutStyle: strutStyle,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  TextSpan _createTextSpan(
    String text,
    TextStyle style,
    ChunkType type,
    bool shouldUnderline,
    Color decorationColor,
    double decorationThickness,
    double lineHeight,
    GroundingSupport? support,
  ) {
    if (type == ChunkType.plain) {
      return TextSpan(text: text, style: style);
    }

    return TextSpan(
      text: text,
      style: style.copyWith(
        height: lineHeight,
        decoration:
            shouldUnderline ? TextDecoration.underline : TextDecoration.none,
        decorationColor: decorationColor,
        decorationThickness: decorationThickness,
        decorationStyle: TextDecorationStyle.solid,
      ),
      mouseCursor: SystemMouseCursors.click,
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          if (support != null) {
            widget.onSupportSelected?.call(support);
          }
        },
      onEnter: (_) => setState(() => _hoveredSupport = support),
      onExit: (_) => setState(() => _hoveredSupport = null),
    );
  }

  List<GroundingCitation> _getReferencedCitations(GroundingSupport support) {
    final List<GroundingCitation> matchedCitations = [];
    final indices = support.groundingChunkIndices;

    for (final index in indices) {
      // 1. Resolve the ScannedSource by index
      final source = widget.scannedSources.firstWhere(
        (s) => s.index == index,
        orElse: () =>
            ScannedSource(index: -1, title: '', url: '', isCited: false),
      );

      if (source.index == -1 || source.url.isEmpty) continue;

      // 2. Search groundingCitations for an entry with the same URL
      // We normalize simple matching or just direct URL match as per backend logic
      final citation = widget.groundingCitations.firstWhere(
        (c) => c.url == source.url,
        orElse: () => GroundingCitation(title: '', url: '', snippet: ''),
      );

      if (citation.url.isNotEmpty) {
        matchedCitations.add(citation);
      }
    }

    return matchedCitations;
  }
}

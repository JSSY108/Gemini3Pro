import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';

class VeriscanInteractiveText extends StatefulWidget {
  final String analysisText;
  final List<GroundingSupport> groundingSupports;
  final List<GroundingCitation> groundingCitations;
  final List<SourceAttachment> attachments;
  final GroundingSupport? activeSupport;
  final Function(GroundingSupport?) onSupportSelected;

  const VeriscanInteractiveText({
    super.key,
    required this.analysisText,
    required this.groundingSupports,
    required this.groundingCitations,
    required this.attachments,
    required this.activeSupport,
    required this.onSupportSelected,
  });

  @override
  State<VeriscanInteractiveText> createState() =>
      _VeriscanInteractiveTextState();
}

class _VeriscanInteractiveTextState extends State<VeriscanInteractiveText> {
  final List<TapGestureRecognizer> _recognizers = [];
  
  // Tracks whether to show sources when the whole text is clicked
  bool _showFallbackSources = false; 

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _buildSpans() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    List<InlineSpan> spans = [];
    String text = widget.analysisText;
    int currentIndex = 0;

    final defaultStyle = GoogleFonts.outfit(
      color: const Color(0xFFE0E0E0),
      fontSize: 16,
      height: 1.8,
    );
    
    final activeLinkStyle = defaultStyle.copyWith(
      color: const Color(0xFFD4AF37),
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
    );

    // Style for when the whole paragraph is clicked
    final activeFallbackStyle = defaultStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFFD4AF37),
      decorationThickness: 1.5,
    );

    // Only try to build specific blue links if Gemini provided exact coordinates
    if (widget.groundingSupports.isNotEmpty) {
      final sortedSupports = List<GroundingSupport>.from(widget.groundingSupports)
        ..sort((a, b) => a.segment.startIndex.compareTo(b.segment.startIndex));

      for (var support in sortedSupports) {
        int start = support.segment.startIndex.clamp(0, text.length);
        int end = support.segment.endIndex.clamp(0, text.length);

        if (start < currentIndex) start = currentIndex;
        if (end <= start) continue; 

        if (start > currentIndex) {
          spans.add(TextSpan(text: text.substring(currentIndex, start), style: defaultStyle));
        }

        final isSelected = widget.activeSupport == support;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onSupportSelected(isSelected ? null : support);
        _recognizers.add(recognizer);

        spans.add(TextSpan(
          text: text.substring(start, end),
          style: isSelected ? activeLinkStyle : defaultStyle.copyWith(
            color: const Color(0xFF64B5F6),
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF64B5F6).withOpacity(0.5),
          ),
          recognizer: recognizer,
        ));

        currentIndex = end;
      }
    } 

    // Add any remaining text (or the entire text if no coordinates were provided)
    if (currentIndex < text.length) {
      // Determine if the fallback text should be underlined right now
      TextStyle styleToUse = defaultStyle;
      if (widget.groundingSupports.isEmpty && _showFallbackSources) {
        styleToUse = activeFallbackStyle;
      }

      spans.add(TextSpan(text: text.substring(currentIndex), style: styleToUse));
    }

    return spans;
  }

  Widget _buildCitationDropBox() {
    List<GroundingCitation> citationsToDisplay = [];

    // Figure out which citations to show based on what was clicked
    if (widget.activeSupport != null) {
      final indices = widget.activeSupport!.groundingChunkIndices;
      citationsToDisplay = indices
          .where((i) => i < widget.groundingCitations.length)
          .map((i) => widget.groundingCitations[i])
          .toList();
    } else if (widget.groundingSupports.isEmpty && _showFallbackSources) {
      citationsToDisplay = widget.groundingCitations;
    }

    if (citationsToDisplay.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: citationsToDisplay.map((citation) {
          final title = citation.title.isNotEmpty ? citation.title : "External Source";
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.link, color: Color(0xFFD4AF37), size: 16),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.open_in_new, color: const Color(0xFFD4AF37).withOpacity(0.5), size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget textContent = RichText(
      text: TextSpan(children: _buildSpans()),
    );

    // If Vertex AI didn't provide specific blue links, make the ENTIRE text clickable
    if (widget.groundingSupports.isEmpty && widget.groundingCitations.isNotEmpty) {
      textContent = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _showFallbackSources = !_showFallbackSources;
            });
          },
          child: textContent,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        textContent,
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
          child: _buildCitationDropBox(),
        ),
      ],
    );
  }
}
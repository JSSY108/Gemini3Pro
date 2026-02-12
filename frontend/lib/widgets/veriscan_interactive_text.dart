import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/grounding_models.dart';
import '../utils/grounding_parser.dart';
import 'citation_popup.dart';

class VeriscanInteractiveText extends StatefulWidget {
  final String analysisText;
  final List<GroundingSupport> groundingSupports;
  final List<GroundingCitation> groundingCitations;

  const VeriscanInteractiveText({
    super.key,
    required this.analysisText,
    required this.groundingSupports,
    required this.groundingCitations,
  });

  @override
  State<VeriscanInteractiveText> createState() =>
      _VeriscanInteractiveTextState();
}

class _VeriscanInteractiveTextState extends State<VeriscanInteractiveText> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  // Track currently active support to show correct data
  GroundingSupport? _activeSupport;

  void _showPopup(GroundingSupport support) {
    setState(() {
      _activeSupport = support;
    });
    _overlayController.show();
  }

  void _hidePopup() {
    _overlayController.hide();
    setState(() {
      _activeSupport = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.analysisText.isEmpty) return const SizedBox();

    final chunks =
        GroundingParser.parse(widget.analysisText, widget.groundingSupports);
    final theme = Theme.of(context);

    // Base style for the text
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
          fontSize: 15,
        ) ??
        const TextStyle(fontSize: 15, height: 1.5);

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          if (_activeSupport == null) return const SizedBox();

          return Positioned(
            width: 300,
            child: CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment
                  .bottomLeft, // Show below the text block (simplified)
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 10), // slight padding
              child: TapRegion(
                onTapOutside: (_) => _hidePopup(),
                child: CitationPopup(
                  citations: _getReferencedCitations(_activeSupport!),
                  onClose: _hidePopup,
                ),
              ),
            ),
          );
        },
        child: RichText(
          text: TextSpan(
            style: baseStyle,
            children: chunks.map((chunk) {
              if (chunk.type == ChunkType.plain) {
                return TextSpan(text: chunk.text);
              } else {
                final isSelected = _activeSupport == chunk.support;

                return TextSpan(
                  text: chunk.text,
                  style: baseStyle.copyWith(
                    backgroundColor: isSelected
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.3)
                        : const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dashed,
                    decorationColor:
                        const Color(0xFFD4AF37).withValues(alpha: 0.8),
                    decorationThickness:
                        2.0, // Thicker underline for visibility
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      if (chunk.support != null) {
                        _showPopup(chunk.support!);
                      }
                    },
                );
              }
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<GroundingCitation> _getReferencedCitations(GroundingSupport support) {
    final indices = support.groundingChunkIndices;
    return indices
        .where((idx) => idx >= 0 && idx < widget.groundingCitations.length)
        .map((idx) => widget.groundingCitations[idx])
        .toList();
  }
}

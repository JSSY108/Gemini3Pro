import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/grounding_models.dart';
import '../source_tile.dart';

class MobileSourceLibrary extends StatefulWidget {
  final List<GroundingCitation> citations;
  final List<SourceAttachment> uploadedAttachments;
  final Function(int) onCitationSelected;
  final Function(String) onDeleteAttachment;

  const MobileSourceLibrary({
    super.key,
    required this.citations,
    required this.uploadedAttachments,
    required this.onCitationSelected,
    required this.onDeleteAttachment,
  });

  @override
  State<MobileSourceLibrary> createState() => _MobileSourceLibraryState();
}

class _MobileSourceLibraryState extends State<MobileSourceLibrary> {
  bool _showEvidence = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Segmented Control
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                _buildToggleItem("Evidence", _showEvidence),
                _buildToggleItem("Uploaded", !_showEvidence),
              ],
            ),
          ),
        ),
        // Active List
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showEvidence ? _buildEvidenceList() : _buildUploadedList(),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleItem(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showEvidence = label == "Evidence"),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.black : Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEvidenceList() {
    if (widget.citations.isEmpty) {
      return Center(
        child: Text(
          "No grounding evidence found.",
          style: GoogleFonts.outfit(color: Colors.white24, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey("evidence_list"),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.citations.length,
      itemBuilder: (context, index) {
        final citation = widget.citations[index];
        return SourceTile(
          title: citation.title,
          url: citation.url,
          onTap: () => widget.onCitationSelected(index),
        );
      },
    );
  }

  Widget _buildUploadedList() {
    if (widget.uploadedAttachments.isEmpty) {
      return Center(
        child: Text(
          "No files uploaded.",
          style: GoogleFonts.outfit(color: Colors.white24, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey("uploaded_list"),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.uploadedAttachments.length,
      itemBuilder: (context, index) {
        final attachment = widget.uploadedAttachments[index];
        return SourceTile(
          title: attachment.title,
          url: attachment.url ?? "",
          onDelete: () => widget.onDeleteAttachment(attachment.id),
        );
      },
    );
  }
}

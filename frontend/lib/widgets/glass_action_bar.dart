import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../models/grounding_models.dart';

class GlassActionBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onAnalyze;
  final List<SourceAttachment> attachments;
  final Map<String, GlobalKey> chipKeys;
  final Function(SourceAttachment) onAddAttachment;
  final Function(String) onRemoveAttachment;
  final bool isLoading;

  const GlassActionBar({
    super.key,
    required this.controller,
    required this.onAnalyze,
    required this.attachments,
    required this.chipKeys,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
    required this.isLoading,
  });

  @override
  State<GlassActionBar> createState() => _GlassActionBarState();
}

class _GlassActionBarState extends State<GlassActionBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_urlDetector);
  }

  void _urlDetector() {
    final text = widget.controller.text;
    final urlRegex = RegExp(
        r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})');
    final matches = urlRegex.allMatches(text);
    if (matches.isNotEmpty) {
      for (final match in matches) {
        final url = match.group(0)!;
        // Check if already added
        if (!widget.attachments.any((a) => a.url == url)) {
          widget.onAddAttachment(SourceAttachment(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: url.split('/').last.isEmpty ? url : url.split('/').last,
            type: AttachmentType.link,
            url: url,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.attachments.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final attachment = widget.attachments[index];
                    final chipKey =
                        widget.chipKeys[attachment.id] ?? GlobalKey();
                    // Ensure the key is stored if not already
                    if (!widget.chipKeys.containsKey(attachment.id)) {
                      widget.chipKeys[attachment.id] = chipKey;
                    }
                    return _AttachmentChip(
                      key: chipKey,
                      attachment: attachment,
                      onRemove: () => widget.onRemoveAttachment(attachment.id),
                    );
                  },
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PickerButton(onAdd: widget.onAddAttachment),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  maxLines: 4,
                  minLines: 1,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Enter claim, question, or URL for analysis...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: widget.isLoading ? null : widget.onAnalyze,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2),
                      )
                    : Text(
                        'ANALYZE',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final Function(SourceAttachment) onAdd;
  const _PickerButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, -150),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
        ),
        child: const Icon(Icons.add, color: Color(0xFFD4AF37), size: 20),
      ),
      onSelected: (value) async {
        if (value == 'image') {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            withData: true,
          );
          if (result != null) {
            onAdd(SourceAttachment(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: result.files.first.name,
              type: AttachmentType.image,
              file: result.files.first,
            ));
          }
        } else if (value == 'pdf') {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            withData: true,
          );
          if (result != null) {
            onAdd(SourceAttachment(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: result.files.first.name,
              type: AttachmentType.pdf,
              file: result.files.first,
            ));
          }
        } else if (value == 'link') {
          // In a real app, show a dialog. For now, rely on auto-detector.
        }
      },
      itemBuilder: (context) => [
        _buildMenuItem('Capture Image', Icons.camera_alt, 'image'),
        _buildMenuItem('Upload PDF', Icons.picture_as_pdf, 'pdf'),
        _buildMenuItem('Add Link', Icons.link, 'link'),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(
      String text, IconData icon, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 20),
          const SizedBox(width: 12),
          Text(text,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final SourceAttachment attachment;
  final VoidCallback onRemove;

  const _AttachmentChip(
      {super.key, required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (attachment.type) {
      case AttachmentType.image:
        icon = Icons.image;
        break;
      case AttachmentType.pdf:
        icon = Icons.description;
        break;
      case AttachmentType.link:
        icon = Icons.link;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              attachment.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: Colors.white38, size: 14),
          ),
        ],
      ),
    );
  }
}

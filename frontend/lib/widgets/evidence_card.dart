import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class EvidenceCard extends StatefulWidget {
  final String title;
  final String snippet;
  final String url;
  final bool isActive;
  final VoidCallback? onDelete;

  const EvidenceCard({
    super.key,
    required this.title,
    required this.snippet,
    required this.url,
    this.isActive = false,
    this.onDelete,
  });

  @override
  State<EvidenceCard> createState() => _EvidenceCardState();
}

class _EvidenceCardState extends State<EvidenceCard> {
  bool _isExpanded = false;

  Future<void> _launchUrl() async {
    if (widget.url.isEmpty) return;
    final Uri uri = Uri.parse(widget.url);
    if (!await launchUrl(uri)) {
      debugPrint('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isActive
              ? const Color(0xFFD4AF37)
              : const Color(0xFFD4AF37).withValues(alpha: 0.2),
          width: widget.isActive ? 1.0 : 0.5,
        ),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37)
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome,
                                color: Color(0xFFD4AF37), size: 14),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFD4AF37),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.onDelete != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Color(0xFFD4AF37), size: 18),
                              onPressed: widget.onDelete,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "VISIT SOURCE",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white24,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: "Open Source in Browser",
                                  icon: const Icon(Icons.open_in_new,
                                      color: Colors.white54, size: 14),
                                  onPressed: _launchUrl,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.snippet,
                              maxLines: _isExpanded ? null : 3,
                              overflow:
                                  _isExpanded ? null : TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                height: 1.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _isExpanded ? "SHOW LESS" : "READ FULL TEXT",
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFD4AF37),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: _isExpanded ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(
                                    Icons.expand_more,
                                    color: Color(0xFFD4AF37),
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

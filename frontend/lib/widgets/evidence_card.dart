import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class EvidenceCard extends StatelessWidget {
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

  Future<void> _launchUrl() async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      debugPrint('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCollapsed = constraints.maxWidth < 80;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? const Color(0xFFD4AF37) : Colors.white10,
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _launchUrl,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity:
                        constraints.maxWidth < 120 && !isCollapsed ? 0.0 : 1.0,
                    child: SizedBox(
                      width: isCollapsed
                          ? 36
                          : 280, // Reduced from 300 to fit inside card padding
                      child: isCollapsed
                          ? Center(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37)
                                      .withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.link,
                                    color: Color(0xFFD4AF37), size: 14),
                              ),
                            )
                          : Row(
                              children: [
                                // Icon
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37)
                                        .withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.link,
                                      color: Color(0xFFD4AF37), size: 18),
                                ),
                                const SizedBox(width: 12),
                                // Text Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        snippet,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Action Buttons
                                if (onDelete != null)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Color(0xFFD4AF37), size: 18),
                                    onPressed: onDelete,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                else
                                  const Icon(Icons.arrow_forward_ios,
                                      color: Colors.white24, size: 14),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

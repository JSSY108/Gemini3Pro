import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class SourceTile extends StatelessWidget {
  final String title;
  final String url;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const SourceTile({
    super.key,
    required this.title,
    required this.url,
    this.isActive = false,
    this.onTap,
    this.onDelete,
  });

  Future<void> _launchUrl() async {
    if (url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      debugPrint('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFFD4AF37) : Colors.white10,
          width: isActive ? 1.0 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? _launchUrl,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Favicon Placeholder
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link,
                      color: Color(0xFFD4AF37), size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Color(0xFFD4AF37), size: 16),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.open_in_new,
                        color: Colors.white24, size: 14),
                    onPressed: _launchUrl,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

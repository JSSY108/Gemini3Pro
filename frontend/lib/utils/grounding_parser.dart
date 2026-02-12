import '../models/grounding_models.dart';

enum ChunkType { plain, support }

class TextChunk {
  final String text;
  final ChunkType type;
  final GroundingSupport? support;

  TextChunk({
    required this.text,
    required this.type,
    this.support,
  });
}

class GroundingParser {
  /// Parses the [text] using [supports] to create a list of interactive [TextChunk]s.
  /// Handles overlapping or out-of-order supports by sorting and simple iteration.
  static List<TextChunk> parse(String text, List<GroundingSupport> supports) {
    if (text.isEmpty) return [];
    if (supports.isEmpty) {
      return [TextChunk(text: text, type: ChunkType.plain)];
    }

    // 1. Sort supports by start index
    // We create a copy to avoid mutating the original list
    final sortedSupports = List<GroundingSupport>.from(supports)
      ..sort((a, b) => a.segment.startIndex.compareTo(b.segment.startIndex));

    final List<TextChunk> chunks = [];
    int currentIndex = 0;

    // DEBUG: Check text length and support count
    // print('PARSER DEBUG: Text Length: ${text.length}');
    // print('PARSER DEBUG: Supports Count: ${sortedSupports.length}');

    for (var support in sortedSupports) {
      final start = support.segment.startIndex;
      final end = support.segment.endIndex;

      // DEBUG: Check specific support indices
      // print('PARSER DEBUG: Support Segment: $start - $end');

      // Safety check: ignore out-of-bounds segments (should fit within text)
      // Note: text.length is UTF-16 code units in Dart, so indices should align
      // with what backend calculated if it used UTF-16 length logic.
      if (start < currentIndex || start >= text.length) {
        // print('PARSER DEBUG: Valid range for start: $currentIndex to ${text.length}');
        // print('PARSER DEBUG: Skipping out-of-bounds or overlapping segment: $start');
        continue;
      }

      // Clamp end to text length
      final safeEnd = end > text.length ? text.length : end;
      // if (safeEnd != end) print('PARSER DEBUG: Clamped end from $end to $safeEnd');

      // 2. Add plain text before this segment
      if (start > currentIndex) {
        chunks.add(TextChunk(
          text: text.substring(currentIndex, start),
          type: ChunkType.plain,
        ));
      }

      // 3. Add the support segment
      chunks.add(TextChunk(
        text: text.substring(start, safeEnd),
        type: ChunkType.support,
        support: support,
      ));

      currentIndex = safeEnd;
    }

    // 4. Add remaining plain text
    if (currentIndex < text.length) {
      chunks.add(TextChunk(
        text: text.substring(currentIndex),
        type: ChunkType.plain,
      ));
    }

    return chunks;
  }
}

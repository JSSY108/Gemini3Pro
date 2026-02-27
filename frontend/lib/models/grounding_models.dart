class Segment {
  final int startIndex;
  final int endIndex;
  final String text;

  Segment({
    required this.startIndex,
    required this.endIndex,
    required this.text,
  });

  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
      startIndex: json['startIndex'] as int,
      endIndex: json['endIndex'] as int,
      text: json['text'] as String,
    );
  }
}

class GroundingSupport {
  final Segment segment;
  final List<int> groundingChunkIndices;
  final List<double> confidenceScores;

  GroundingSupport({
    required this.segment,
    required this.groundingChunkIndices,
    required this.confidenceScores,
  });

  factory GroundingSupport.fromJson(Map<String, dynamic> json) {
    return GroundingSupport(
      segment: Segment.fromJson(json['segment']),
      groundingChunkIndices: List<int>.from(
        json['groundingChunkIndices'] ?? [],
      ),
      confidenceScores: List<double>.from(
        (json['confidenceScores'] ?? []).map((x) => x.toDouble()),
      ),
    );
  }
}

class ScannedSource {
  final int id;
  final String title;
  final String url;
  final bool isCited;

  ScannedSource({
    required this.id,
    required this.title,
    required this.url,
    required this.isCited,
  });

  factory ScannedSource.fromJson(Map<String, dynamic> json) {
    return ScannedSource(
      id: (json['id'] ?? json['index']) as int? ?? -1,
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      isCited: json['is_cited'] ?? false,
    );
  }
}

class GroundingCitation {
  final int id;
  final String title;
  final String url;
  final String snippet;
  final String? sourceFile;
  final String status;

  GroundingCitation({
    this.id = 0,
    required this.title,
    required this.url,
    required this.snippet,
    this.sourceFile,
    this.status = 'live',
  });

  factory GroundingCitation.fromJson(Map<String, dynamic> json) {
    return GroundingCitation(
      id: json['id'] as int? ?? 0,
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      snippet: json['snippet'] ?? '',
      sourceFile: json['source_file'],
      status: json['status'] ?? 'live',
    );
  }
}

enum AttachmentType { image, pdf, link }

class SourceAttachment {
  final String id;
  final String title;
  final AttachmentType type;
  final String? url;
  final dynamic file; // PlatformFile or cross_file XFile

  SourceAttachment({
    required this.id,
    required this.title,
    required this.type,
    this.url,
    this.file,
  });
}

class SourceAudit {
  final int id;
  final int sourceIndex;
  final int chunkIndex;
  final String domain;
  final double score;
  final String quoteText;
  final double confidence;
  final double authority;

  SourceAudit({
    required this.id,
    required this.sourceIndex,
    required this.chunkIndex,
    required this.domain,
    required this.score,
    required this.quoteText,
    required this.confidence,
    required this.authority,
  });

  factory SourceAudit.fromJson(Map<String, dynamic> json) {
    return SourceAudit(
      id: json['id'] as int,
      sourceIndex: json['source_index'] as int? ?? -1,
      chunkIndex: json['chunk_index'] as int? ?? json['id'] as int,
      domain: json['domain'] as String,
      score: (json['score'] as num).toDouble(),
      quoteText: json['quote_text'] as String? ?? json['text'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      authority: (json['authority'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SegmentAudit {
  final String text;
  final String topSourceDomain;
  final double topSourceScore;
  final List<SourceAudit> sources;

  SegmentAudit({
    required this.text,
    required this.topSourceDomain,
    required this.topSourceScore,
    required this.sources,
  });

  factory SegmentAudit.fromJson(Map<String, dynamic> json) {
    return SegmentAudit(
      text: json['text'] as String,
      topSourceDomain: json['top_source_domain'] as String,
      topSourceScore: (json['top_source_score'] as num).toDouble(),
      sources:
          (json['sources'] as List<dynamic>?)
              ?.map((e) => SourceAudit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class UnusedSourceAudit {
  final String domain;
  final String title;

  UnusedSourceAudit({required this.domain, required this.title});

  factory UnusedSourceAudit.fromJson(Map<String, dynamic> json) {
    return UnusedSourceAudit(
      domain: json['domain'] as String? ?? 'unknown',
      title: json['title'] as String? ?? 'Unknown Title',
    );
  }
}

class ReliabilityMetrics {
  final double reliabilityScore;
  final double aiConfidence;
  final double baseGrounding;
  final double consistencyBonus;
  final double multimodalBonus;
  final String verdictLabel;
  final String explanation;
  final List<SegmentAudit> segments;
  final List<UnusedSourceAudit> unusedSources;

  ReliabilityMetrics({
    required this.reliabilityScore,
    required this.aiConfidence,
    required this.baseGrounding,
    required this.consistencyBonus,
    required this.multimodalBonus,
    required this.verdictLabel,
    required this.explanation,
    required this.segments,
    required this.unusedSources,
  });

  factory ReliabilityMetrics.fromJson(Map<String, dynamic> json) {
    return ReliabilityMetrics(
      reliabilityScore: (json['reliability_score'] as num?)?.toDouble() ?? 0.0,
      aiConfidence: (json['ai_confidence'] as num?)?.toDouble() ?? 0.0,
      baseGrounding: (json['base_grounding'] as num?)?.toDouble() ?? 0.0,
      consistencyBonus: (json['consistency_bonus'] as num?)?.toDouble() ?? 0.0,
      multimodalBonus: (json['multimodal_bonus'] as num?)?.toDouble() ?? 0.0,
      verdictLabel: json['verdict_label'] as String? ?? 'Unknown',
      explanation: json['explanation'] as String? ?? '',
      segments:
          (json['segments'] as List<dynamic>?)
              ?.map((e) => SegmentAudit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      unusedSources:
          (json['unused_sources'] as List<dynamic>?)
              ?.map(
                (e) => UnusedSourceAudit.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

class AnalysisResponse {
  final String verdict;
  final double confidenceScore;
  final String analysis;
  final List<GroundingCitation> groundingCitations;
  final List<ScannedSource> scannedSources;
  final List<GroundingSupport> groundingSupports;
  final ReliabilityMetrics? reliabilityMetrics;

  AnalysisResponse({
    required this.verdict,
    required this.confidenceScore,
    required this.analysis,
    required this.groundingCitations,
    this.scannedSources = const [],
    required this.groundingSupports,
    this.reliabilityMetrics,
  });

  factory AnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AnalysisResponse(
      verdict: json['verdict'] ?? 'UNVERIFIED',
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      analysis: json['analysis'] ?? '',
      groundingCitations:
          (json['grounding_citations'] as List<dynamic>?)
              ?.map((e) => GroundingCitation.fromJson(e))
              .toList() ??
          [],
      scannedSources:
          (json['scanned_sources'] as List<dynamic>?)
              ?.map((e) => ScannedSource.fromJson(e))
              .toList() ??
          [],
      groundingSupports:
          (json['grounding_supports'] as List<dynamic>?)
              ?.map((e) => GroundingSupport.fromJson(e))
              .toList() ??
          [],
      reliabilityMetrics: json['reliability_metrics'] != null
          ? ReliabilityMetrics.fromJson(json['reliability_metrics'])
          : null,
    );
  }
}

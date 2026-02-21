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
      groundingChunkIndices:
          List<int>.from(json['groundingChunkIndices'] ?? []),
      confidenceScores: List<double>.from(
          (json['confidenceScores'] ?? []).map((x) => x.toDouble())),
    );
  }
}

class GroundingCitation {
  final String title;
  final String url;
  final String snippet;
  final String? sourceFile;
  final String status;

  GroundingCitation({
    required this.title,
    required this.url,
    required this.snippet,
    this.sourceFile,
    this.status = 'live',
  });

  factory GroundingCitation.fromJson(Map<String, dynamic> json) {
    return GroundingCitation(
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

class SegmentAudit {
  final String text;
  final String topSourceDomain;
  final double topSourceScore;

  SegmentAudit({
    required this.text,
    required this.topSourceDomain,
    required this.topSourceScore,
  });

  factory SegmentAudit.fromJson(Map<String, dynamic> json) {
    return SegmentAudit(
      text: json['text'] as String,
      topSourceDomain: json['top_source_domain'] as String,
      topSourceScore: (json['top_source_score'] as num).toDouble(),
    );
  }
}

class ReliabilityMetrics {
  final double score;
  final double baseGrounding;
  final double consistencyBonus;
  final double multimodalBonus;
  final String verdictLabel;
  final String explanation;
  final List<SegmentAudit> segments;

  ReliabilityMetrics({
    required this.score,
    required this.baseGrounding,
    required this.consistencyBonus,
    required this.multimodalBonus,
    required this.verdictLabel,
    required this.explanation,
    required this.segments,
  });

  factory ReliabilityMetrics.fromJson(Map<String, dynamic> json) {
    return ReliabilityMetrics(
      score: (json['score'] as num).toDouble(),
      baseGrounding: (json['base_grounding'] as num).toDouble(),
      consistencyBonus: (json['consistency_bonus'] as num).toDouble(),
      multimodalBonus: (json['multimodal_bonus'] as num).toDouble(),
      verdictLabel: json['verdict_label'] as String,
      explanation: json['explanation'] as String,
      segments: (json['segments'] as List<dynamic>?)
              ?.map((e) => SegmentAudit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class AnalysisResponse {
  final String verdict;
  final double confidenceScore;
  final String analysis;
  final List<String> keyFindings;
  final List<GroundingCitation> groundingCitations;
  final List<GroundingSupport> groundingSupports;
  final ReliabilityMetrics? reliabilityMetrics;

  AnalysisResponse({
    required this.verdict,
    required this.confidenceScore,
    required this.analysis,
    required this.keyFindings,
    required this.groundingCitations,
    required this.groundingSupports,
    this.reliabilityMetrics,
  });

  factory AnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AnalysisResponse(
      verdict: json['verdict'] ?? 'UNVERIFIED',
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      analysis: json['analysis'] ?? '',
      keyFindings: List<String>.from(json['key_findings'] ?? []),
      groundingCitations: (json['grounding_citations'] as List<dynamic>?)
              ?.map((e) => GroundingCitation.fromJson(e))
              .toList() ??
          [],
      groundingSupports: (json['grounding_supports'] as List<dynamic>?)
              ?.map((e) => GroundingSupport.fromJson(e))
              .toList() ??
          [],
      reliabilityMetrics: json['reliability_metrics'] != null
          ? ReliabilityMetrics.fromJson(json['reliability_metrics'])
          : null,
    );
  }
}

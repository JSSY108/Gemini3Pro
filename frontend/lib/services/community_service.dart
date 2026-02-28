import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/community_models.dart';
import '../models/discussion_models.dart';
import '../config/api_config.dart';

class CommunityService {
  // Dynamic base URL that adapts to the environment (Codespaces, localhost, production)
  String get baseUrl => ApiConfig.getBaseUrl();

  Future<CommunityClaimData> getClaimData(String claimText) async {
    final url = '$baseUrl/claim';
    try {
      debugPrint('📤 GET claim data from: $url');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'claim_text': claimText}),
      ).timeout(const Duration(seconds: 10));

      debugPrint('📥 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CommunityClaimData.fromJson(data);
      } else {
        debugPrint('❌ Error response: ${response.body}');
        throw Exception('Failed to get claim data: ${response.statusCode} - ${response.body}');
      }
    } on http.ClientException catch (e) {
      debugPrint('❌ Network error getting claim data: $e');
      debugPrint('   URL attempted: $url');
      debugPrint('   This usually means the backend is not accessible.');
      debugPrint('   In Codespaces, make sure port 8000 is forwarded and accessible.');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error getting claim data: $e');
      rethrow;
    }
  }

  Future<PostClaimResponse> postClaim(String claimText, String aiVerdict) async {
    final url = '$baseUrl/post';
    try {
      debugPrint('📤 Posting claim to: $url');
      debugPrint('   Claim: ${claimText.substring(0, claimText.length > 50 ? 50 : claimText.length)}...');
      debugPrint('   Verdict: $aiVerdict');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'claim_text': claimText,
          'ai_verdict': aiVerdict,
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return PostClaimResponse.fromJson(data);
      } else {
        debugPrint('❌ Error response body: ${response.body}');
        throw Exception('Failed to post claim: ${response.statusCode} - ${response.body}');
      }
    } on http.ClientException catch (e) {
      debugPrint('❌ Network error posting claim: $e');
      debugPrint('   URL attempted: $url');
      debugPrint('   ');
      debugPrint('   TROUBLESHOOTING:');
      debugPrint('   1. Check that backend is running: curl http://localhost:8000/health');
      debugPrint('   2. In Codespaces: Ensure port 8000 is publicly forwarded');
      debugPrint('   3. Check CORS is enabled on backend');
      debugPrint('   ');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error posting claim: $e');
      rethrow;
    }
  }

  Future<VoteResponse> submitVote({
    required String claimId,
    required String userId,
    required String userVerdict,
    String? notes,
    bool? vote,
  }) async {
    final url = '$baseUrl/vote';
    try {
      debugPrint('📤 Submitting vote to: $url');
      debugPrint('   Claim ID: $claimId');
      debugPrint('   User ID: $userId');
      debugPrint('   Verdict: $userVerdict');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'claim_id': claimId,
          'user_id': userId,
          'user_verdict': userVerdict,
          'notes': notes,
          'vote': vote,
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 Vote response status: ${response.statusCode}');
      debugPrint('📥 Vote response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return VoteResponse.fromJson(data);
      } else {
        debugPrint('❌ Error response: ${response.body}');
        throw Exception('Failed to submit vote: ${response.statusCode} - ${response.body}');
      }
    } on http.ClientException catch (e) {
      debugPrint('❌ Network error submitting vote: $e');
      debugPrint('   URL attempted: $url');
      debugPrint('   This is likely a connectivity issue between frontend and backend.');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error submitting vote: $e');
      rethrow;
    }
  }

  Future<List<ClaimSummary>> getTopClaims({int limit = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/top?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final claims = (data['claims'] as List)
            .map((claim) => ClaimSummary.fromJson(claim))
            .toList();
        return claims;
      } else {
        throw Exception('Failed to get top claims: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting top claims: $e');
      rethrow;
    }
  }

  Future<List<ClaimSummary>> searchClaims(String query) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/search'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final claims = (data['claims'] as List)
            .map((claim) => ClaimSummary.fromJson(claim))
            .toList();
        return claims;
      } else {
        throw Exception('Failed to search claims: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching claims: $e');
      rethrow;
    }
  }

  Future<UserReputation> getUserReputation(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reputation/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserReputation.fromJson(data);
      } else {
        throw Exception('Failed to get user reputation: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting user reputation: $e');
      rethrow;
    }
  }

  Future<ClaimDiscussion> getClaimDiscussion(String claimId) async {
    final url = '$baseUrl/discussion/$claimId';
    try {
      debugPrint('📤 GET discussion data from: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('📥 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ClaimDiscussion.fromJson(data);
      } else {
        debugPrint('❌ Error response: ${response.body}');
        throw Exception('Failed to get discussion: ${response.statusCode} - ${response.body}');
      }
    } on http.ClientException catch (e) {
      debugPrint('❌ Network error getting discussion: $e');
      debugPrint('   URL attempted: $url');
      debugPrint('   This usually means the backend is not accessible.');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error getting discussion: $e');
      rethrow;
    }
  }
}

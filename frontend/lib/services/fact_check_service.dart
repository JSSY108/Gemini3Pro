import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import '../models/grounding_models.dart';

class FactCheckService {
  final String baseUrl = kReleaseMode
      ? 'https://us-central1-veriscan-kitahack.cloudfunctions.net/analyze'
      : 'http://127.0.0.1:8080';

  Future<AnalysisResponse> analyzeNews({
    String? text,
    String? url,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));

      debugPrint(
          'SERVICE DEBUG: Sending - Text: $text, URL: $url, Image: $imageFilename');

      if (text != null && text.isNotEmpty) {
        request.fields['text'] = text;
      }
      if (url != null && url.isNotEmpty) {
        request.fields['url'] = url;
      }
      if (imageBytes != null && imageFilename != null) {
        // Determine mime type based on extension, or default to jpeg/png
        final mimeType =
            imageFilename.toLowerCase().endsWith('png') ? 'png' : 'jpeg';

        request.files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageFilename,
          contentType: MediaType('image', mimeType),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return AnalysisResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
            'Failed to analyze: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }
}

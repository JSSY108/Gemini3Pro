import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/grounding_models.dart';

class DemoService {
  static Future<AnalysisResponse?> loadLemonDemo() async {
    try {
      print("🔍 DEBUG: Starting asset load for demo_lemon_analysis.json...");
      final String response =
          await rootBundle.loadString('data/demo_lemon_analysis.json');
      print("🔍 DEBUG: Asset loaded. String length: ${response.length}");

      final data = await json.decode(response);
      print("🔍 DEBUG: JSON decoded successfully.");

      return AnalysisResponse.fromJson(data);
    } catch (e) {
      print("❌ DEBUG ERROR: Demo Load Failed: $e");
      return null;
    }
  }

  Future<void> simulateLoading() async {
    await Future.delayed(const Duration(seconds: 2));
  }
}

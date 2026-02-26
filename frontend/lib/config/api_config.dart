import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform; // Safe to use with kIsWeb checks

class ApiConfig {
  static String getBaseUrl() {
    // Allow temporary override without changing defaults or committing secrets.
    const envOverride = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    if (envOverride.isNotEmpty) {
      return envOverride.endsWith('/community') ? envOverride : '${envOverride.replaceAll(RegExp(r'\/$'), '')}/community';
    }

    // 1. WEB LOGIC (Codespaces & Forwarded Ports)
    if (kIsWeb) {
      try {
        // MAGIC FIX: Uri.base gets the web URL safely without dart:html!
        final uri = Uri.base; 
        
        // Check if we're in GitHub Codespaces
        if (uri.host.contains('app.github.dev')) {
          final hostParts = uri.host.split('-');
          if (hostParts.length >= 2) {
            final lastPart = hostParts.last.split('.').first;
            
            final codespacePrefix = hostParts.sublist(0, hostParts.length - 1).join('-');
            final backendUrl = 'https://$codespacePrefix-8000.app.github.dev';
            
            print('🌐 Detected Codespaces environment');
            print('🔗 Using backend URL: $backendUrl/community');
            return '$backendUrl/community';
          }
        }
        
        // Check if we're running on a forwarded port
        if (uri.port != 0 && uri.port != 80 && uri.port != 443) {
          final backendUrl = '${uri.scheme}://${uri.host.split('-').first}-8000.${uri.host.split('-').sublist(1).join('-')}';
          print('🔗 Using forwarded port URL: $backendUrl/community');
          return '$backendUrl/community';
        }
      } catch (e) {
        print('⚠️ Error detecting environment: $e');
      }
    }
    
    // 2. MOBILE LOGIC (Physical Device & Emulator)
    if (!kIsWeb) {
      // Default for mobile / emulator: use localhost / emulator mapping.
      final String physicalDeviceIp = '127.0.0.1';
      // Note: For Android emulator you may need to use 10.0.2.2 instead.
      print('📱 Using Physical Device/Emulator backend: http://$physicalDeviceIp:8000/community');
      return 'http://$physicalDeviceIp:8000/community';
    }
    
    // 3. DEFAULT FALLBACK
    print('🏠 Using localhost backend: http://localhost:8000/community');
    return 'http://localhost:8000/community';
  }
}
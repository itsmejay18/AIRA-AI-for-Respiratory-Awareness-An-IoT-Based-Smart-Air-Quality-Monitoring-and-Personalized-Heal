import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.aiBaseUrl,
  });

  factory AppConfig.fromEnv() {
    final supabaseUrl =
        dotenv.maybeGet('SUPABASE_URL') ?? dotenv.maybeGet('url') ?? '';
    final supabaseAnonKey =
        dotenv.maybeGet('SUPABASE_ANON_KEY') ??
        dotenv.maybeGet('anon key') ??
        '';

    return AppConfig(
      supabaseUrl: supabaseUrl.trim(),
      supabaseAnonKey: supabaseAnonKey.trim(),
      aiBaseUrl:
          dotenv.maybeGet('AI_BASE_URL') ?? AppConstants.aiBaseUrlFallback,
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String aiBaseUrl;

  bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnv());

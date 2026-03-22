import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  SettingsRepository({
    required SharedPreferences preferences,
    SupabaseClient? supabaseClient,
  }) : _preferences = preferences,
       _supabaseClient = supabaseClient;

  final SharedPreferences _preferences;
  final SupabaseClient? _supabaseClient;

  Future<AppSettings> loadSettings({
    required String userId,
    required String email,
  }) async {
    final client = _supabaseClient;
    if (client != null) {
      try {
        final response = await client
            .from('users')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (response != null) {
          return AppSettings.fromMap({
            'user_id': userId,
            'email': email,
            ...response,
          });
        }
      } catch (_) {
        // Use local storage when the users table is not available yet.
      }
    }

    final saved = _preferences.getString(AppConstants.settingsPrefsKey);
    if (saved != null) {
      return AppSettings.fromMap(jsonDecode(saved) as Map<String, dynamic>);
    }

    return AppSettings(
      userId: userId,
      fullName: 'Demo Farmer',
      email: email,
      autoIrrigationEnabled: true,
      notificationsEnabled: true,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final client = _supabaseClient;
    if (client != null) {
      try {
        await client.from('users').upsert({
          'id': settings.userId,
          'full_name': settings.fullName,
          'email': settings.email,
          'auto_irrigation_enabled': settings.autoIrrigationEnabled,
          'notifications_enabled': settings.notificationsEnabled,
        });
      } catch (_) {
        // Save locally even if the remote table is still missing.
      }
    }

    await _preferences.setString(
      AppConstants.settingsPrefsKey,
      jsonEncode(settings.toMap()),
    );
  }
}

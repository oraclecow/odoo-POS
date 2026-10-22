import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/odoo_pos_models.dart';

class PosRuntimeConfig {
  final String defaultOdooUrl;
  final String defaultDatabase;
  final List<OdooCompanyProfile> profiles;

  const PosRuntimeConfig({
    this.defaultOdooUrl = 'http://localhost:8069',
    this.defaultDatabase = 'odoo',
    this.profiles = OdooCompanyProfile.availableProfiles,
  });

  factory PosRuntimeConfig.fromJson(Map<String, dynamic> json) {
    final rawProfiles = json['profiles'] as List<dynamic>?;
    final parsedProfiles = (rawProfiles != null && rawProfiles.isNotEmpty)
        ? rawProfiles
            .whereType<Map<String, dynamic>>()
            .map(OdooCompanyProfile.fromJson)
            .toList()
        : OdooCompanyProfile.availableProfiles;

    return PosRuntimeConfig(
      defaultOdooUrl: json['default_odoo_url']?.toString() ?? 'http://localhost:8069',
      defaultDatabase: json['default_database']?.toString() ?? 'odoo',
      profiles: parsedProfiles,
    );
  }

  static Future<PosRuntimeConfig> load({String? baseUrl}) async {
    try {
      final Uri uri = kIsWeb
          ? Uri.base.resolve('/pos_config.json')
          : Uri.parse('${baseUrl ?? "http://127.0.0.1:8089"}/pos_config.json');
      final response = await http.get(uri).timeout(const Duration(milliseconds: 800));
      if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
        return PosRuntimeConfig.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return const PosRuntimeConfig();
  }
}

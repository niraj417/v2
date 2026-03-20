import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lead_model.dart';
import 'firebase_lead_service.dart';
import 'database_service.dart';

class LeadGeneratorService {
  final _uuid = const Uuid();
  final _random = Random();

  /// Mock lead generation (fallback for testing without Apify)
  Future<int> generateLeads(String keyword, String location,
      {String? teamId}) async {
    await Future.delayed(const Duration(seconds: 3));

    final count = _random.nextInt(15) + 5;
    int imported = 0;

    final categories = [keyword, 'Professional Services', 'Local Business', 'Agency'];

    for (int i = 0; i < count; i++) {
      final lead = Lead(
        id: _uuid.v4(),
        businessName: '${_generatePrefix()} $keyword ${_generateSuffix()}'.trim(),
        category: categories[_random.nextInt(categories.length)],
        phone: '+1 555-${_random.nextInt(9000) + 1000}',
        email: 'hello@mocklead${_random.nextInt(100)}.com',
        website: 'https://mocklead${_random.nextInt(100)}.com',
        rating: (_random.nextDouble() * 2 + 3).toDouble(),
        reviewCount: _random.nextInt(500),
        address: '${_random.nextInt(9999)} Main St, $location',
        latitude: (_random.nextDouble() * 0.1) + 40.0,
        longitude: (_random.nextDouble() * 0.1) - 74.0,
        keyword: keyword,
        location: location,
        leadStatus: 'New',
        createdAt: DateTime.now(),
        addedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
        addedByEmail: FirebaseAuth.instance.currentUser?.email ?? '',
      );

      try {
        await FirebaseLeadService.instance.addLead(lead, teamId: teamId);
        imported++;
      } catch (e) {
        // Skip on error
      }
    }

    if (imported > 0) {
      await DatabaseService.instance.insertSearchHistory(keyword, location, imported);
    }

    return imported;
  }

  String _generatePrefix() {
    const prefixes = ['The Best', 'Premium', 'Local', 'Express', 'Elite', 'Pro', 'Apex'];
    return prefixes[_random.nextInt(prefixes.length)];
  }

  String _generateSuffix() {
    const suffixes = ['Services', 'Agency', 'Co.', 'Group', 'Solutions', 'Clinic', 'Experts'];
    return suffixes[_random.nextInt(suffixes.length)];
  }
}

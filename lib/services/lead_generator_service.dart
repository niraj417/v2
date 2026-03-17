import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/lead_model.dart';
import 'database_service.dart';

class LeadGeneratorService {
  final _uuid = Uuid();
  final _random = Random();

  /// Mock lead generation simulating scraping API
  Future<int> generateLeads(String keyword, String location) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 3));

    final count = _random.nextInt(15) + 5; // Generate 5-20 leads
    int imported = 0;

    final categories = [
      keyword,
      'Professional Services',
      'Local Business',
      'Agency'
    ];

    for (int i = 0; i < count; i++) {
      final lead = Lead(
        id: _uuid.v4(),
        businessName: '${_generatePrefix()} $keyword ${_generateSuffix()}'.trim(),
        category: categories[_random.nextInt(categories.length)],
        phone: '+1 555-${_random.nextInt(9000) + 1000}',
        email: 'hello@mocklead${_random.nextInt(100)}.com',
        website: 'https://mocklead${_random.nextInt(100)}.com',
        rating: (_random.nextDouble() * 2 + 3).toDouble(), // 3.0 to 5.0
        reviewCount: _random.nextInt(500),
        address: '${_random.nextInt(9999)} Main St, $location',
        latitude: (_random.nextDouble() * 0.1) + 40.0, 
        longitude: (_random.nextDouble() * 0.1) - 74.0,
        keyword: keyword,
        location: location,
        leadStatus: 'New',
        createdAt: DateTime.now(),
      );

      // Attempt to save (database handles deduplication)
      try {
        await DatabaseService.instance.insertLead(lead);
        imported++;
      } catch (e) {
        // Skip on duplicate
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

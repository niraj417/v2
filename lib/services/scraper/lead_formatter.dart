import '../../models/lead_model.dart';

class LeadFormatter {
  /// Transforms raw JS extraction data into a structured [Lead] model.
  static Lead format(Map<String, dynamic> data, String keyword, String location) {
    // Generate a safer ID if the script one is missing
    final String rawId = data['id'] ?? '';
    final String safeId = rawId.isNotEmpty 
        ? rawId 
        : '${data['name']}_${data['category']}_${DateTime.now().millisecondsSinceEpoch}';

    return Lead(
      id: safeId,
      businessName: data['name'] ?? 'Unknown',
      category: data['category'] ?? keyword,
      phone: data['phone'] ?? '',
      website: data['link'] ?? '',
      rating: double.tryParse(data['rating']?.toString() ?? '0') ?? 0,
      reviewCount: int.tryParse(data['reviews']?.toString() ?? '0') ?? 0,
      address: data['address'] ?? '',
      keyword: keyword,
      location: location,
      leadStatus: 'New',
      createdAt: DateTime.now(),
    );
  }
}

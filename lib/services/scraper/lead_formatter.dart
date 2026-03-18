import '../../models/lead_model.dart';

class LeadFormatter {
  /// Transforms raw Apify Google Maps actor output into a structured [Lead] model.
  ///
  /// The Apify actor (sbEjxxfeFlEBHijJS) returns data with these key fields:
  ///   title, totalScore, reviewsCount, phone, phoneUnformatted,
  ///   website, address, categoryName, categories, placeId,
  ///   location.lat, location.lng, emails (array of strings)
  static Lead format(Map<String, dynamic> data, String keyword, String location) {
    // --- ID ---
    // Use Google's placeId as the stable unique identifier.
    final String placeId = data['placeId'] ?? '';
    final String title = data['title'] ?? data['name'] ?? 'Unknown';
    final String safeId = placeId.isNotEmpty
        ? placeId
        : '${title}_${DateTime.now().millisecondsSinceEpoch}';

    // --- Category ---
    // 'categoryName' is the primary category. Fall back to first entry in 'categories'.
    String category = data['categoryName'] ?? '';
    if (category.isEmpty) {
      final List<dynamic>? cats = data['categories'] as List<dynamic>?;
      if (cats != null && cats.isNotEmpty) {
        category = cats.first.toString();
      }
    }
    if (category.isEmpty) category = keyword;

    // --- Phone ---
    // Prefer formatted phone, fall back to unformatted.
    final String phone = (data['phone'] as String?)?.trim().isNotEmpty == true
        ? data['phone'] as String
        : (data['phoneUnformatted'] ?? '') as String;

    // --- Email ---
    // 'emails' is a List<String> returned by the actor's email enrichment.
    String email = '';
    final dynamic rawEmails = data['emails'];
    if (rawEmails is List && rawEmails.isNotEmpty) {
      email = rawEmails.first.toString();
    } else if (rawEmails is String) {
      email = rawEmails;
    }

    // --- Rating ---
    // 'totalScore' is a double (e.g., 4.7).
    final double rating =
        double.tryParse(data['totalScore']?.toString() ?? '0') ?? 0.0;

    // --- Review Count ---
    // 'reviewsCount' is an int.
    final int reviewCount =
        int.tryParse(data['reviewsCount']?.toString() ?? '0') ?? 0;

    // --- Address ---
    final String address = data['address'] ?? data['street'] ?? '';

    // --- Coordinates ---
    // 'location' is a nested object: { "lat": 37.7..., "lng": -122.4... }
    double latitude = 0.0;
    double longitude = 0.0;
    final dynamic loc = data['location'];
    if (loc is Map) {
      latitude = double.tryParse(loc['lat']?.toString() ?? '0') ?? 0.0;
      longitude = double.tryParse(loc['lng']?.toString() ?? '0') ?? 0.0;
    }

    // --- Website ---
    final String website = data['website'] ?? data['url'] ?? '';

    return Lead(
      id: safeId,
      businessName: title,
      category: category,
      phone: phone,
      email: email,
      website: website,
      rating: rating,
      reviewCount: reviewCount,
      address: address,
      latitude: latitude,
      longitude: longitude,
      keyword: keyword,
      location: location,
      leadStatus: 'New',
      createdAt: DateTime.now(),
    );
  }
}

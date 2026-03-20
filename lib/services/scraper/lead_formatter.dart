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
    final String placeId = data['placeId'] ?? data['google_place_id'] ?? '';
    final String title = data['title'] ?? data['name'] ?? 'Unknown';
    final String safeId = placeId.isNotEmpty
        ? placeId
        : '${title}_${DateTime.now().millisecondsSinceEpoch}';

    // --- Category ---
    String category = data['categoryName'] ?? data['google_business_categories'] ?? '';
    if (category.isEmpty) {
      final List<dynamic>? cats = data['categories'] as List<dynamic>?;
      if (cats != null && cats.isNotEmpty) category = cats.first.toString();
    }
    if (category.isEmpty) category = keyword;

    // --- Phone ---
    final String phone = data['phone_number'] ?? data['phone'] ?? data['phoneUnformatted'] ?? '';

    // --- Email ---
    String email = '';
    final dynamic rawEmails = data['emails'];
    if (rawEmails is List && rawEmails.isNotEmpty) {
      email = rawEmails.first.toString();
    } else if (rawEmails is String) {
      email = rawEmails;
    }

    // --- Rating ---
    final double rating =
        double.tryParse(data['review_score']?.toString() ?? data['totalScore']?.toString() ?? '0') ?? 0.0;

    // --- Review Count ---
    final int reviewCount =
        int.tryParse(data['reviews_number']?.toString() ?? data['reviewsCount']?.toString() ?? '0') ?? 0;

    // --- Address ---
    final String address = data['address'] ?? data['street'] ?? '';

    // --- Coordinates ---
    double latitude = 0.0;
    double longitude = 0.0;

    if (data['latitude'] != null && data['longitude'] != null) {
      latitude = double.tryParse(data['latitude'].toString()) ?? 0.0;
      longitude = double.tryParse(data['longitude'].toString()) ?? 0.0;
    } else {
      final dynamic loc = data['location'];
      if (loc is Map) {
        latitude = double.tryParse(loc['lat']?.toString() ?? '0') ?? 0.0;
        longitude = double.tryParse(loc['lng']?.toString() ?? '0') ?? 0.0;
      }
    }

    // --- Website ---
    final String website = data['website_url'] ?? data['website'] ?? data['url'] ?? '';

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
      // addedBy & addedByEmail will be set by FirebaseLeadService when saved
      addedBy: '',
      addedByEmail: '',
    );
  }
}

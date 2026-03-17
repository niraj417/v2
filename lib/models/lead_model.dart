class Lead {
  final String id;
  final String businessName;
  final String category;
  final String phone;
  final String email;
  final String website;
  final double rating;
  final int reviewCount;
  final String address;
  final double latitude;
  final double longitude;
  final String keyword;
  final String location;
  final String leadStatus; // New, Contacted, Interested, Not Interested, Closed
  final DateTime createdAt;

  Lead({
    required this.id,
    required this.businessName,
    required this.category,
    required this.phone,
    required this.email,
    required this.website,
    required this.rating,
    required this.reviewCount,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.keyword,
    required this.location,
    required this.leadStatus,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_name': businessName,
      'category': category,
      'phone': phone,
      'email': email,
      'website': website,
      'rating': rating,
      'review_count': reviewCount,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'keyword': keyword,
      'location': location,
      'lead_status': leadStatus,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Lead.fromMap(Map<String, dynamic> map) {
    return Lead(
      id: map['id'],
      businessName: map['business_name'],
      category: map['category'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      website: map['website'] ?? '',
      rating: map['rating']?.toDouble() ?? 0.0,
      reviewCount: map['review_count'] ?? 0,
      address: map['address'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      keyword: map['keyword'] ?? '',
      location: map['location'] ?? '',
      leadStatus: map['lead_status'] ?? 'New',
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Lead copyWith({
    String? id,
    String? businessName,
    String? category,
    String? phone,
    String? email,
    String? website,
    double? rating,
    int? reviewCount,
    String? address,
    double? latitude,
    double? longitude,
    String? keyword,
    String? location,
    String? leadStatus,
    DateTime? createdAt,
  }) {
    return Lead(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      category: category ?? this.category,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      keyword: keyword ?? this.keyword,
      location: location ?? this.location,
      leadStatus: leadStatus ?? this.leadStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

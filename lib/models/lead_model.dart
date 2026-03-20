import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Team & Firebase fields
  final String? teamId;        // Team this lead belongs to (null if solo user)
  final String addedBy;        // UID of user who added the lead
  final String addedByEmail;   // Email of user who added the lead
  final String? claimedBy;     // UID of team member who claimed the lead (null = unclaimed)
  final String? claimedByEmail; // Email of member who claimed (for display)

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
    this.teamId,
    required this.addedBy,
    required this.addedByEmail,
    this.claimedBy,
    this.claimedByEmail,
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

  /// Serialize for Firestore (uses server-friendly field names)
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'businessName': businessName,
      'category': category,
      'phone': phone,
      'email': email,
      'website': website,
      'rating': rating,
      'reviewCount': reviewCount,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'keyword': keyword,
      'location': location,
      'leadStatus': leadStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'teamId': teamId,
      'addedBy': addedBy,
      'addedByEmail': addedByEmail,
      'claimedBy': claimedBy,
      'claimedByEmail': claimedByEmail,
    };
  }

  factory Lead.fromMap(Map<String, dynamic> map) {
    return Lead(
      id: map['id'] ?? '',
      businessName: map['business_name'] ?? '',
      category: map['category'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      website: map['website'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: map['review_count'] as int? ?? 0,
      address: map['address'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      keyword: map['keyword'] ?? '',
      location: map['location'] ?? '',
      leadStatus: map['lead_status'] ?? 'New',
      createdAt: DateTime.parse(map['created_at'] as String),
      addedBy: map['addedBy'] ?? '',
      addedByEmail: map['addedByEmail'] ?? '',
      teamId: map['teamId'],
      claimedBy: map['claimedBy'],
      claimedByEmail: map['claimedByEmail'],
    );
  }

  /// Deserialize from a Firestore DocumentSnapshot
  factory Lead.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Lead(
      id: doc.id,
      businessName: map['businessName'] ?? '',
      category: map['category'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      website: map['website'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: map['reviewCount'] as int? ?? 0,
      address: map['address'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      keyword: map['keyword'] ?? '',
      location: map['location'] ?? '',
      leadStatus: map['leadStatus'] ?? 'New',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      teamId: map['teamId'],
      addedBy: map['addedBy'] ?? '',
      addedByEmail: map['addedByEmail'] ?? '',
      claimedBy: map['claimedBy'],
      claimedByEmail: map['claimedByEmail'],
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
    Object? teamId = _sentinel,
    String? addedBy,
    String? addedByEmail,
    Object? claimedBy = _sentinel,
    Object? claimedByEmail = _sentinel,
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
      teamId: teamId == _sentinel ? this.teamId : teamId as String?,
      addedBy: addedBy ?? this.addedBy,
      addedByEmail: addedByEmail ?? this.addedByEmail,
      claimedBy: claimedBy == _sentinel ? this.claimedBy : claimedBy as String?,
      claimedByEmail: claimedByEmail == _sentinel
          ? this.claimedByEmail
          : claimedByEmail as String?,
    );
  }
}

// Sentinel value to differentiate "not provided" from explicit null in copyWith
const Object _sentinel = Object();

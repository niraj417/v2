import 'package:cloud_firestore/cloud_firestore.dart';

class MessageTemplate {
  final String id;
  final String name;
  final String content;
  final List<String> platforms;
  final String createdBy;
  final DateTime createdAt;

  MessageTemplate({
    required this.id,
    required this.name,
    required this.content,
    required this.platforms,
    required this.createdBy,
    required this.createdAt,
  });

  factory MessageTemplate.fromMap(Map<String, dynamic> data, String documentId) {
    return MessageTemplate(
      id: documentId,
      name: data['name'] ?? '',
      content: data['content'] ?? '',
      platforms: List<String>.from(data['platforms'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'content': content,
      'platforms': platforms,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

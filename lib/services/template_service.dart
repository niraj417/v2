import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/template_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final TemplateService instance = TemplateService._();
  TemplateService._();

  Stream<List<MessageTemplate>> getTemplatesStream(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('templates')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageTemplate.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addTemplate(String teamId, String name, String content, List<String> platforms) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    await _firestore.collection('teams').doc(teamId).collection('templates').add({
      'name': name,
      'content': content,
      'platforms': platforms,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTemplate(String teamId, String templateId, String name, String content, List<String> platforms) async {
    await _firestore.collection('teams').doc(teamId).collection('templates').doc(templateId).update({
      'name': name,
      'content': content,
      'platforms': platforms,
    });
  }

  Future<void> deleteTemplate(String teamId, String templateId) async {
    await _firestore.collection('teams').doc(teamId).collection('templates').doc(templateId).delete();
  }
}

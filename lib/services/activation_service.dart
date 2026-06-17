import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class ActivationService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static final ActivationService instance = ActivationService._();
  ActivationService._();

  Future<void> claimCode(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    if (code.trim().isEmpty) {
      throw Exception('Please enter an activation code.');
    }

    final codeRef = _db.collection('activation_codes').doc(code.trim());
    final userRef = _db.collection('users').doc(user.uid);

    await _db.runTransaction((tx) async {
      final codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) {
        throw Exception('Invalid activation code.');
      }
      final data = codeSnap.data()!;
      if (data['used'] == true) {
        throw Exception('Activation code has already been used.');
      }

      // Claim code
      tx.update(codeRef, {
        'used': true,
        'usedByEmail': user.email,
        'usedByUid': user.uid,
        'usedAt': FieldValue.serverTimestamp(),
      });

      // Update user
      tx.set(userRef, {
        'activationCode': code.trim(),
        'email': user.email, // Ensure email is there just in case
        'uid': user.uid,
      }, SetOptions(merge: true));
    });
  }

  // Admin function to generate 10,000 keys (Creates 20 batches of 500)
  Future<void> generateAdminKeys() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    
    for (int i = 0; i < 20; i++) {
      final batch = _db.batch();
      for (int j = 0; j < 500; j++) {
        String code = List.generate(15, (index) => chars[random.nextInt(chars.length)]).join();
        final docRef = _db.collection('activation_codes').doc(code);
        batch.set(docRef, {
          'used': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}

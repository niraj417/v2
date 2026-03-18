import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user information (email, primarily)
  User? get currentUser => _auth.currentUser;

  // Initialize a user profile upon signup
  Future<void> initializeUserProfile() async {
    if (currentUser == null) return;
    final userDoc = await _db.collection('users').doc(currentUser!.uid).get();
    if (!userDoc.exists) {
      await _db.collection('users').doc(currentUser!.uid).set({
        'email': currentUser!.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Create a new team
  Future<String?> createTeam(String teamName) async {
    if (currentUser == null) return null;
    
    final docRef = await _db.collection('teams').add({
      'name': teamName,
      'ownerId': currentUser!.uid,
      'ownerEmail': currentUser!.email,
      'members': [currentUser!.email], // List of emails
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // Get the team the current user belongs to
  Stream<QuerySnapshot> getUserTeams() {
    return _db.collection('teams')
      .where('members', arrayContains: currentUser?.email)
      .snapshots();
  }

  // Add a member by email
  Future<void> addMember(String teamId, String email) async {
    await _db.collection('teams').doc(teamId).update({
      'members': FieldValue.arrayUnion([email.trim()])
    });
  }

  // Log a call event for tracking performance
  Future<void> logCall(String teamId, String leadPhone, String leadName) async {
    if (currentUser == null) return;
    
    await _db.collection('teams').doc(teamId).collection('call_logs').add({
      'callerEmail': currentUser!.email,
      'leadPhone': leadPhone,
      'leadName': leadName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get call logs for a team (for admin view)
  Stream<QuerySnapshot> getTeamCallLogs(String teamId) {
    return _db.collection('teams')
      .doc(teamId)
      .collection('call_logs')
      .orderBy('timestamp', descending: true)
      .snapshots();
  }
}

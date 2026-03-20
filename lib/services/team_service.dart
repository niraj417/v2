import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // ─── User Profile ────────────────────────────────────────────────────────

  Future<void> initializeUserProfile() async {
    if (currentUser == null) return;
    final userDoc =
        await _db.collection('users').doc(currentUser!.uid).get();
    if (!userDoc.exists) {
      await _db.collection('users').doc(currentUser!.uid).set({
        'email': currentUser!.email,
        'displayName': currentUser!.displayName ?? '',
        'uid': currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─── Team CRUD ───────────────────────────────────────────────────────────

  Future<String?> createTeam(String teamName) async {
    if (currentUser == null) return null;

    final docRef = await _db.collection('teams').add({
      'name': teamName,
      'ownerId': currentUser!.uid,
      'ownerEmail': currentUser!.email,
      'members': [currentUser!.email],
      'memberUids': [currentUser!.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Stream<QuerySnapshot> getUserTeams() {
    return _db
        .collection('teams')
        .where('members', arrayContains: currentUser?.email)
        .snapshots();
  }

  Future<void> addMember(String teamId, String email) async {
    await _db.collection('teams').doc(teamId).update({
      'members': FieldValue.arrayUnion([email.trim()])
    });
  }

  // ─── Owner / Member Helpers ───────────────────────────────────────────────

  /// Returns true if the current user is the owner of the given team.
  bool isOwner(Map<String, dynamic> teamData) {
    return teamData['ownerId'] == currentUser?.uid;
  }

  /// Returns the list of member emails for a given team (from already-fetched data).
  List<String> getTeamMembers(Map<String, dynamic> teamData) {
    return List<String>.from(teamData['members'] ?? []);
  }

  // ─── Call Logs ───────────────────────────────────────────────────────────

  Future<void> logCall(
      String teamId, String leadPhone, String leadName) async {
    if (currentUser == null) return;

    await _db
        .collection('teams')
        .doc(teamId)
        .collection('call_logs')
        .add({
      'callerEmail': currentUser!.email,
      'callerUid': currentUser!.uid,
      'leadPhone': leadPhone,
      'leadName': leadName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getTeamCallLogs(String teamId) {
    return _db
        .collection('teams')
        .doc(teamId)
        .collection('call_logs')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}

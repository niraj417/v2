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
      'pendingInvites': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Stream<QuerySnapshot> getUserTeams() {
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('teams')
        .where('memberUids', arrayContains: uid)
        .snapshots();
  }

  // ─── Invitations & Notifications ──────────────────────────────────────────

  Future<void> inviteMember(String teamId, String teamName, String email) async {
    email = email.trim();
    if (email.isEmpty) return;

    // Find target user by email
    final userSnap = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
        
    if (userSnap.docs.isEmpty) {
      throw Exception('User with email $email not found. They must sign up first.');
    }

    final targetUid = userSnap.docs.first.id;

    // Prevent inviting if already in team or if team is full
    final teamDoc = await _db.collection('teams').doc(teamId).get();
    if (teamDoc.exists) {
      final members = List<String>.from(teamDoc.data()?['members'] ?? []);
      final pendingInvites = List<String>.from(teamDoc.data()?['pendingInvites'] ?? []);
      
      if (members.contains(email)) {
        throw Exception('User is already in this team.');
      }
      if (pendingInvites.contains(email)) {
        throw Exception('An invite has already been sent to this user.');
      }
      
      // Enforce 3 team members limit (owner is included in members list, so total members = 4)
      if (members.length + pendingInvites.length >= 4) {
        throw Exception('Maximum team limit reached. Only 3 team members are allowed (this includes pending invites).');
      }
    }

    // Add to pendingInvites in team document
    await _db.collection('teams').doc(teamId).update({
      'pendingInvites': FieldValue.arrayUnion([email]),
    });

    // Create invite notification
    await _db
        .collection('users')
        .doc(targetUid)
        .collection('notifications')
        .add({
      'type': 'team_invite',
      'teamId': teamId,
      'teamName': teamName,
      'inviterEmail': currentUser?.email,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptInvite(String notificationId, String teamId) async {
    if (currentUser == null) return;
    final uid = currentUser!.uid;
    final email = currentUser!.email!;

    final batch = _db.batch();

    // 1. Add user to team and remove from pending invites
    final teamRef = _db.collection('teams').doc(teamId);
    batch.update(teamRef, {
      'members': FieldValue.arrayUnion([email]),
      'memberUids': FieldValue.arrayUnion([uid]),
      'pendingInvites': FieldValue.arrayRemove([email]),
    });

    // 2. Delete the notification
    final notifRef = _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId);
    batch.delete(notifRef);

    await batch.commit();

    // 3. Migrate their personal leads to the new team so they aren't lost
    final personalLeads = await _db
        .collection('leads')
        .where('addedBy', isEqualTo: uid)
        .where('teamId', isNull: true)
        .get();

    if (personalLeads.docs.isNotEmpty) {
      final leadBatch = _db.batch();
      for (var doc in personalLeads.docs) {
        leadBatch.update(doc.reference, {'teamId': teamId});
      }
      await leadBatch.commit();
    }
  }

  Future<void> declineInvite(String notificationId) async {
    if (currentUser == null) return;
    final notifRef = _db
        .collection('users')
        .doc(currentUser!.uid)
        .collection('notifications')
        .doc(notificationId);
        
    final snap = await notifRef.get();
    if (snap.exists) {
      final teamId = snap.data()?['teamId'];
      if (teamId != null) {
        await _db.collection('teams').doc(teamId).update({
          'pendingInvites': FieldValue.arrayRemove([currentUser!.email])
        });
      }
    }

    await notifRef.delete();
  }

  Future<void> leaveTeam(String teamId) async {
    if (currentUser == null) return;
    final uid = currentUser!.uid;
    final email = currentUser!.email!;

    // Check if the user is the owner
    final teamDoc = await _db.collection('teams').doc(teamId).get();
    if (teamDoc.exists && teamDoc.data()?['ownerId'] == uid) {
      throw Exception('Team owner cannot leave the team. You must delete the team instead.');
    }

    // Remove user from team
    final teamRef = _db.collection('teams').doc(teamId);
    await teamRef.update({
      'members': FieldValue.arrayRemove([email]),
      'memberUids': FieldValue.arrayRemove([uid]),
    });
  }

  Stream<QuerySnapshot> getNotifications() {
    if (currentUser == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(currentUser!.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
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

  // ─── Activity Logs ───────────────────────────────────────────────────────────

  Future<void> logActivity(
      String teamId, String leadName, String action, {String? leadPhone}) async {
    if (currentUser == null) return;

    await _db
        .collection('teams')
        .doc(teamId)
        .collection('activity_logs')
        .add({
      'callerEmail': currentUser!.email,
      'callerUid': currentUser!.uid,
      'leadPhone': leadPhone ?? '',
      'leadName': leadName,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getTeamActivityLogs(String teamId) {
    return _db
        .collection('teams')
        .doc(teamId)
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lead_model.dart';

class FirebaseLeadService {
  static final FirebaseLeadService instance = FirebaseLeadService._();
  FirebaseLeadService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  User? get _user => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _leads =>
      _db.collection('leads');

  // ─── Add Lead ─────────────────────────────────────────────────────────────

  /// Saves a lead to Firestore. Automatically attaches the current user's uid,
  /// email and optionally a teamId. Returns the new Firestore document id.
  Future<String> addLead(Lead lead, {String? teamId}) async {
    if (_user == null) throw Exception('Not authenticated');

    final enriched = lead.copyWith(
      addedBy: _user!.uid,
      addedByEmail: _user!.email ?? '',
      teamId: teamId,
      claimedBy: null,
      claimedByEmail: null,
    );

    // Prevent exact duplicates (same phone AND same team/user scope)
    final existing = await _leads
        .where('phone', isEqualTo: lead.phone)
        .where('addedBy', isEqualTo: _user!.uid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty && lead.phone.isNotEmpty) {
      return existing.docs.first.id; // already exists
    }

    final docRef = await _leads.add(enriched.toFirestore());
    return docRef.id;
  }

  // ─── Streams ──────────────────────────────────────────────────────────────

  /// Streams ALL leads belonging to the given team (for team members & owners).
  Stream<List<Lead>> streamTeamLeads(String teamId) {
    return _leads
        .where('teamId', isEqualTo: teamId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Lead.fromFirestore).toList());
  }

  /// Streams only the current user's own leads (for solo / non-team users).
  Stream<List<Lead>> streamMyLeads() {
    if (_user == null) return const Stream.empty();
    return _leads
        .where('addedBy', isEqualTo: _user!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Lead.fromFirestore).toList());
  }

  // ─── Claim Lead ───────────────────────────────────────────────────────────

  /// Atomically claim an unclaimed lead. Fails silently if already claimed.
  Future<void> claimLead(String leadId) async {
    if (_user == null) return;
    final ref = _leads.doc(leadId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      // Only claim if unclaimed
      if (data['claimedBy'] != null) return;
      tx.update(ref, {
        'claimedBy': _user!.uid,
        'claimedByEmail': _user!.email ?? '',
      });
    });
  }

  /// Release a claim (only the claimer or an owner should call this).
  Future<void> unclaimLead(String leadId) async {
    await _leads.doc(leadId).update({
      'claimedBy': FieldValue.delete(),
      'claimedByEmail': FieldValue.delete(),
    });
  }

  // ─── Update / Delete ──────────────────────────────────────────────────────

  Future<void> updateLeadStatus(String leadId, String status) async {
    await _leads.doc(leadId).update({'leadStatus': status});
  }

  Future<void> updateLead(Lead lead) async {
    await _leads.doc(lead.id).update(lead.toFirestore());
  }

  Future<void> deleteLead(String leadId) async {
    await _leads.doc(leadId).delete();
  }
}

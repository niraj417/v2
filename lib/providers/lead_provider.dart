import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lead_model.dart';
import '../services/firebase_lead_service.dart';
import '../services/team_service.dart';

// ─── Auth User Provider ────────────────────────────────────────────────────

/// Streams the current Firebase Auth user (null when logged out).
final authUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ─── Active Team Provider ──────────────────────────────────────────────────

/// Streams the first team the current user belongs to (null if none).
final activeTeamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  return TeamService().getUserTeams().map((snap) {
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  });
});

// ─── Lead List Provider ────────────────────────────────────────────────────

/// Streams leads from Firestore.
///   • Team member  → all leads in their team (teamId matches)
///   • Solo user    → only their own leads
final leadListProvider = StreamProvider<List<Lead>>((ref) {
  final teamAsync = ref.watch(activeTeamProvider);
  final leadService = FirebaseLeadService.instance;

  return teamAsync.when(
    data: (team) {
      if (team != null) {
        return leadService.streamTeamLeads(team['id'] as String);
      }
      return leadService.streamMyLeads();
    },
    loading: () => const Stream.empty(),
    error: (e, _) => const Stream.empty(),
  );
});

// ─── Lead Actions Provider ─────────────────────────────────────────────────

/// Provides imperative actions (claim, update status, delete, etc.) on leads.
final leadActionsProvider = Provider<LeadActions>((ref) => LeadActions(ref));

class LeadActions {
  LeadActions(this.ref);
  final Ref ref;

  FirebaseLeadService get _svc => FirebaseLeadService.instance;

  Future<String> addLead(Lead lead) async {
    final teamAsync = ref.read(activeTeamProvider);
    final teamId = teamAsync.value?['id'] as String?;
    return _svc.addLead(lead, teamId: teamId);
  }

  Future<void> claimLead(String leadId) => _svc.claimLead(leadId);
  Future<void> unclaimLead(String leadId) => _svc.unclaimLead(leadId);
  Future<void> updateLeadStatus(String leadId, String status) =>
      _svc.updateLeadStatus(leadId, status);
  Future<void> updateLead(Lead lead) => _svc.updateLead(lead);
  Future<void> deleteLead(String leadId) => _svc.deleteLead(leadId);
}

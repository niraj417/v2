import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lead_model.dart';
import '../services/database_service.dart';

final leadListProvider = AsyncNotifierProvider<LeadListNotifier, List<Lead>>(() {
  return LeadListNotifier();
});

class LeadListNotifier extends AsyncNotifier<List<Lead>> {
  @override
  FutureOr<List<Lead>> build() async {
    return DatabaseService.instance.getAllLeads();
  }

  Future<void> loadLeads() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => DatabaseService.instance.getAllLeads());
  }

  Future<void> updateLeadStatus(String id, String newStatus) async {
    try {
      await DatabaseService.instance.updateLeadStatus(id, newStatus);
      await loadLeads();
    } catch (e) {
      // Ignored
    }
  }

  Future<void> updateLead(Lead lead) async {
    try {
      await DatabaseService.instance.updateLead(lead);
      await loadLeads();
    } catch (e) {
      // Ignored
    }
  }

  Future<void> deleteLead(String id) async {
    try {
      await DatabaseService.instance.deleteLead(id);
      await loadLeads();
    } catch (e) {
      // Ignored
    }
  }
}

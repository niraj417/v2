import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/lead_model.dart';
import '../services/database_service.dart';
import '../services/drive_backup_service.dart';

final leadListProvider = AsyncNotifierProvider<LeadListNotifier, List<Lead>>(() {
  return LeadListNotifier();
});

class LeadListNotifier extends AsyncNotifier<List<Lead>> {
  @override
  FutureOr<List<Lead>> build() async {
    return DatabaseService.instance.getAllLeads();
  }

  Future<void> _triggerAutoSync() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('auto_sync_drive') ?? false) {
      // We pass a dummy context or handling null in service
      // Better: DriveBackupService should handle null context for silent sync
      debugPrint('Triggering silent auto-sync to Google Drive...');
      DriveBackupService().backupDatabaseToDrive(null, silent: true);
    }
  }

  Future<void> loadLeads() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => DatabaseService.instance.getAllLeads());
  }

  Future<void> updateLeadStatus(String id, String newStatus) async {
    try {
      await DatabaseService.instance.updateLeadStatus(id, newStatus);
      await loadLeads();
      _triggerAutoSync();
    } catch (e) {
      // Ignored
    }
  }

  Future<void> updateLead(Lead lead) async {
    try {
      await DatabaseService.instance.updateLead(lead);
      await loadLeads();
      _triggerAutoSync();
    } catch (e) {
      // Ignored
    }
  }

  Future<void> deleteLead(String id) async {
    try {
      await DatabaseService.instance.deleteLead(id);
      await loadLeads();
      _triggerAutoSync();
    } catch (e) {
      // Ignored
    }
  }
}

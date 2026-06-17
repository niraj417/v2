import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../models/lead_model.dart';

class ExportService {
  Future<String?> exportToCsv(List<Lead> leads) async {
    try {
      if (leads.isEmpty) return null;

      // Request permission
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          return null;
        }
      }

      List<List<dynamic>> rows = [];
      
      // Header
      rows.add([
        "Business Name",
        "Category",
        "Phone",
        "Email",
        "Website",
        "Rating",
        "Reviews",
        "Address",
        "Keyword",
        "Location",
        "Status",
        "Date Generated"
      ]);

      // Data
      for (var lead in leads) {
        rows.add([
          lead.businessName,
          lead.category,
          lead.phone,
          lead.email,
          lead.website,
          lead.rating.toStringAsFixed(1),
          lead.reviewCount.toString(),
          lead.address,
          lead.keyword,
          lead.location,
          lead.leadStatus,
          lead.createdAt.toLocal().toString().split('.').first, // YYYY-MM-DD HH:MM:SS
        ]);
      }

      String csv = rows.map((row) => row.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',')).join('\n');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Save directly to folder
      final directory = Directory('/storage/emulated/0/Exported Leads');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final file = File('${directory.path}/leads_export_$timestamp.csv');
      await file.writeAsString(csv);
      
      return file.path;
    } catch (_) {
      // Export failed silently — caller checks for null return value.
      return null;
    }
  }

  Future<String?> exportTeamReportToCsv(List<dynamic> stats, String timeframe) async {
    try {
      if (stats.isEmpty) return null;

      // Request permission
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          return null;
        }
      }

      List<List<dynamic>> rows = [];
      
      // Header exactly as requested
      rows.add([
        "Team Members",
        "Leads Claimed",
        "Leads Contacted",
        "Leads Interested",
        "Closed",
        "Not Interested",
        "Leads Generated"
      ]);

      // Data
      for (var userStat in stats) {
        rows.add([
          userStat.email,
          userStat.leadsClaimed.toString(),
          userStat.leadsContacted.toString(),
          userStat.leadsInterested.toString(),
          userStat.leadsClosed.toString(),
          userStat.leadsNotInterested.toString(),
          userStat.leadsGenerated.toString(),
        ]);
      }

      String csv = rows.map((row) => row.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',')).join('\n');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Save directly to folder
      final directory = Directory('/storage/emulated/0/Exported Leads');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final file = File('${directory.path}/team_report_${timeframe.toLowerCase()}_$timestamp.csv');
      await file.writeAsString(csv);
      
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

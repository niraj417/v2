import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/lead_model.dart';

class ExportService {
  Future<String?> exportToCsv(List<Lead> leads) async {
    try {
      if (leads.isEmpty) return null;

      final directory = await _getExportDirectory();
      if (directory == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final File file = File('${directory.path}/leads_export_$timestamp.csv');

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
      await file.writeAsString(csv);
      
      return file.path;
    } catch (_) {
      // Export failed silently — caller checks for null return value.
      return null;
    }
  }

  Future<Directory?> _getExportDirectory() async {
    if (Platform.isAndroid) {
      // Use external storage for downloads/documents on Android
      return await getExternalStorageDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }
}

import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import '../models/lead_model.dart';

class ExportService {
  Future<String?> exportToCsv(List<Lead> leads) async {
    try {
      if (leads.isEmpty) return null;

      if (leads.isEmpty) return null;

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
      Uint8List bytes = Uint8List.fromList(csv.codeUnits);
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      String fileName = await FileSaver.instance.saveFile(
        name: 'leads_export_$timestamp',
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      
      return fileName;
    } catch (_) {
      // Export failed silently — caller checks for null return value.
      return null;
    }
  }
}

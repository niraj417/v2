import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/export_service.dart';
import '../services/database_service.dart';
import '../providers/lead_provider.dart';
import '../providers/history_provider.dart';
import '../providers/scraper_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Data Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Export Leads to CSV'),
            subtitle: const Text('Save all your leads into your documents folder.'),
            leading: const Icon(Icons.file_download),
            onTap: () async {
              final leadsState = ref.read(leadListProvider);
              leadsState.whenData((leads) async {
                final exporter = ExportService();
                final path = await exporter.exportToCsv(leads);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(path != null ? 'Exported to: $path' : 'Failed to export leads')),
                  );
                }
              });
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Clear All Leads & History', style: TextStyle(color: Colors.red)),
            subtitle: const Text('This action cannot be undone.'),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () {
              showDialog(
                context: context, 
                builder: (context) => AlertDialog(
                  title: const Text('Clear Database?'),
                  content: const Text('Are you sure you want to delete all leads and search history?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () async {
                        await DatabaseService.instance.clearAll();
                        ref.read(leadListProvider.notifier).loadLeads();
                        ref.read(historyProvider.notifier).loadHistory();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Database cleared successfully')),
                          );
                        }
                      }, 
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text('Integrations & API', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Apify API Token'),
            subtitle: Text(ref.watch(apifyTokenProvider).isEmpty 
                ? 'No token configured. Using local WebView scraper.' 
                : 'Token configured. Using high-performance Apify Cloud Scraper.'),
            leading: const Icon(Icons.cloud_sync),
            trailing: const Icon(Icons.edit),
            onTap: () {
              final controller = TextEditingController(text: ref.read(apifyTokenProvider));
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Apify API Token'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Token',
                      hintText: 'apify_api_...',
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        ref.read(apifyTokenProvider.notifier).updateToken(controller.text.trim());
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Apify token updated')),
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Google Places API Key'),
            subtitle: const Text('Reserved for future enrichment features.'),
            leading: const Icon(Icons.vpn_key),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API configuration coming in a future update')),
              );
            },
          ),
        ],
      ),
    );
  }
}

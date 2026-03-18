import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/export_service.dart';
import '../services/database_service.dart';
import '../services/drive_backup_service.dart';
import '../providers/lead_provider.dart';
import '../providers/history_provider.dart';
import '../providers/scraper_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _autoSync = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSync = prefs.getBool('auto_sync_drive') ?? false;
    });
  }

  Future<void> _toggleAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_drive', value);
    setState(() {
      _autoSync = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Data Management'),
          ListTile(
            title: const Text('Export Leads to CSV'),
            subtitle: const Text('Save all your leads into your documents folder.'),
            leading: const Icon(Icons.file_download, color: Colors.blue),
            onTap: () async {
              final sm = ScaffoldMessenger.of(context);
              final leads = ref.read(leadListProvider).value;
              if (leads != null) {
                final path = await ExportService().exportToCsv(leads);
                sm.showSnackBar(
                  SnackBar(content: Text(path != null ? 'Exported to: $path' : 'Failed to export leads')),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Backup to Google Drive'),
            subtitle: const Text('Manually sync your database to Google Drive.'),
            leading: const Icon(Icons.cloud_upload, color: Colors.blue),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Starting backup... Please wait.')),
              );
              await DriveBackupService().backupDatabaseToDrive(context);
            },
          ),
          ListTile(
            title: const Text('Restore from Google Drive'),
            subtitle: const Text('Overwrite local data with Google Drive backup.'),
            leading: const Icon(Icons.cloud_download, color: Colors.green),
            onTap: () => _confirmRestore(context),
          ),
          SwitchListTile(
            title: const Text('Auto-Sync to Drive'),
            subtitle: const Text('Automatically backup on every update.'),
            secondary: const Icon(Icons.sync, color: Colors.orange),
            value: _autoSync,
            onChanged: _toggleAutoSync,
          ),
          const Divider(),
          ListTile(
            title: const Text('Clear All Leads & History', style: TextStyle(color: Colors.red)),
            subtitle: const Text('This action cannot be undone.'),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () => _confirmClear(context),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Integrations & API'),
          ListTile(
            title: const Text('Apify API Token'),
            subtitle: Text(ref.watch(apifyTokenProvider).isEmpty 
                ? 'No token configured.' 
                : 'Token configured.'),
            leading: const Icon(Icons.vpn_key, color: Colors.purple),
            trailing: const Icon(Icons.edit),
            onTap: () => _showTokenDialog(context),
          ),
          const Divider(),
          const SizedBox(height: 32),
          _buildSectionHeader('Account'),
          ListTile(
            title: const Text('Team Management'),
            subtitle: const Text('Invite members and view team activity.'),
            leading: const Icon(Icons.groups, color: Colors.teal),
            onTap: () => context.push('/team_management'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () async {
              final router = GoRouter.of(context);
              await FirebaseAuth.instance.signOut();
              router.go('/login');
            },
          ),
        ],
      ),
    );
  }

  void _confirmRestore(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text('This will overwrite all local leads with data from Google Drive. Current local data will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              DriveBackupService().restoreDatabaseFromDrive(context);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('Clear Database?'),
        content: const Text('Are you sure you want to delete all leads and search history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final sm = ScaffoldMessenger.of(context);
              
              await DatabaseService.instance.clearAll();
              ref.read(leadListProvider.notifier).loadLeads();
              ref.read(historyProvider.notifier).loadHistory();
              
              if (mounted) {
                nav.pop();
                sm.showSnackBar(
                  const SnackBar(content: Text('Database cleared successfully')),
                );
              }
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTokenDialog(BuildContext context) {
    final controller = TextEditingController(text: ref.read(apifyTokenProvider));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apify API Token'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Token', hintText: 'apify_api_...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(apifyTokenProvider.notifier).updateToken(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

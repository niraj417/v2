import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/export_service.dart';
import '../services/database_service.dart';
import '../services/drive_backup_service.dart';
import '../providers/lead_provider.dart';
import '../providers/history_provider.dart';
import '../providers/scraper_provider.dart';
import '../services/firebase_lead_service.dart';
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
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Ambient Glow Top Left
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF3B82F6)),
            ),
          ),
          // Ambient Glow Bottom Right
          Positioned(
            bottom: -50,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7C3AED)),
            ),
          ),
          // Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(color: Colors.transparent),
            ),
          ),
          
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              children: [
                _buildProfileCard(),
                const SizedBox(height: 32),
                _buildSectionHeader('Data Management'),
                const SizedBox(height: 12),
                _buildTile(
                  icon: Icons.file_download, 
                  iconColor: const Color(0xFF60A5FA),
                  title: 'Export Leads to CSV', 
                  subtitle: 'Save all your leads into your documents folder.',
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
                _buildTile(
                  icon: Icons.cloud_upload, 
                  iconColor: const Color(0xFF60A5FA),
                  title: 'Backup to Google Drive', 
                  subtitle: 'Manually sync your database to Google Drive.',
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Starting backup... Please wait.')),
                    );
                    await DriveBackupService().backupDatabaseToDrive(context);
                  },
                ),
                _buildTile(
                  icon: Icons.cloud_download, 
                  iconColor: const Color(0xFF4ADE80),
                  title: 'Restore from Google Drive', 
                  subtitle: 'Overwrite local data with Google Drive backup.',
                  onTap: () => _confirmRestore(context),
                ),
                _buildSwitchTile(
                  icon: Icons.sync, 
                  iconColor: const Color(0xFFFBBF24),
                  title: 'Auto-Sync to Drive', 
                  subtitle: 'Automatically backup on every update.',
                  value: _autoSync,
                  onChanged: _toggleAutoSync,
                ),
                _buildTile(
                  icon: Icons.delete_forever, 
                  iconColor: const Color(0xFFEF4444),
                  title: 'Clear All Leads & History', 
                  subtitle: 'This action cannot be undone.',
                  textColor: const Color(0xFFEF4444),
                  onTap: () => _confirmClear(context),
                ),
                const SizedBox(height: 32),
                
                _buildSectionHeader('Integrations & API'),
                const SizedBox(height: 12),
                _buildTile(
                  icon: Icons.vpn_key, 
                  iconColor: const Color(0xFFC084FC),
                  title: 'Apify API Token', 
                  subtitle: ref.watch(apifyTokenProvider).isEmpty ? 'No token configured.' : 'Token configured.',
                  trailing: const Icon(Icons.edit, color: Color(0xFF64748B), size: 20),
                  onTap: () => _showTokenDialog(context),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 8.0),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                      children: [
                        const TextSpan(text: 'Get your API token from '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('https://console.apify.com/account/integrations');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Text(
                              'here',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF60A5FA),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF60A5FA)
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                _buildSectionHeader('Account'),
                const SizedBox(height: 12),
                _buildTile(
                  icon: Icons.groups, 
                  iconColor: const Color(0xFF2DD4BF),
                  title: 'Team Management', 
                  subtitle: 'Invite members and view team activity.',
                  onTap: () => context.push('/team_management'),
                ),
                _buildTile(
                  icon: Icons.logout, 
                  iconColor: const Color(0xFFEF4444),
                  title: 'Logout', 
                  subtitle: 'Sign out of your account securely.',
                  textColor: const Color(0xFFEF4444),
                  onTap: () async {
                    final router = GoRouter.of(context);
                    await FirebaseAuth.instance.signOut();
                    router.go('/login');
                  },
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap, Color? textColor, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title, 
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor ?? Colors.white, fontSize: 16)
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: SwitchListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title, 
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF3B82F6),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final displayName = user?.displayName ?? '';
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : '?');
    final name = displayName.isNotEmpty ? displayName : email.split('@').first;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Text(
                      initials,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRestore(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Restore Backup?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('This will overwrite all local leads with data from Google Drive. Current local data will be lost.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8)))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            onPressed: () {
              Navigator.pop(context);
              DriveBackupService().restoreDatabaseFromDrive(context);
            },
            child: Text('Restore', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Clear Database?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete all leads and search history?', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8)))),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final sm = ScaffoldMessenger.of(context);
              
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseLeadService.instance.deleteAllMyLeads(user.uid);
              }
              await DatabaseService.instance.clearMyData();
              
              ref.read(historyProvider.notifier).loadHistory();
              if (mounted) {
                nav.pop();
                sm.showSnackBar(
                  const SnackBar(content: Text('Database cleared successfully')),
                );
              }
            }, 
            child: Text('Delete', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
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
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Apify API Token', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Token', 
            hintText: 'apify_api_...',
            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
            hintStyle: TextStyle(color: Color(0xFF64748B)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF64748B))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3B82F6))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8)))),
          TextButton(
            onPressed: () {
              ref.read(apifyTokenProvider.notifier).updateToken(controller.text.trim());
              Navigator.pop(context);
            },
            child: Text('Save', style: GoogleFonts.inter(color: const Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

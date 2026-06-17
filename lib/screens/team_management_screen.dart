import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/team_service.dart';
import '../services/team_report_service.dart';
import '../services/export_service.dart';
import '../providers/activation_provider.dart';
import '../screens/lock_screen.dart';

class TeamManagementScreen extends ConsumerStatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  ConsumerState<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends ConsumerState<TeamManagementScreen> {
  final TeamService _teamService = TeamService();
  String? _selectedTeamId;
  String? _teamName;

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(appAccessProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Team & Performance', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
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
              width: 250,
              height: 250,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF8B5CF6)),
            ),
          ),
          // Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Main Content
          accessAsync.when(
            data: (hasAccess) {
              if (!hasAccess) return const SafeArea(child: LockScreenWidget());
              return StreamBuilder<QuerySnapshot>(
                stream: _teamService.getUserTeams(),
                builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: const Color(0xFFEF4444))));
              }

              final teams = snapshot.data?.docs ?? [];
              if (teams.isEmpty) {
                return _buildNoTeamView();
              }

              final teamDoc = teams.first;
              final teamData = teamDoc.data() as Map<String, dynamic>;
              _selectedTeamId = teamDoc.id;
              _teamName = teamData['name'];
              final members = List<String>.from(teamData['members'] ?? []);
              final pendingInvites = List<String>.from(teamData['pendingInvites'] ?? []);
              final isOwner = _teamService.isOwner(teamData);

              return _buildTeamDashboard(members, pendingInvites, isOwner);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTeamView() {
    final controller = TextEditingController();
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.group_add_rounded, size: 64, color: Color(0xFF60A5FA)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Team Found',
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a team or ask an owner to invite you.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: controller,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter team name',
                          hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          if (controller.text.isNotEmpty) {
                            await _teamService.createTeam(controller.text.trim());
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Team created!'), backgroundColor: Color(0xFF10B981)),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: Text('Create Team', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamDashboard(List<String> members, List<String> pendingInvites, bool isOwner) {
    return Column(
      children: [
        // Team Header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group_rounded, color: Color(0xFF60A5FA)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Team', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13)),
                    Text(
                      _teamName ?? 'N/A',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.file_download_rounded, color: Color(0xFF10B981)),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF10B981).withOpacity(0.1)),
                    onPressed: _showExportOptions,
                    tooltip: 'Export Report',
                  ),
                  const SizedBox(width: 8),
                  if (isOwner)
                    OutlinedButton.icon(
                      onPressed: (members.length + pendingInvites.length) >= 4 
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Maximum team limit reached (includes pending invites). Only 3 team members allowed.'),
                                  backgroundColor: Color(0xFFEF4444),
                                ),
                              );
                            }
                          : _showAddMemberDialog,
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: Text('Invite', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _showLeaveTeamDialog(context),
                      icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                      label: Text('Leave', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                // Members Section
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.people_alt_outlined, color: Color(0xFF60A5FA), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Members (${members.length})',
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Colors.white24),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(8),
                                itemCount: members.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 4),
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF3B82F6).withOpacity(0.2),
                                      child: const Icon(Icons.person, color: Color(0xFF60A5FA), size: 18),
                                    ),
                                    title: Text(members[index], style: GoogleFonts.inter(color: Colors.white)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Activity Feed Section (Call Logs)
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.history_rounded, color: Color(0xFFF59E0B), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Recent Activity Log',
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Colors.white24),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: _teamService.getTeamActivityLogs(_selectedTeamId!),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
                                  }
                                  final logs = snapshot.data?.docs ?? [];
                                  if (logs.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.phone_disabled_rounded, size: 48, color: Color(0xFF64748B)),
                                          const SizedBox(height: 12),
                                          Text(
                                            "No calls logged yet.\nTap 'Call' on a lead to log.",
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return ListView.separated(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: logs.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                                    itemBuilder: (context, index) {
                                      final data = logs[index].data() as Map<String, dynamic>;
                                      final caller = data['callerEmail'];
                                      final lead = data['leadName'];
                                      final time = (data['timestamp'] as Timestamp?)?.toDate();
                                      final timeStr = time != null ? '${time.hour}:${time.minute.toString().padLeft(2, '0')} - ${time.day}/${time.month}' : '';
                                      final action = data['action'] as String? ?? 'Call';
                                      
                                      IconData iconData = Icons.call_made_rounded;
                                      Color iconColor = const Color(0xFF10B981);
                                      if (action == 'Claim') {
                                        iconData = Icons.person_add_alt_1_rounded;
                                        iconColor = const Color(0xFF3B82F6);
                                      } else if (action == 'Unclaim') {
                                        iconData = Icons.person_remove_alt_1_rounded;
                                        iconColor = const Color(0xFFEF4444);
                                      } else if (action.startsWith('Status Update:')) {
                                        iconData = Icons.swap_horiz_rounded;
                                        iconColor = const Color(0xFFF59E0B);
                                      }

                                      String actionText = ' called ';
                                      if (action == 'Claim') actionText = ' claimed ';
                                      else if (action == 'Unclaim') actionText = ' unclaimed ';
                                      else if (action.startsWith('Status Update:')) {
                                        final status = action.split(': ').last;
                                        actionText = ' marked $status for ';
                                      }

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.03),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: iconColor.withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(iconData, color: iconColor, size: 16),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  RichText(
                                                    text: TextSpan(
                                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                                      children: [
                                                        TextSpan(text: caller, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                        TextSpan(text: actionText),
                                                        TextSpan(text: lead, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF60A5FA))),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(timeStr, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Export Button
                FilledButton.icon(
                  onPressed: _showExportOptions,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text('Export Team Report', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Export Logic ─────────────────────────────────────────────────────────

  void _showExportOptions() {
    if (_selectedTeamId == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Export Team Report', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              _buildExportOption('Today', Icons.today_rounded),
              const SizedBox(height: 12),
              _buildExportOption('This Week', Icons.view_week_rounded),
              const SizedBox(height: 12),
              _buildExportOption('This Month', Icons.calendar_month_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportOption(String label, IconData icon) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF3B82F6).withOpacity(0.2),
        foregroundColor: const Color(0xFF60A5FA),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.5))),
      ),
      icon: Icon(icon),
      label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      onPressed: () {
        Navigator.pop(context);
        _handleExport(label);
      },
    );
  }

  bool _isExporting = false;
  Future<void> _handleExport(String timeFilter) async {
    if (_selectedTeamId == null || _isExporting) return;
    setState(() => _isExporting = true);
    
    // Show loading
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
    );

    try {
      final stats = await TeamReportService().generateStats(_selectedTeamId!, timeFilter);
      final path = await ExportService().exportTeamReportToCsv(stats, timeFilter);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report saved to $path'), backgroundColor: const Color(0xFF10B981)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export failed or permission denied'), backgroundColor: Color(0xFFEF4444)));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showAddMemberDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Invite Team Member', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the email address of the team member you want to invite.',
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: controller,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Member Email',
                  labelStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                  hintText: 'john@example.com',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), 
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (controller.text.isNotEmpty && _selectedTeamId != null && _teamName != null) {
                try {
                  await _teamService.inviteMember(_selectedTeamId!, _teamName!, controller.text.trim());
                  if (dialogContext.mounted) {
                     Navigator.pop(dialogContext);
                     ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Invitation sent successfully!'), backgroundColor: Color(0xFF10B981)),
                     );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                }
              }
            }, 
            child: Text('Send Invite', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      )
    );
  }

  void _showLeaveTeamDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Leave Team', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to leave this team? You will lose access to team leads and your app may lock until you activate it yourself.',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (_selectedTeamId != null) {
                try {
                  await _teamService.leaveTeam(_selectedTeamId!);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext); // Close dialog
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Successfully left the team.'), backgroundColor: Color(0xFF10B981)),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext); // Close dialog immediately on error or we might lock up UI
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                }
              }
            },
            child: Text('Leave', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

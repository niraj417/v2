import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/team_service.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final TeamService _teamService = TeamService();
  String? _selectedTeamId;
  String? _teamName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team & Performance'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _teamService.getUserTeams(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }

          final teams = snapshot.data?.docs ?? [];
          if (teams.isEmpty) {
            return _buildNoTeamView();
          }

          // User belongs to at least one team, default to first
          final teamDoc = teams.first;
          _selectedTeamId = teamDoc.id;
          _teamName = teamDoc['name'];
          final members = List<String>.from(teamDoc['members'] ?? []);

          return _buildTeamDashboard(members);
        },
      ),
    );
  }

  Widget _buildNoTeamView() {
    final controller = TextEditingController();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_add, size: 80, color: Colors.blueGrey),
            const SizedBox(height: 16),
            const Text(
              'You are not part of any team yet.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Team Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await _teamService.createTeam(controller.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Team created!')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create New Team'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamDashboard(List<String> members) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.blue.withValues(alpha: 0.05),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                 'Team: $_teamName', 
                 style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
               ),
               ElevatedButton.icon(
                 onPressed: _showAddMemberDialog,
                 icon: const Icon(Icons.person_add),
                 label: const Text('Invite'),
               )
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Members List
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(members[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // Activity Feed
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Recent Call Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _teamService.getTeamCallLogs(_selectedTeamId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                             return const Center(child: CircularProgressIndicator());
                          }
                          final logs = snapshot.data?.docs ?? [];
                          if (logs.isEmpty) {
                             return const Center(
                               child: Text("No calls logged yet. Tap 'Call' on a lead to log.")
                             );
                          }
                          return ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final data = logs[index].data() as Map<String, dynamic>;
                              final caller = data['callerEmail'];
                              final lead = data['leadName'];
                              final time = (data['timestamp'] as Timestamp?)?.toDate();
                              final timeStr = time != null ? '${time.hour}:${time.minute.toString().padLeft(2, '0')} - ${time.day}/${time.month}' : '';
                              return ListTile(
                                leading: const Icon(Icons.call_made, color: Colors.green),
                                title: Text('$caller called $lead'),
                                subtitle: Text(timeStr),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  void _showAddMemberDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite Team Member'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Member Email',
            hintText: 'john@example.com',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && _selectedTeamId != null) {
                await _teamService.addMember(_selectedTeamId!, controller.text.trim());
                if (dialogContext.mounted) {
                   Navigator.pop(dialogContext);
                   ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Member added!')),
                   );
                }
              }
            }, 
            child: const Text('Add')
          ),
        ],
      )
    );
  }
}

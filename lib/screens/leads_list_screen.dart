import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/lead_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/team_service.dart';

class LeadsListScreen extends ConsumerStatefulWidget {
  const LeadsListScreen({super.key});

  @override
  ConsumerState<LeadsListScreen> createState() => _LeadsListScreenState();
}

class _LeadsListScreenState extends ConsumerState<LeadsListScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'All';

  final List<String> _statuses = ['All', 'New', 'Contacted', 'Interested', 'Not Interested', 'Closed'];

  @override
  Widget build(BuildContext context) {
    final leadsState = ref.watch(leadListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      appBar: AppBar(
        title: const Text('My Leads', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone or keyword...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: _statuses.map((status) {
                    final isSelected = _selectedStatus == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text(status),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedStatus = status;
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: leadsState.when(
        data: (leads) {
          final filteredLeads = leads.where((l) {
            final matchesStatus = _selectedStatus == 'All' || l.leadStatus == _selectedStatus;
            final matchesSearch = l.businessName.toLowerCase().contains(_searchQuery) ||
                l.keyword.toLowerCase().contains(_searchQuery) ||
                l.phone.contains(_searchQuery);
            return matchesStatus && matchesSearch;
          }).toList();

          if (filteredLeads.isEmpty) {
            return const Center(child: Text('No leads found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredLeads.length,
            itemBuilder: (context, index) {
              final lead = filteredLeads[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // Navigate to details (to be implemented)
                    context.push('/lead_details', extra: lead);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                lead.businessName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(lead.leadStatus).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Status: ${lead.leadStatus}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: _getStatusColor(lead.leadStatus),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(lead.phone, style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lead.address,
                                style: TextStyle(color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: lead.phone.isEmpty 
                                    ? null 
                                    : () async {
                                        try {
                                          final Uri url = Uri.parse('tel:${lead.phone}');
                                          await launchUrl(url);
                                          final teamService = TeamService();
                                          final teamsSnapshot = await teamService.getUserTeams().first;
                                          if (teamsSnapshot.docs.isNotEmpty) {
                                            final teamId = teamsSnapshot.docs.first.id;
                                            await teamService.logCall(teamId, lead.phone, lead.businessName);
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Could not launch dialer')),
                                            );
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.phone, size: 18),
                                label: const Text('Call'),
                              ),
                            ),
                            Container(width: 1, height: 24, color: Colors.grey.shade300),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: lead.website.isEmpty 
                                    ? null 
                                    : () async {
                                        try {
                                          final Uri url = Uri.parse(
                                            lead.website.startsWith('http') ? lead.website : 'https://${lead.website}'
                                          );
                                          await launchUrl(url);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Could not open website')),
                                            );
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.language, size: 18),
                                label: const Text('Website'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New': return Colors.blue;
      case 'Contacted': return Colors.orange;
      case 'Interested': return Colors.purple;
      case 'Closed': return Colors.green;
      case 'Not Interested': return Colors.red;
      default: return Colors.grey;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lead_model.dart';
import '../providers/lead_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/team_service.dart';

class LeadDetailsScreen extends ConsumerWidget {
  final Lead lead;

  const LeadDetailsScreen({super.key, required this.lead});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We observe the full list to get reactive updates to this specific lead if status changes
    final leadsState = ref.watch(leadListProvider);
    final currentLead = leadsState.maybeWhen(
      data: (leads) => leads.firstWhere((l) => l.id == lead.id, orElse: () => lead),
      orElse: () => lead,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      appBar: AppBar(
        title: const Text('Lead Details', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            currentLead.businessName,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(currentLead.leadStatus).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            currentLead.leadStatus,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(currentLead.leadStatus),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentLead.category.isNotEmpty ? currentLead.category : 'General Business',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.phone, 'Phone', currentLead.phone),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.email, 'Email', currentLead.email),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.language, 'Website', currentLead.website),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.location_on, 'Address', currentLead.address),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Change Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
               elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: currentLead.leadStatus,
                    items: ['New', 'Contacted', 'Interested', 'Closed', 'Not Interested']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (newStatus) {
                      if (newStatus != null) {
                        ref.read(leadListProvider.notifier).updateLeadStatus(currentLead.id, newStatus);
                      }
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Metadata',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
               elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildMetaRow('Source Keyword', currentLead.keyword),
                    const Divider(height: 24),
                    _buildMetaRow('Location Searched', currentLead.location),
                    const Divider(height: 24),
                    _buildMetaRow('Generated On', currentLead.createdAt.toString().split('.').first),
                    const Divider(height: 24),
                    _buildMetaRow('Rating', '${currentLead.rating} (${currentLead.reviewCount} reviews)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton.icon(
            onPressed: currentLead.phone.isEmpty
                ? null
                : () async {
                    try {
                      final Uri url = Uri.parse('tel:${currentLead.phone}');
                      await launchUrl(url);
                      // Log the call if user is in a team
                      final teamService = TeamService();
                      final teamsSnapshot = await teamService.getUserTeams().first;
                      if (teamsSnapshot.docs.isNotEmpty) {
                        final teamId = teamsSnapshot.docs.first.id;
                        await teamService.logCall(teamId, currentLead.phone, currentLead.businessName);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not launch dialer')),
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.phone),
            label: const Text('Call Lead'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Expanded(
          child: Text(
            value, 
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
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

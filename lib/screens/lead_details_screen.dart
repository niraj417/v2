import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lead_model.dart';
import '../providers/lead_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/team_service.dart';
import '../models/template_model.dart';
import '../services/template_service.dart';

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
                    _buildInfoRow(
                      Icons.phone, 
                      'Phone', 
                      currentLead.phone,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        color: Colors.blue,
                        onPressed: () => _showEditPhoneDialog(context, currentLead, ref),
                      )
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.email, 'Email', currentLead.email),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.language,
                      'Website',
                      currentLead.website,
                      isLink: true,
                      onTap: () async {
                        String urlStr = currentLead.website;
                        if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
                          urlStr = 'https://$urlStr';
                        }
                        final url = Uri.parse(urlStr);
                        try {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open website')),
                            );
                          }
                        }
                      },
                    ),
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
                        ref.read(leadActionsProvider).updateLeadStatus(currentLead.id, newStatus);
                        if (currentLead.teamId != null && currentLead.teamId!.isNotEmpty) {
                          TeamService().logActivity(currentLead.teamId!, currentLead.businessName, 'Status Update: $newStatus', leadPhone: currentLead.phone);
                        }
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
                    if (currentLead.addedByEmail.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildMetaRow('Added By', currentLead.addedByEmail),
                    ],
                    if (currentLead.claimedByEmail != null) ...[
                      const Divider(height: 24),
                      _buildMetaRow('Claimed By', currentLead.claimedByEmail!),
                    ],
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
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: currentLead.phone.isEmpty
                      ? null
                      : () async {
                          try {
                            final Uri url = Uri.parse('tel:${currentLead.phone}');
                            await launchUrl(url);
                            if (currentLead.teamId != null && currentLead.teamId!.isNotEmpty) {
                              final teamService = TeamService();
                              await teamService.logActivity(currentLead.teamId!, currentLead.businessName, 'Call', leadPhone: currentLead.phone);
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
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: currentLead.phone.isEmpty ? null : () => _showMessagingOptions(context, currentLead, 'WhatsApp'),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('WhatsApp'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: currentLead.phone.isEmpty ? null : () => _showMessagingOptions(context, currentLead, 'SMS'),
                  icon: const Icon(Icons.sms, size: 18),
                  label: const Text('SMS'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessagingOptions(BuildContext context, Lead lead, String platform) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bottomSheetContext) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Send $platform', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_document),
              label: const Text('Use Template'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              onPressed: () {
                Navigator.pop(bottomSheetContext);
                _showTemplatesList(context, lead, platform);
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Direct Message'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF3B82F6),
              ),
              onPressed: () {
                Navigator.pop(bottomSheetContext);
                _showDirectMessageDialog(context, lead, platform);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDirectMessageDialog(BuildContext context, Lead lead, String platform) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('New $platform', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Type your message...',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext);
                _launchMessagingApp(context, lead.phone, controller.text.trim(), platform);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  void _showTemplatesList(BuildContext context, Lead lead, String platform) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
    );

    try {
      final teamService = TeamService();
      final teamsSnapshot = await teamService.getUserTeams().first;
      
      if (!context.mounted) return;
      Navigator.pop(context);

      if (teamsSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be in a team to use templates.')));
        return;
      }
      
      final teamId = teamsSnapshot.docs.first.id;
      
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (bottomSheetContext) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text('Select $platform Template', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: StreamBuilder<List<MessageTemplate>>(
                  stream: TemplateService.instance.getTemplatesStream(teamId),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final allTemplates = snapshot.data ?? [];
                    final templates = allTemplates.where((t) => t.platforms.contains(platform)).toList();
                    
                    if (templates.isEmpty) {
                      return Center(child: Text('No $platform templates found.', style: const TextStyle(color: Color(0xFF94A3B8))));
                    }
                    
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: templates.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final t = templates[idx];
                        return InkWell(
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            _launchMessagingApp(context, lead.phone, t.content, platform);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                Text(t.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                              ],
                            ),
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
      );

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _launchMessagingApp(BuildContext context, String phone, String message, String platform) async {
    final encodedMessage = Uri.encodeComponent(message);
    Uri url;
    if (platform == 'WhatsApp') {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');
    } else {
      url = Uri.parse('sms:$phone?body=$encodedMessage');
    }
    
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $platform. Ensure app is installed.')));
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isLink = false, VoidCallback? onTap, Widget? trailing}) {
    if (value.isEmpty && trailing == null) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? 'Not Provided' : value, style: TextStyle(
                  fontSize: 16,
                  color: isLink ? Colors.blue : null,
                  decoration: isLink ? TextDecoration.underline : null,
                )),
              ],
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  void _showEditPhoneDialog(BuildContext context, Lead lead, WidgetRef ref) {
    final controller = TextEditingController(text: lead.phone);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Edit Phone Number', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'Enter phone number...',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), 
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))
          ),
          FilledButton(
            onPressed: () async {
              final newPhone = controller.text.trim();
              if (newPhone != lead.phone) {
                final updatedLead = lead.copyWith(phone: newPhone);
                await ref.read(leadActionsProvider).updateLead(updatedLead);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
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

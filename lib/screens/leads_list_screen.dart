import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/lead_provider.dart';
import '../services/team_service.dart';
import '../models/lead_model.dart';

class LeadsListScreen extends ConsumerStatefulWidget {
  const LeadsListScreen({super.key});

  @override
  ConsumerState<LeadsListScreen> createState() => _LeadsListScreenState();
}

class _LeadsListScreenState extends ConsumerState<LeadsListScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String? _filterByMember; // null = show all (owner filter)

  final List<String> _statuses = [
    'All', 'New', 'Contacted', 'Interested', 'Not Interested', 'Closed'
  ];

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadListProvider);
    final teamAsync = ref.watch(activeTeamProvider);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor:
          Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      appBar: AppBar(
        title: const Text('My Leads', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Owner-only member filter
          teamAsync.when(
            data: (team) {
              if (team == null) return const SizedBox.shrink();
              final teamService = TeamService();
              if (!teamService.isOwner(team)) return const SizedBox.shrink();
              final members = teamService.getTeamMembers(team);
              return _MemberFilterButton(
                members: members,
                selectedMember: _filterByMember,
                onChanged: (m) => setState(() => _filterByMember = m),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
          ),
        ],
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
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
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
                        onSelected: (_) => setState(() => _selectedStatus = status),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: leadsAsync.when(
        data: (leads) {
          var filtered = leads.where((l) {
            final matchesStatus =
                _selectedStatus == 'All' || l.leadStatus == _selectedStatus;
            final matchesSearch =
                l.businessName.toLowerCase().contains(_searchQuery) ||
                    l.keyword.toLowerCase().contains(_searchQuery) ||
                    l.phone.contains(_searchQuery);
            // Owner filter by claimed member
            final matchesMember = _filterByMember == null ||
                l.claimedByEmail == _filterByMember;
            return matchesStatus && matchesSearch && matchesMember;
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 12),
                  Text('No leads found.',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final lead = filtered[index];
              return _LeadCard(
                lead: lead,
                currentUid: currentUid,
                teamAsync: teamAsync,
                onTap: () => context.push('/lead_details', extra: lead),
                onClaim: () async {
                  await ref.read(leadActionsProvider).claimLead(lead.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Lead claimed!'),
                          backgroundColor: Colors.green),
                    );
                  }
                },
                onUnclaim: () async {
                  await ref.read(leadActionsProvider).unclaimLead(lead.id);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ─── Member Filter Button ──────────────────────────────────────────────────

class _MemberFilterButton extends StatelessWidget {
  const _MemberFilterButton({
    required this.members,
    required this.selectedMember,
    required this.onChanged,
  });

  final List<String> members;
  final String? selectedMember;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      icon: Badge(
        isLabelVisible: selectedMember != null,
        child: const Icon(Icons.filter_list_rounded),
      ),
      tooltip: 'Filter by member',
      initialValue: selectedMember,
      onSelected: onChanged,
      itemBuilder: (_) => [
        const PopupMenuItem<String?>(
          value: null,
          child: Text('Show All'),
        ),
        ...members.map((email) => PopupMenuItem<String?>(
              value: email,
              child: Text(email),
            )),
      ],
    );
  }
}

// ─── Lead Card ─────────────────────────────────────────────────────────────

class _LeadCard extends ConsumerWidget {
  const _LeadCard({
    required this.lead,
    required this.currentUid,
    required this.teamAsync,
    required this.onTap,
    required this.onClaim,
    required this.onUnclaim,
  });

  final Lead lead;
  final String currentUid;
  final AsyncValue<Map<String, dynamic>?> teamAsync;
  final VoidCallback onTap;
  final VoidCallback onClaim;
  final VoidCallback onUnclaim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isClaimed = lead.claimedBy != null;
    final isMyCllaim = lead.claimedBy == currentUid;
    final teamService = TeamService();
    final isOwner = teamAsync.value != null &&
        teamService.isOwner(teamAsync.value!);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isClaimed
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ──────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.businessName,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (lead.addedByEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Added by ${lead.addedByEmail}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(lead.leadStatus)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      lead.leadStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(lead.leadStatus),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Claimed Banner ───────────────────────────────────────────
              if (isClaimed) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isMyCllaim
                              ? 'Claimed by you'
                              : 'Claimed by ${lead.claimedByEmail ?? 'a member'}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.green),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              // ── Info rows ────────────────────────────────────────────────
              _InfoRow(Icons.phone, lead.phone),
              const SizedBox(height: 4),
              _InfoRow(Icons.location_on, lead.address, maxLines: 1),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // ── Actions ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: lead.phone.isEmpty
                          ? null
                          : () async {
                              final uri = Uri.parse('tel:${lead.phone}');
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                              final teamAsync2 =
                                  await TeamService().getUserTeams().first;
                              if (teamAsync2.docs.isNotEmpty) {
                                final teamId = teamAsync2.docs.first.id;
                                TeamService().logCall(
                                    teamId, lead.phone, lead.businessName);
                              }
                            },
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Call'),
                    ),
                  ),
                  Container(
                      width: 1, height: 24, color: Colors.grey.shade300),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: lead.website.isEmpty
                          ? null
                          : () async {
                              final raw = lead.website.startsWith('http')
                                  ? lead.website
                                  : 'https://${lead.website}';
                              final uri = Uri.parse(raw);
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                      icon: const Icon(Icons.language, size: 18),
                      label: const Text('Website'),
                    ),
                  ),
                  Container(
                      width: 1, height: 24, color: Colors.grey.shade300),
                  // Claim button
                  Expanded(
                    child: _buildClaimButton(isOwner, isClaimed, isMyCllaim),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClaimButton(bool isOwner, bool isClaimed, bool isMyCllaim) {
    if (!isClaimed) {
      return TextButton.icon(
        onPressed: onClaim,
        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
        label: const Text('Claim'),
      );
    }
    if (isMyCllaim || isOwner) {
      return TextButton.icon(
        onPressed: onUnclaim,
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        icon: const Icon(Icons.bookmark_remove_outlined, size: 18),
        label: const Text('Unclaim'),
      );
    }
    // Claimed by someone else, can't claim
    return TextButton.icon(
      onPressed: null,
      icon: const Icon(Icons.bookmark_outlined, size: 18),
      label: const Text('Claimed'),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'New':
        return Colors.blue;
      case 'Contacted':
        return Colors.orange;
      case 'Interested':
        return Colors.purple;
      case 'Closed':
        return Colors.green;
      case 'Not Interested':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text, {this.maxLines});
  final IconData icon;
  final String text;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade600),
            maxLines: maxLines,
            overflow: maxLines != null ? TextOverflow.ellipsis : null,
          ),
        ),
      ],
    );
  }
}

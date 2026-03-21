import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
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
    'All', 'Claimed', 'New', 'Contacted', 'Interested', 'Not Interested', 'Closed'
  ];

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadListProvider);
    final teamAsync = ref.watch(activeTeamProvider);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Leads', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
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
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone or keyword...',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  ),
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
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedStatus = status),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.5) : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.inter(
                              color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          leadsAsync.when(
            data: (leads) {
              var filtered = leads.where((l) {
                final matchesStatus = _selectedStatus == 'All' || 
                    (_selectedStatus == 'Claimed' ? l.claimedBy != null : l.leadStatus == _selectedStatus);
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
                      const Icon(Icons.inbox_outlined, size: 64, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text('No leads found.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
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
                          const SnackBar(content: Text('Lead claimed!'), backgroundColor: Color(0xFF10B981)),
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
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
            error: (e, st) => Center(child: Text('Error: $e', style: GoogleFonts.inter(color: const Color(0xFFEF4444)))),
          ),
        ],
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
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.filter_list_rounded, color: Colors.white),
      ),
      color: const Color(0xFF1E293B),
      tooltip: 'Filter by member',
      initialValue: selectedMember,
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: null,
          child: Text('Show All', style: GoogleFonts.inter(color: Colors.white)),
        ),
        ...members.map((email) => PopupMenuItem<String?>(
              value: email,
              child: Text(email, style: GoogleFonts.inter(color: Colors.white)),
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
    final isMyClaim = lead.claimedBy == currentUid;
    final teamService = TeamService();
    final isOwner = teamAsync.value != null && teamService.isOwner(teamAsync.value!);

    Color statusColor;
    if (lead.leadStatus == 'New') statusColor = const Color(0xFF3B82F6);
    else if (lead.leadStatus == 'Contacted') statusColor = const Color(0xFFF59E0B);
    else if (lead.leadStatus == 'Interested') statusColor = const Color(0xFF10B981);
    else if (lead.leadStatus == 'Closed') statusColor = const Color(0xFF8B5CF6);
    else statusColor = const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClaimed 
              ? const Color(0xFF10B981).withOpacity(0.3) 
              : Colors.white.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          lead.businessName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          lead.leadStatus,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.category_outlined, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lead.category ?? 'Uncategorized',
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (lead.rating > 0)
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          '${lead.rating} (${lead.reviewCount} reviews)',
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  
                  // Team Claim Info (if in a team and claimed)
                  if (teamAsync.value != null && isClaimed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMyClaim ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isMyClaim ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFF3B82F6).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: isMyClaim ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isMyClaim ? 'Claimed by you' : 'Claimed by ${lead.claimedByEmail ?? 'Member'}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isMyClaim ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      if (lead.phone.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => launchUrl(Uri.parse('tel:${lead.phone}')),
                            icon: const Icon(Icons.phone, size: 18, color: Colors.white),
                            label: Text('Call', style: GoogleFonts.inter(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withOpacity(0.2)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (teamAsync.value != null) ...[
                        if (lead.phone.isNotEmpty) const SizedBox(width: 8),
                        Expanded(
                          child: isClaimed
                              ? (isMyClaim || isOwner)
                                  ? OutlinedButton(
                                      onPressed: onUnclaim,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFEF4444),
                                        side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.5)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text('Unclaim', style: GoogleFonts.inter()),
                                    )
                                  : OutlinedButton(
                                      onPressed: null,
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text('Claimed', style: GoogleFonts.inter()),
                                    )
                              : FilledButton(
                                  onPressed: onClaim,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: Text('Claim Lead', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

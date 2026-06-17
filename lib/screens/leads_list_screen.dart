import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/lead_provider.dart';
import '../providers/activation_provider.dart';
import '../services/team_service.dart';
import '../models/lead_model.dart';
import '../screens/lock_screen.dart';

// ─── Pre-computed TextStyles (avoids GoogleFonts lookup on every build) ──────

final _titleStyle = GoogleFonts.outfit(
  fontWeight: FontWeight.bold,
  fontSize: 18,
  color: Colors.white,
);

final _appBarTitleStyle = GoogleFonts.outfit(
  color: Colors.white,
  fontWeight: FontWeight.bold,
  fontSize: 24,
);

final _bodyStyle = GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13);

final _hintStyle = GoogleFonts.inter(color: const Color(0xFF94A3B8));

final _searchInputStyle = GoogleFonts.inter(color: Colors.white);

// ─── Debouncer ───────────────────────────────────────────────────────────────

class _Debouncer {
  _Debouncer({this.milliseconds = 300});
  final int milliseconds;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

// ─── Leads List Screen ───────────────────────────────────────────────────────

class LeadsListScreen extends ConsumerStatefulWidget {
  const LeadsListScreen({super.key});

  @override
  ConsumerState<LeadsListScreen> createState() => _LeadsListScreenState();
}

class _LeadsListScreenState extends ConsumerState<LeadsListScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String? _filterByMember = 'ALL_MEMBERS';
  final _debouncer = _Debouncer(milliseconds: 300);

  static const _statuses = [
    'All', 'Claimed', 'New', 'Contacted', 'Interested', 'Not Interested', 'Closed'
  ];

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  // Filtering is done here (not in build) so it only runs when state changes
  List<Lead> _filterLeads(List<Lead> leads) {
    if (_searchQuery.isEmpty && _selectedStatus == 'All' && _filterByMember == 'ALL_MEMBERS') {
      return leads;
    }
    return leads.where((l) {
      final matchesStatus = _selectedStatus == 'All' ||
          (_selectedStatus == 'Claimed'
              ? l.claimedBy != null
              : l.leadStatus == _selectedStatus);
      final matchesSearch = _searchQuery.isEmpty ||
          l.businessName.toLowerCase().contains(_searchQuery) ||
          l.keyword.toLowerCase().contains(_searchQuery) ||
          l.phone.contains(_searchQuery);
      final matchesMember =
          _filterByMember == 'ALL_MEMBERS' || l.claimedByEmail == _filterByMember;
      return matchesStatus && matchesSearch && matchesMember;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadListProvider);
    final teamAsync = ref.watch(activeTeamProvider);
    final accessAsync = ref.watch(appAccessProvider);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Leads', style: _appBarTitleStyle),
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
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    style: _searchInputStyle,
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone or keyword...',
                      hintStyle: _hintStyle,
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    // Debounced — avoids rebuilding on every keystroke
                    onChanged: (val) {
                      _debouncer.run(() {
                        if (mounted) setState(() => _searchQuery = val.toLowerCase());
                      });
                    },
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
                        child: _StatusChip(status: status, isSelected: isSelected),
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
          // Background Glows — wrapped in RepaintBoundary so they don't force
          // the list to repaint when scrolling
          const RepaintBoundary(
            child: _BackgroundGlows(),
          ),

          accessAsync.when(
            data: (hasAccess) {
              if (!hasAccess) return const SafeArea(child: LockScreenWidget());
              return leadsAsync.when(
                data: (leads) {
                  final filtered = _filterLeads(leads);

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text(
                            'No leads found.',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    // addRepaintBoundaries: true is the default and helps Flutter
                    // skip repainting cards that are off-screen.
                    itemBuilder: (context, index) {
                      final lead = filtered[index];
                      return _LeadCard(
                        key: ValueKey(lead.id),
                        lead: lead,
                        currentUid: currentUid,
                        teamAsync: teamAsync,
                        onTap: () => GoRouter.of(context).push('/lead_details', extra: lead),
                        onClaim: () async {
                          await ref.read(leadActionsProvider).claimLead(lead.id);
                          if (lead.teamId != null) {
                            try {
                              await TeamService().logActivity(
                                lead.teamId!, lead.businessName, 'Claim',
                                leadPhone: lead.phone,
                              );
                            } catch (_) {}
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lead claimed!'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          }
                        },
                        onUnclaim: () async {
                          await ref.read(leadActionsProvider).unclaimLead(lead.id);
                          if (lead.teamId != null) {
                            try {
                              await TeamService().logActivity(
                                lead.teamId!, lead.businessName, 'Unclaim',
                                leadPhone: lead.phone,
                              );
                            } catch (_) {}
                          }
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                ),
                error: (e, st) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: Color(0xFFEF4444)),
                  ),
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            ),
            error: (_, e) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── Background Glows (static, no backdrop filter needed) ────────────────────

class _BackgroundGlows extends StatelessWidget {
  const _BackgroundGlows();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              // Use a plain color gradient instead of BackdropFilter blur —
              // dramatically cheaper on the GPU.
              gradient: RadialGradient(
                colors: [Color(0x263B82F6), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -100,
          child: Container(
            width: 250,
            height: 250,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x268B5CF6), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Status Chip ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isSelected});

  final String status;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0x333B82F6)
            : Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? const Color(0x803B82F6)
              : Colors.white12,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontFamily: 'Inter',
          color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// ─── Member Filter Button ─────────────────────────────────────────────────────

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
          value: 'ALL_MEMBERS',
          child: Text('Show All', style: GoogleFonts.inter(color: Colors.white)),
        ),
        ...members.map(
          (email) => PopupMenuItem<String?>(
            value: email,
            child: Text(email, style: GoogleFonts.inter(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

// ─── Lead Card ───────────────────────────────────────────────────────────────
// KEY OPTIMISATIONS:
//   • Removed BackdropFilter (was the #1 GPU bottleneck).
//   • TeamService is not re-instantiated in build (passed via constructor values).
//   • Replaced withOpacity() chains with literal hex alpha colors.
//   • ValueKey on card so Flutter can reconcile list diffs cheaply.

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    super.key,
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

  static final _teamService = TeamService();

  Color _statusColor() {
    switch (lead.leadStatus) {
      case 'New':
        return const Color(0xFF3B82F6);
      case 'Contacted':
        return const Color(0xFFF59E0B);
      case 'Interested':
        return const Color(0xFF10B981);
      case 'Closed':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClaimed = lead.claimedBy != null;
    final isMyClaim = lead.claimedBy == currentUid;
    final teamData = teamAsync.value;
    final isOwner = teamData != null && _teamService.isOwner(teamData);
    final statusColor = _statusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        // Solid semi-transparent color — no BackdropFilter needed.
        color: const Color(0xFF1A2540),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClaimed
              ? const Color(0x4D10B981) // 0.3 opacity
              : const Color(0x1AFFFFFF), // 0.1 opacity
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
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
                      style: _titleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: lead.leadStatus, color: statusColor),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.category_outlined, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      lead.category,
                      style: _bodyStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (lead.rating > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      '${lead.rating} (${lead.reviewCount} reviews)',
                      style: _bodyStyle,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Team Claim Info
              if (teamData != null && isClaimed)
                _ClaimBadge(isMyClaim: isMyClaim, claimedByEmail: lead.claimedByEmail),

              Row(
                children: [
                  if (lead.phone.isNotEmpty)
                    Expanded(
                      child: _CallButton(
                        phone: lead.phone,
                        teamId: lead.teamId,
                        businessName: lead.businessName,
                      ),
                    ),
                  if (teamData != null) ...[
                    if (lead.phone.isNotEmpty) const SizedBox(width: 8),
                    Expanded(
                      child: _ClaimActionButton(
                        isClaimed: isClaimed,
                        isMyClaim: isMyClaim,
                        isOwner: isOwner,
                        onClaim: onClaim,
                        onUnclaim: onUnclaim,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Small extracted widgets (helps Flutter skip their subtree during diffing) ─

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ClaimBadge extends StatelessWidget {
  const _ClaimBadge({required this.isMyClaim, required this.claimedByEmail});
  final bool isMyClaim;
  final String? claimedByEmail;

  @override
  Widget build(BuildContext context) {
    final color = isMyClaim ? const Color(0xFF10B981) : const Color(0xFF60A5FA);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMyClaim
            ? const Color(0x1A10B981)
            : const Color(0x1A3B82F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMyClaim
              ? const Color(0x4D10B981)
              : const Color(0x4D3B82F6),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.person, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMyClaim ? 'Claimed by you' : 'Claimed by ${claimedByEmail ?? 'Member'}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.phone,
    required this.teamId,
    required this.businessName,
  });
  final String phone;
  final String? teamId;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        try {
          final url = Uri.parse('tel:$phone');
          await launchUrl(url);
          if (teamId != null && teamId!.isNotEmpty) {
            await TeamService().logActivity(teamId!, businessName, 'Call', leadPhone: phone);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch dialer')),
            );
          }
        }
      },
      icon: const Icon(Icons.phone, size: 18, color: Colors.white),
      label: const Text('Call', style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0x33FFFFFF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _ClaimActionButton extends StatelessWidget {
  const _ClaimActionButton({
    required this.isClaimed,
    required this.isMyClaim,
    required this.isOwner,
    required this.onClaim,
    required this.onUnclaim,
  });
  final bool isClaimed;
  final bool isMyClaim;
  final bool isOwner;
  final VoidCallback onClaim;
  final VoidCallback onUnclaim;

  @override
  Widget build(BuildContext context) {
    if (!isClaimed) {
      return FilledButton(
        onPressed: onClaim,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text(
          'Claim Lead',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (isMyClaim || isOwner) {
      return OutlinedButton(
        onPressed: onUnclaim,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEF4444),
          side: const BorderSide(color: Color(0x80EF4444)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text('Unclaim', style: TextStyle(fontFamily: 'Inter')),
      );
    }

    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: const Text('Claimed', style: TextStyle(fontFamily: 'Inter')),
    );
  }
}

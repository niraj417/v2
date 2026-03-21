import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/team_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: TeamService().getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
          }
          if (snapshot.hasError) {
             return Center(child: Text('Error loading notifications', style: GoogleFonts.inter(color: Colors.red)));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Container(
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       color: Colors.white.withValues(alpha: 0.05),
                     ),
                     child: const Icon(Icons.notifications_off_outlined, color: Color(0xFF64748B), size: 60),
                   ),
                   const SizedBox(height: 24),
                   Text('No new notifications', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 16)),
                 ],
               ),
             );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              if (data['type'] == 'team_invite') {
                 return _buildInviteCard(context, doc.id, data);
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }

  Widget _buildInviteCard(BuildContext context, String notifId, Map<String, dynamic> data) {
    final teamName = data['teamName'] ?? 'A team';
    final inviter = data['inviterEmail'] ?? 'Someone';
    final teamId = data['teamId'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Container(
                 padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(
                   color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                   shape: BoxShape.circle,
                 ),
                 child: const Icon(Icons.group_add, color: Color(0xFF60A5FA), size: 24),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Text(
                   'Team Invitation',
                   style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                 ),
               ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$inviter has invited you to join their team "$teamName".',
            style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
               TextButton(
                 onPressed: () async {
                   try {
                     await TeamService().declineInvite(notifId);
                   } catch (_) {}
                 },
                 child: Text('Decline', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
               ),
               const SizedBox(width: 12),
               ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF3B82F6),
                   foregroundColor: Colors.white,
                   elevation: 0,
                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 ),
                 onPressed: () async {
                   if (teamId != null) {
                     try {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepting...')));
                        await TeamService().acceptInvite(notifId, teamId);
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined team!')));
                        }
                     } catch (e) {
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                     }
                   }
                 },
                 child: Text('Accept', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
               ),
            ],
          )
        ],
      ),
    );
  }
}

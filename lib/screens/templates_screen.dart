import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/template_model.dart';
import '../services/template_service.dart';
import '../services/team_service.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final TeamService _teamService = TeamService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Message Templates', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Ambience
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF3B82F6).withOpacity(0.15)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          StreamBuilder<QuerySnapshot>(
            stream: _teamService.getUserTeams(),
            builder: (context, teamSnapshot) {
              if (teamSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
              }
              final teams = teamSnapshot.data?.docs ?? [];
              if (teams.isEmpty) {
                return Center(
                  child: Text('You need to join or create a team first.', 
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
                );
              }
              
              final teamId = teams.first.id;
              
              return _buildTemplatesList(teamId);
            },
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: _teamService.getUserTeams(),
        builder: (context, teamSnapshot) {
          final teams = teamSnapshot.data?.docs ?? [];
          if (teams.isEmpty) return const SizedBox.shrink();
          final teamId = teams.first.id;
          
          return FloatingActionButton(
            backgroundColor: const Color(0xFF3B82F6),
            onPressed: () => _showAddTemplateDialog(context, teamId),
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }

  Widget _buildTemplatesList(String teamId) {
    return StreamBuilder<List<MessageTemplate>>(
      stream: TemplateService.instance.getTemplatesStream(teamId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
        }
        final templates = snapshot.data ?? [];
        if (templates.isEmpty) {
          return Center(
            child: Text('No templates found. Create one to get started!',
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 16)),
          );
        }
        
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: templates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final template = templates[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(template.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                        onPressed: () => _confirmDelete(context, teamId, template.id),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(template.content, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: template.platforms.map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: p == 'WhatsApp' ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(p, style: GoogleFonts.inter(color: p == 'WhatsApp' ? const Color(0xFF10B981) : const Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w600)),
                    )).toList(),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddTemplateDialog(BuildContext context, String teamId) {
    final nameController = TextEditingController();
    final contentController = TextEditingController();
    bool isWhatsApp = true;
    bool isSms = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Text('New Template', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Template Name',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF64748B))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3B82F6))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message Content',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF64748B))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3B82F6))),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('Platforms:', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  CheckboxListTile(
                    title: const Text('WhatsApp', style: TextStyle(color: Colors.white)),
                    value: isWhatsApp,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) => setState(() => isWhatsApp = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('SMS', style: TextStyle(color: Colors.white)),
                    value: isSms,
                    activeColor: const Color(0xFF3B82F6),
                    onChanged: (val) => setState(() => isSms = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext), 
                child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8)))
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                onPressed: () async {
                  if (nameController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                    return;
                  }
                  if (!isWhatsApp && !isSms) {
                    return;
                  }
                  
                  final platforms = <String>[];
                  if (isWhatsApp) platforms.add('WhatsApp');
                  if (isSms) platforms.add('SMS');
                  
                  try {
                    await TemplateService.instance.addTemplate(
                      teamId, 
                      nameController.text.trim(), 
                      contentController.text.trim(), 
                      platforms
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                      );
                    }
                  }
                },
                child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _confirmDelete(BuildContext context, String teamId, String templateId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Delete Template?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('This will delete the template for your entire team. Are you sure?', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8)))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await TemplateService.instance.deleteTemplate(teamId, templateId);
            }, 
            child: Text('Delete', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold))
          ),
        ],
      )
    );
  }
}

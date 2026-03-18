import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../models/lead_model.dart';
import '../providers/lead_provider.dart';

class PipelineScreen extends ConsumerStatefulWidget {
  const PipelineScreen({super.key});

  @override
  ConsumerState<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends ConsumerState<PipelineScreen> {
  final List<String> _stages = ['New', 'Contacted', 'Interested', 'Closed', 'Not Interested'];

  @override
  Widget build(BuildContext context) {
    final leadsState = ref.watch(leadListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Pipeline Dashboard', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Ambient Background Glows
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3B82F6),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: leadsState.when(
              data: (leads) {
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _stages.length,
                  itemBuilder: (context, index) {
                    final stage = _stages[index];
                    final stageLeads = leads.where((l) => l.leadStatus == stage).toList();
                    
                    return _buildKanbanColumn(stage, stageLeads);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
              error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn(String stage, List<Lead> leads) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DragTarget<Lead>(
        onAcceptWithDetails: (details) {
          final lead = details.data;
          if (lead.leadStatus != stage) {
            ref.read(leadListProvider.notifier).updateLeadStatus(lead.id, stage);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: candidateData.isNotEmpty 
                      ? Colors.white.withValues(alpha: 0.1) 
                      : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stage,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStageColor(stage).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getStageColor(stage).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '${leads.length}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _getStageColor(stage)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: leads.length,
                  itemBuilder: (context, index) {
                    final lead = leads[index];
                    return Draggable<Lead>(
                      data: lead,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 260,
                          child: _buildLeadCard(lead, isDragging: true),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _buildLeadCard(lead),
                      ),
                      child: _buildLeadCard(lead),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeadCard(Lead lead, {bool isDragging = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slightly lighter state for visibility
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDragging ? _getStageColor(lead.leadStatus) : Colors.white.withValues(alpha: 0.1)),
        boxShadow: isDragging ? [
          BoxShadow(
            color: _getStageColor(lead.leadStatus).withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          )
        ] : [],
      ),
      child: InkWell(
        onTap: () {
          context.push('/lead_details', extra: lead);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _getStageColor(lead.leadStatus).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Status: ${lead.leadStatus}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _getStageColor(lead.leadStatus),
                  ),
                ),
              ),
              Text(
                lead.businessName,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, 
                  fontSize: 15,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, size: 12, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(lead.phone, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                lead.keyword,
                style: GoogleFonts.inter(
                  color: Colors.blueAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStageColor(String stage) {
    switch (stage) {
      case 'New': return Colors.blueAccent;
      case 'Contacted': return Colors.orangeAccent;
      case 'Interested': return Colors.purpleAccent;
      case 'Closed': return Colors.greenAccent;
      case 'Not Interested': return Colors.redAccent;
      default: return Colors.white54;
    }
  }
}

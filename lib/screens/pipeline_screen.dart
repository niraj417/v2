import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      appBar: AppBar(
        title: const Text('Pipeline Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: leadsState.when(
        data: (leads) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            itemCount: _stages.length,
            itemBuilder: (context, index) {
              final stage = _stages[index];
              final stageLeads = leads.where((l) => l.leadStatus == stage).toList();
              
              return _buildKanbanColumn(stage, stageLeads);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildKanbanColumn(String stage, List<Lead> leads) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
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
                      ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) 
                      : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    top: BorderSide(color: Colors.grey.withOpacity(0.1)),
                    left: BorderSide(color: Colors.grey.withOpacity(0.1)),
                    right: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stage,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${leads.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDragging ? 8 : 1,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
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
              Text(
                lead.businessName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(lead.phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                lead.keyword,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
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
}

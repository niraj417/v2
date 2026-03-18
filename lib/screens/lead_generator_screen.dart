import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/lead_provider.dart';
import '../providers/history_provider.dart';
import '../providers/scraper_provider.dart';
import '../services/scraper/scraper_engine.dart';

class LeadGeneratorScreen extends ConsumerStatefulWidget {
  const LeadGeneratorScreen({super.key});

  @override
  ConsumerState<LeadGeneratorScreen> createState() => _LeadGeneratorScreenState();
}

class _LeadGeneratorScreenState extends ConsumerState<LeadGeneratorScreen> {
  final _keywordController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isLoading = false;
  int? _lastGeneratedCount;

  @override
  void dispose() {
    _keywordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _generateLeads() async {
    final keyword = _keywordController.text.trim();
    final location = _locationController.text.trim();

    if (keyword.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both keyword and location'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _lastGeneratedCount = null;
    });

    final engine = ref.read(scraperEngineProvider);
    
    try {
      await engine.scrape(
        keyword, 
        location, 
        targetCount: 50, 
        onProgress: (status) {
          ref.read(scraperStatusProvider.notifier).updateStatus(status);
          
          if (status.isComplete) {
            setState(() {
              _lastGeneratedCount = status.importedCount;
              _isLoading = false;
            });
            // Refresh providers
            ref.read(leadListProvider.notifier).loadLeads();
            ref.read(historyProvider.notifier).loadHistory();
            
            if (status.isError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Scraping error: ${status.currentAction}'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scraperStatus = ref.watch(scraperStatusProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Lead Pulse', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.primaryContainer.withValues(alpha: 0.05),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 120),
                Hero(
                  tag: 'generator_title',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      'Universal Search',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Powered by Apify Cloud Engine',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                
                _buildInputCard(theme),
                
                const SizedBox(height: 32),

                if (_isLoading) _buildProgressCard(theme, scraperStatus),

                if (_lastGeneratedCount != null) _buildSuccessCard(theme),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            label: 'Business Category',
            controller: _keywordController,
            hint: 'e.g. Real Estate, Software...',
            icon: Icons.search_rounded,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Region',
            controller: _locationController,
            hint: 'e.g. New York, London...',
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: 32),
          if (_isLoading)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () { 
                  ref.read(scraperEngineProvider).stop(); 
                  setState(() { _isLoading = false; }); 
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.stop_circle_rounded, color: Colors.white),
                label: Text(
                  'Stop Generation',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _generateLeads,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  'Search & Extract',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(ThemeData theme, ScraperStatus status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Engine Working',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      status.currentAction,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: status.importedCount > 0 ? (status.importedCount / 50) : null,
              minHeight: 8,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat('Discovered', status.foundCount.toString()),
              _buildStat('Imported', '${status.importedCount}/50'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
        Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSuccessCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Successfully harvested $_lastGeneratedCount verified leads in ${_locationController.text}.',
              style: GoogleFonts.inter(
                color: Colors.green.shade900,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

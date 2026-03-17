import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        const SnackBar(content: Text('Please enter both keyword and location')),
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
          ref.read(scraperStatusProvider.notifier).state = status;
          
          if (status.isComplete) {
            setState(() {
              _lastGeneratedCount = status.importedCount;
              _isLoading = false;
            });
            // Refresh providers
            ref.read(leadListProvider.notifier).loadLeads();
            ref.read(historyProvider.notifier).loadHistory();
          }
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating leads: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scraperStatus = ref.watch(scraperStatusProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Leads', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Find Local Businesses',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a target keyword and location to automatically discover and extract business data into your CRM.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              
              const Text('Target Keyword', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _keywordController,
                decoration: InputDecoration(
                  hintText: 'e.g. Dentist, Plumber, Marketing Agency',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              const SizedBox(height: 24),
              
              const Text('Target Location', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'e.g. Kolkata, New York, London',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _generateLeads,
                  icon: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _isLoading ? 'Extracting Data...' : 'Generate Leads',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              if (_isLoading) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              scraperStatus.currentAction,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: scraperStatus.importedCount > 0 ? (scraperStatus.importedCount / 50) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Found: ${scraperStatus.foundCount}'),
                          Text('Imported: ${scraperStatus.importedCount} / 50'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              if (_lastGeneratedCount != null) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Successfully discovered and stored $_lastGeneratedCount unique leads.',
                          style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

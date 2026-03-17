import 'dart:async';
import 'dart:math';
import '../../models/lead_model.dart';
import 'search_url_builder.dart';
import 'webview_controller.dart';
import 'lead_formatter.dart';
import 'duplicate_filter.dart';
import '../database_service.dart';

class ScraperStatus {
  final int foundCount;
  final int importedCount;
  final String currentAction;
  final bool isComplete;
  final bool isError;

  ScraperStatus({
    this.foundCount = 0,
    this.importedCount = 0,
    this.currentAction = '',
    this.isComplete = false,
    this.isError = false,
  });
}

class ScraperEngine {
  final ScraperWebviewController webviewController;
  final DuplicateFilter _duplicateFilter = DuplicateFilter();
  final _random = Random();

  ScraperEngine(this.webviewController);

  /// Main scraping loop that handles navigation, scrolling, and extraction.
  Future<void> scrape(
    String keyword, 
    String location, 
    {int targetCount = 100, void Function(ScraperStatus)? onProgress}
  ) async {
    _duplicateFilter.clear();
    int imported = 0;
    int found = 0;

    try {
      onProgress?.call(ScraperStatus(currentAction: 'Building search URL...'));
      final url = SearchUrlBuilder.build(keyword, location);
      
      onProgress?.call(ScraperStatus(currentAction: 'Loading Google Maps...'));
      await webviewController.loadUrl(url);

      // Initial wait for page rendering and consent handling (if any)
      await Future.delayed(const Duration(seconds: 6));

      bool endReached = false;
      int scrollAttempts = 0;

      while (imported < targetCount && !endReached && scrollAttempts < 150) {
        onProgress?.call(ScraperStatus(
          foundCount: found,
          importedCount: imported,
          currentAction: 'Extracting listings...',
        ));

        final listings = await webviewController.extractListings();
        found = listings.length;

        for (var data in listings) {
          final lead = LeadFormatter.format(data, keyword, location);
          
          if (_duplicateFilter.isNew(lead.id)) {
            try {
              // Database handles internal deduplication as well
              await DatabaseService.instance.insertLead(lead);
              imported++;
              
              onProgress?.call(ScraperStatus(
                foundCount: found,
                importedCount: imported,
                currentAction: 'Discovered: ${lead.businessName}',
              ));

              if (imported >= targetCount) break;
            } catch (e) {
              // Skip failed inserts
            }
          }
        }

        if (imported >= targetCount) break;

        onProgress?.call(ScraperStatus(
          foundCount: found,
          importedCount: imported,
          currentAction: 'Scrolling to load more results...',
        ));

        final canScrollPredict = await webviewController.scrollDown();
        
        // Wait for lazy loading to trigger
        await Future.delayed(Duration(milliseconds: 2000 + _random.nextInt(2000)));
        
        if (!canScrollPredict) {
          endReached = await webviewController.isEndReached();
        }
        
        scrollAttempts++;
      }

      onProgress?.call(ScraperStatus(
        foundCount: found,
        importedCount: imported,
        currentAction: 'Scraping session finished successfully.',
        isComplete: true,
      ));

      if (imported > 0) {
        await DatabaseService.instance.insertSearchHistory(keyword, location, imported);
      }
      
    } catch (e) {
      onProgress?.call(ScraperStatus(
        foundCount: found,
        importedCount: imported,
        currentAction: 'Error during scraping: $e',
        isComplete: true,
        isError: true,
      ));
    }
  }
}

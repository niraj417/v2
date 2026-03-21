import 'dart:async';
import 'dart:math';
import 'search_url_builder.dart';
import 'webview_controller.dart';
import 'lead_formatter.dart';
import 'duplicate_filter.dart';
import '../database_service.dart';
import '../firebase_lead_service.dart';
import 'apify_service.dart';

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
  final ApifyService? apifyService;
  final DuplicateFilter _duplicateFilter = DuplicateFilter();
  final _random = Random();
  String? _teamId;

  bool _isCancelled = false;

  ScraperEngine(this.webviewController, {this.apifyService, String? teamId})
      : _teamId = teamId;

  void stop() {
    _isCancelled = true;
  }

  void setTeamId(String? teamId) {
    _teamId = teamId;
  }

  /// Main scraping loop that handles navigation, scrolling, and extraction.
  Future<void> scrape(
    String keyword,
    String location, {
    int targetCount = 100,
    void Function(ScraperStatus)? onProgress,
  }) async {
    _isCancelled = false;
    _duplicateFilter.clear();
    int imported = 0;
    int found = 0;

    if (apifyService != null) {
      await _scrapeWithApify(keyword, location, targetCount, onProgress);
      return;
    }

    try {
      onProgress?.call(ScraperStatus(currentAction: 'Building search URL...'));
      final url = SearchUrlBuilder.build(keyword, location);

      onProgress
          ?.call(ScraperStatus(currentAction: 'Loading Google Maps...'));
      await webviewController.loadUrl(url);

      await Future.delayed(const Duration(seconds: 6));

      bool endReached = false;
      int scrollAttempts = 0;

      while (imported < targetCount &&
          !endReached &&
          scrollAttempts < 150) {
        if (_isCancelled) throw Exception('Cancelled by user');

        onProgress?.call(ScraperStatus(
          foundCount: found,
          importedCount: imported,
          currentAction: 'Extracting listings...',
        ));

        final listings = await webviewController.extractListings();
        found = listings.length;

        for (var data in listings) {
          if (_isCancelled) throw Exception('Cancelled by user');
          final lead = LeadFormatter.format(data, keyword, location);

          if (_duplicateFilter.isNew(lead.id)) {
            try {
              await FirebaseLeadService.instance.addLead(lead, teamId: _teamId);
              imported++;

              onProgress?.call(ScraperStatus(
                foundCount: found,
                importedCount: imported,
                currentAction: 'Discovered: ${lead.businessName}',
              ));

              if (imported >= targetCount) break;
            } catch (e) {
              // Skip individual insert failures
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
        await Future.delayed(
            Duration(milliseconds: 2000 + _random.nextInt(2000)));

        if (!canScrollPredict) {
          endReached = await webviewController.isEndReached();
        }

        scrollAttempts++;
      }

      if (imported > 0) {
        // Keep search history in local SQLite (lightweight, not team-critical)
        await DatabaseService.instance.insertSearchHistory(
            keyword, location, imported);
      }

      onProgress?.call(ScraperStatus(
        foundCount: found,
        importedCount: imported,
        currentAction: _isCancelled
            ? 'Scraping stopped by user.'
            : 'Scraping session finished successfully.',
        isComplete: true,
      ));
    } catch (e) {
      onProgress?.call(ScraperStatus(
        foundCount: found,
        importedCount: imported,
        currentAction: 'Scraping stopped: $e',
        isComplete: true,
        isError: !e.toString().contains('Cancelled'),
      ));
    }
  }

  Future<void> _scrapeWithApify(
    String keyword,
    String location,
    int targetCount,
    void Function(ScraperStatus)? onProgress,
  ) async {
    try {
      onProgress?.call(
          ScraperStatus(currentAction: 'Starting Apify Cloud Actor...'));
      final runId = await apifyService!
          .startScrape(keyword, location, maxResults: targetCount);

      onProgress?.call(ScraperStatus(
          currentAction: 'Actor running. Waiting for results...'));
      final runData = await apifyService!
          .waitForCompletion(runId, isCancelled: () => _isCancelled);

      onProgress?.call(
          ScraperStatus(currentAction: 'Processing results...'));
      final datasetId = runData['defaultDatasetId'];
      final leads =
          await apifyService!.fetchResults(datasetId, keyword, location);

      // Reset duplicate filter for this Apify run so placeId-based
      // deduplication matches the WebView path behaviour.
      _duplicateFilter.clear();

      int imported = 0;
      for (var lead in leads) {
        if (_isCancelled) break;
        // Skip in-dataset duplicates (same placeId appearing twice in results)
        if (!_duplicateFilter.isNew(lead.id)) continue;
        try {
          await FirebaseLeadService.instance.addLead(lead, teamId: _teamId);
          imported++;
          onProgress?.call(ScraperStatus(
            foundCount: leads.length,
            importedCount: imported,
            currentAction: 'Imported: ${lead.businessName}',
          ));
        } catch (e) {
          // Skip individual insert failures (e.g. Firestore phone-duplicate guard)
        }
      }

      if (imported > 0) {
        await DatabaseService.instance.insertSearchHistory(
            keyword, location, imported);
      }

      onProgress?.call(ScraperStatus(
        foundCount: leads.length,
        importedCount: imported,
        currentAction: 'Apify scraping finished successfully.',
        isComplete: true,
      ));
    } catch (e) {
      onProgress?.call(ScraperStatus(
        currentAction: 'Apify Error: $e',
        isComplete: true,
        isError: true,
      ));
    }
  }
}

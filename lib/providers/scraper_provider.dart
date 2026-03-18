import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/scraper/webview_controller.dart';
import '../services/scraper/scraper_engine.dart';
import '../services/scraper/apify_service.dart';

// ---------------------------------------------------------------------------
// Apify token — editable by the user from Settings screen.
// Migrated from deprecated StateProvider to Notifier (Riverpod 3).
// ---------------------------------------------------------------------------

class _ApifyTokenNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateToken(String newToken) {
    state = newToken;
  }
}

final apifyTokenProvider = NotifierProvider<_ApifyTokenNotifier, String>(
  _ApifyTokenNotifier.new,
);

// ---------------------------------------------------------------------------
// Apify service — derived from the token; null when token is empty.
// ---------------------------------------------------------------------------

final apifyServiceProvider = Provider<ApifyService?>((ref) {
  final token = ref.watch(apifyTokenProvider);
  if (token.isEmpty) return null;
  return ApifyService(apiToken: token);
});

// ---------------------------------------------------------------------------
// WebView controller — single instance for the background scraper widget.
// ---------------------------------------------------------------------------

final scraperWebviewControllerProvider = Provider<ScraperWebviewController>((ref) {
  return ScraperWebviewController();
});

// ---------------------------------------------------------------------------
// Scraper engine — orchestrates Apify or WebView scraping.
// ---------------------------------------------------------------------------

final scraperEngineProvider = Provider<ScraperEngine>((ref) {
  final controller = ref.watch(scraperWebviewControllerProvider);
  final apifyService = ref.watch(apifyServiceProvider);
  return ScraperEngine(controller, apifyService: apifyService);
});

// ---------------------------------------------------------------------------
// Scraper status — real-time progress updates.
// Migrated from deprecated StateProvider to Notifier (Riverpod 3).
// ---------------------------------------------------------------------------

class _ScraperStatusNotifier extends Notifier<ScraperStatus> {
  @override
  ScraperStatus build() => ScraperStatus(currentAction: 'Idle');

  void updateStatus(ScraperStatus newStatus) {
    state = newStatus;
  }
}

final scraperStatusProvider = NotifierProvider<_ScraperStatusNotifier, ScraperStatus>(
  _ScraperStatusNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/scraper/webview_controller.dart';
import '../services/scraper/scraper_engine.dart';

/// Provider for the [ScraperWebviewController] which manages the WebView instance.
final scraperWebviewControllerProvider = Provider<ScraperWebviewController>((ref) {
  return ScraperWebviewController();
});

/// Provider for the [ScraperEngine] which handles the high-level scraping logic.
final scraperEngineProvider = Provider<ScraperEngine>((ref) {
  final controller = ref.watch(scraperWebviewControllerProvider);
  return ScraperEngine(controller);
});

/// StateProvider to track the real-time status of the scraping process.
final scraperStatusProvider = StateProvider<ScraperStatus>((ref) {
  return ScraperStatus(currentAction: 'Idle');
});

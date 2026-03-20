import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/scraper/webview_controller.dart';
import '../services/scraper/scraper_engine.dart';
import '../services/scraper/apify_service.dart';
import 'lead_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Apify Token ─────────────────────────────────────────────────────────────

class _ApifyTokenNotifier extends Notifier<String> {
  static const _tokenKey = 'apify_token_prefs';

  @override
  String build() {
    _loadToken();
    return '';
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    if (savedToken != null && savedToken.isNotEmpty) {
      state = savedToken;
    }
  }

  Future<void> updateToken(String newToken) async {
    state = newToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, newToken);
  }
}

final apifyTokenProvider = NotifierProvider<_ApifyTokenNotifier, String>(
  _ApifyTokenNotifier.new,
);

// ─── Apify Service ────────────────────────────────────────────────────────────

final apifyServiceProvider = Provider<ApifyService?>((ref) {
  final token = ref.watch(apifyTokenProvider);
  if (token.isEmpty) return null;
  return ApifyService(apiToken: token);
});

// ─── WebView Controller ───────────────────────────────────────────────────────

final scraperWebviewControllerProvider =
    Provider<ScraperWebviewController>((ref) {
  return ScraperWebviewController();
});

// ─── Scraper Engine ───────────────────────────────────────────────────────────

/// Builds the scraper engine and automatically injects the current team ID,
/// so that scraped leads are always saved under the correct team scope.
final scraperEngineProvider = Provider<ScraperEngine>((ref) {
  final controller = ref.watch(scraperWebviewControllerProvider);
  final apifyService = ref.watch(apifyServiceProvider);
  final teamAsync = ref.watch(activeTeamProvider);

  final teamId = teamAsync.value?['id'] as String?;
  return ScraperEngine(controller, apifyService: apifyService, teamId: teamId);
});

// ─── Scraper Status ───────────────────────────────────────────────────────────

class _ScraperStatusNotifier extends Notifier<ScraperStatus> {
  @override
  ScraperStatus build() => ScraperStatus(currentAction: 'Idle');

  void updateStatus(ScraperStatus newStatus) {
    state = newStatus;
  }
}

final scraperStatusProvider =
    NotifierProvider<_ScraperStatusNotifier, ScraperStatus>(
  _ScraperStatusNotifier.new,
);

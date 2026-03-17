import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'scraper_scripts.dart';

class ScraperWebviewController {
  InAppWebViewController? webViewController;
  final Completer<void> _readyCompleter = Completer<void>();

  /// Future that completes when the [InAppWebViewController] is initialized.
  Future<void> get isReady => _readyCompleter.future;

  /// Callback to be passed to the InAppWebView's onWebViewCreated.
  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }

  /// Navigates to the specified URL.
  Future<void> loadUrl(String url) async {
    await isReady;
    await webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
  }

  /// Scrolls the results list down by a random amount.
  /// Returns false if it appears we are at the bottom of the current feed.
  Future<bool> scrollDown() async {
    await isReady;
    try {
      final result = await webViewController?.evaluateJavascript(source: ScraperScripts.autoScroll);
      if (result != null && result is Map && result['success'] == true) {
        return !result['atBottom'];
      }
    } catch (e) {
      // Log or handle JS execution errors
    }
    return false;
  }

  /// Checks if the "End of results" indicator is present on the page.
  Future<bool> isEndReached() async {
    await isReady;
    try {
      final result = await webViewController?.evaluateJavascript(source: ScraperScripts.checkEndReached);
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Executes the listing extraction script and returns a list of data maps.
  Future<List<Map<String, dynamic>>> extractListings() async {
    await isReady;
    try {
      final result = await webViewController?.evaluateJavascript(source: ScraperScripts.extractListings);
      if (result is List) {
        return result.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      // Return empty list on failure
    }
    return [];
  }
}

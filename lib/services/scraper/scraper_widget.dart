import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/scraper_provider.dart';

/// A persistent, nearly-hidden WebView widget used for background scraping.
/// This widget should be placed in a high-level layout to maintain state across screens.
class ScraperWidget extends ConsumerWidget {
  const ScraperWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(scraperWebviewControllerProvider);

    return SizedBox(
      height: 1,
      width: 1,
      child: Opacity(
        opacity: 0.01,
        child: IgnorePointer(
          child: InAppWebView(
            initialSettings: InAppWebViewSettings(
              userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
              javaScriptEnabled: true,
              cacheEnabled: true,
              transparentBackground: true,
              disableContextMenu: true,
            ),
            onWebViewCreated: (webViewController) {
              controller.onWebViewCreated(webViewController);
            },
            onConsoleMessage: (controller, consoleMessage) {
              // Useful for debugging in-app scraping logic
              debugPrint("SCRAPER_CONSOLE: ${consoleMessage.message}");
            },
          ),
        ),
      ),
    );
  }
}

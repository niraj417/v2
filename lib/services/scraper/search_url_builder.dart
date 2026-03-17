class SearchUrlBuilder {
  /// Constructs a Google Maps search URL for the given keyword and location.
  /// Sets hl=en to ensure a consistent English DOM structure for parsing.
  static String build(String keyword, String location) {
    final query = '$keyword $location'.trim();
    final encodedQuery = Uri.encodeComponent(query);
    
    // We use the search endpoint which automatically handles location disambiguation
    return 'https://www.google.com/maps/search/$encodedQuery?hl=en';
  }

  /// Builds a URL with specific coordinates and zoom level if available.
  static String buildWithCoords(String keyword, double lat, double lng, {int zoom = 14}) {
    final encodedKeyword = Uri.encodeComponent(keyword);
    return 'https://www.google.com/maps/search/$encodedKeyword/@$lat,$lng,${zoom}z?hl=en';
  }
}

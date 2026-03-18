import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/lead_model.dart';
import 'lead_formatter.dart';

class ApifyService {
  final String apiToken;

  /// Actor ID for the Google Maps scraper:
  /// https://console.apify.com/actors/sbEjxxfeFlEBHijJS
  final String actorId = 'sbEjxxfeFlEBHijJS';

  ApifyService({required this.apiToken});

  /// Builds a Google Maps search URL from a keyword and a plain-text location
  /// by geocoding the location to latitude/longitude using Nominatim.
  /// This is required because actor sbEjxxfeFlEBHijJS needs coordinates in the URL.
  Future<String> _buildGoogleMapsUrl(String keyword, String location) async {
    final geoUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(location)}&format=json&limit=1');
    
    // Default fallback coordinates (e.g. San Francisco)
    String lat = '37.7749';
    String lng = '-122.4194';
    
    try {
      final geoResponse = await http.get(
        geoUrl,
        headers: {'User-Agent': 'CRM_Leads_App/1.0'},
      );
      if (geoResponse.statusCode == 200) {
        final geoData = jsonDecode(geoResponse.body) as List;
        if (geoData.isNotEmpty) {
          lat = geoData[0]['lat'];
          lng = geoData[0]['lon'];
        }
      }
    } catch (e) {
      // Ignore geocoding errors and fallback to default
    }

    final query = Uri.encodeComponent(keyword);
    return 'https://www.google.com/maps/search/$query/@$lat,$lng,13z/data=!3m1!4b1';
  }

  /// Starts the Apify actor with the given [keyword] and [location].
  /// Returns the run ID (String) which is used to poll for completion.
  Future<String> startScrape(
    String keyword,
    String location, {
    int maxResults = 50,
  }) async {
    final url = Uri.parse(
      'https://api.apify.com/v2/acts/$actorId/runs?token=$apiToken',
    );

    final mapsUrl = await _buildGoogleMapsUrl(keyword, location);

    // Input schema as required by actor sbEjxxfeFlEBHijJS
    final input = {
      "search_query": keyword,
      "gmaps_url": mapsUrl,
      "latitude": "",
      "longitude": "",
      "area_width": 20,
      "area_height": 20,
      "max_results": maxResults,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(input),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final runId = data['data']['id'] as String;
      return runId;
    } else {
      throw Exception(
        'Failed to start Apify actor [${response.statusCode}]: ${response.body}',
      );
    }
  }

  /// Polls the actor run status every 5 seconds until it completes.
  /// Returns the full run data map (which contains [defaultDatasetId]).
  Future<Map<String, dynamic>> waitForCompletion(String runId) async {
    final url = Uri.parse(
      'https://api.apify.com/v2/actor-runs/$runId?token=$apiToken',
    );

    const terminalStatuses = {'SUCCEEDED', 'FAILED', 'ABORTED', 'TIMED-OUT'};

    while (true) {
      await Future.delayed(const Duration(seconds: 5));

      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to poll Apify run status [${response.statusCode}]: ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['data']['status'] as String;

      if (status == 'SUCCEEDED') {
        return data['data'] as Map<String, dynamic>;
      } else if (terminalStatuses.contains(status)) {
        throw Exception('Apify actor run ended with status: $status');
      }
      // Otherwise: RUNNING / READY → keep polling
    }
  }

  /// Fetches all items from the dataset produced by the completed actor run.
  Future<List<Lead>> fetchResults(
    String datasetId,
    String keyword,
    String location,
  ) async {
    final url = Uri.parse(
      'https://api.apify.com/v2/datasets/$datasetId/items?token=$apiToken&clean=true',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch Apify dataset [${response.statusCode}]: ${response.body}',
      );
    }

    final List<dynamic> items = jsonDecode(response.body) as List<dynamic>;
    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => LeadFormatter.format(item, keyword, location))
        .toList();
  }
}

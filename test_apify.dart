// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiToken = 'YOUR_APIFY_API_TOKEN';
  final actorId = 'sbEjxxfeFlEBHijJS';
  
  final keyword = 'dentist';
  final location = 'san francisco';
  
  final geoResponse = await http.get(
    Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(location)}&format=json&limit=1'),
    headers: {'User-Agent': 'CRM_Leads_App/1.0'},
  );
  final geoData = jsonDecode(geoResponse.body) as List;
  String lat = '37.7749';
  String lng = '-122.4194';
  if (geoData.isNotEmpty) {
    lat = geoData[0]['lat'];
    lng = geoData[0]['lon'];
  }
  
  final query = Uri.encodeComponent(keyword);
  final mapsUrl = 'https://www.google.com/maps/search/$query/@$lat,$lng,13z/data=!3m1!4b1';

  final input = {
    "search_query": keyword,
    "gmaps_url": mapsUrl,
    "latitude": "",
    "longitude": "",
    "area_width": 20,
    "area_height": 20,
    "max_results": 5,
  };

  print('Starting run...');
  final url = Uri.parse('https://api.apify.com/v2/acts/$actorId/runs?token=$apiToken');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(input),
  );

  print('Status code: ${response.statusCode}');
  print('Resp body: ${response.body}');
  
  if (response.statusCode == 200 || response.statusCode == 201) {
    final data = jsonDecode(response.body);
    final runId = data['data']['id'];
    print('Started run: $runId');
    
    while(true) {
      await Future.delayed(Duration(seconds: 5));
      final statusResp = await http.get(Uri.parse('https://api.apify.com/v2/actor-runs/$runId?token=$apiToken'));
      final statusData = jsonDecode(statusResp.body);
      final status = statusData['data']['status'];
      print('Status: $status');
      if (status == 'SUCCEEDED') {
        final datasetId = statusData['data']['defaultDatasetId'];
        print('Dataset ID: $datasetId');
        
        final datasetResp = await http.get(Uri.parse('https://api.apify.com/v2/datasets/$datasetId/items?token=$apiToken&clean=true'));
        final items = jsonDecode(datasetResp.body) as List;
        print('Items count: ${items.length}');
        if (items.isNotEmpty) {
           print('First item: ${jsonEncode(items.first)}');
        }
        break;
      } else if (['FAILED', 'ABORTED', 'TIMED-OUT'].contains(status)) {
        break;
      }
    }
  }
}

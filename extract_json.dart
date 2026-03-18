// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() async {
  try {
    final file = File('scraper_html.html');
    if (!await file.exists()) {
      print('scraper_html.html not found');
      return;
    }
    
    final html = await file.readAsString();
    
    final startMarker = 'window.APP_INITIALIZATION_STATE=';
    final endMarker = ';window.APP_FLAGS=';
    
    final startIndex = html.indexOf(startMarker);
    if (startIndex == -1) {
      print('APP_INITIALIZATION_STATE not found');
      return;
    }
    
    final dataStartIndex = startIndex + startMarker.length;
    final endIndex = html.indexOf(endMarker, dataStartIndex);
    
    if (endIndex == -1) {
      print('APP_FLAGS not found after APP_INITIALIZATION_STATE');
      return;
    }
    
    final jsonString = html.substring(dataStartIndex, endIndex);
    final data = jsonDecode(jsonString);
    
    print('Data type: ${data.runtimeType}');
    if (data is List) {
      print('List length: ${data.length}');
      for (var i = 0; i < data.length; i++) {
        // print summary of each top level element
        final element = data[i];
        if (element is List) {
           print('Item $i is List of length ${element.length}');
        } else {
           print('Item $i is ${element.runtimeType}');
        }
      }
    }
    
    // Write formatted JSON to file
    final encoder = JsonEncoder.withIndent('  ');
    final formattedJson = encoder.convert(data);
    
    await File('extracted_data.json').writeAsString(formattedJson);
    print('Successfully wrote formatted JSON to extracted_data.json');
    
  } catch (e) {
    print('Error: $e');
  }
}

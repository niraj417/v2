// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('extracted_data.json');
  final content = await file.readAsString();
  final data = jsonDecode(content);
  
  void search(dynamic node, String path) {
    if (node is Map) {
      node.forEach((key, value) {
        search(value, "$path['$key']");
      });
    } else if (node is List) {
      for (var i = 0; i < node.length; i++) {
        search(node[i], "$path[$i]");
      }
    } else if (node is String) {
      if (node.toLowerCase().contains('plumber') || node.toLowerCase().contains('london')) {
        print('Found match at $path: ${node.substring(0, node.length > 50 ? 50 : node.length)}');
      }
    }
  }
  
  search(data, "data");
}

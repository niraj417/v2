import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<Map<String, dynamic>>>(() {
  return HistoryNotifier();
});

class HistoryNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  FutureOr<List<Map<String, dynamic>>> build() async {
    return DatabaseService.instance.getSearchHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => DatabaseService.instance.getSearchHistory());
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lead_provider.dart';

final dashboardStatsProvider = Provider<Map<String, int>>((ref) {
  final leadsState = ref.watch(leadListProvider);

  return leadsState.maybeWhen(
    data: (leads) {
      int total = leads.length;
      int contacted = leads.where((l) => l.leadStatus != 'New').length;
      int converted = leads.where((l) => l.leadStatus == 'Closed').length;

      return {
        'total': total,
        'contacted': contacted,
        'converted': converted,
      };
    },
    orElse: () => {
      'total': 0,
      'contacted': 0,
      'converted': 0,
    },
  );
});

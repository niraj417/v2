import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_stat.dart';

class TeamReportService {
  final _db = FirebaseFirestore.instance;

  Future<List<UserStat>> generateStats(String teamId, String timeFilter) async {
    final now = DateTime.now();
    DateTime startDate;

    if (timeFilter == 'Today') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (timeFilter == 'This Week') {
      final offset = now.weekday - 1;
      startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
    } else if (timeFilter == 'This Month') {
      startDate = DateTime(now.year, now.month, 1);
    } else {
      startDate = DateTime(2000);
    }

    final teamDoc = await _db.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) return [];
    
    final data = teamDoc.data()!;
    final List<dynamic> memberEmails = data['members'] ?? [];
    final String ownerEmail = data['ownerEmail'] ?? '';
    final allEmails = <String>{ownerEmail, ...memberEmails.cast<String>()};

    final logsSnap = await _db
        .collection('teams')
        .doc(teamId)
        .collection('activity_logs')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();

    final leadsSnap = await _db
        .collection('leads')
        .where('teamId', isEqualTo: teamId)
        .get();

    final validLeadsCreated = leadsSnap.docs.where((doc) {
      final leadData = doc.data();
      final createdTs = leadData['createdAt'] as Timestamp?;
      DateTime dateField = createdTs?.toDate() ?? DateTime.now();
      return dateField.isAfter(startDate) || dateField.isAtSameMomentAs(startDate);
    }).toList();

    List<UserStat> stats = [];

    for (var email in allEmails) {
      if (email.isEmpty) continue;
      
      int generated = 0;
      for (var doc in validLeadsCreated) {
        if (doc.data()['addedByEmail'] == email) generated++;
      }

      final claimedSet = <String>{};
      final contactedSet = <String>{};
      final interestedSet = <String>{};
      final closedSet = <String>{};
      final notInterestedSet = <String>{};

      for (var log in logsSnap.docs) {
        final logData = log.data();
        if (logData['callerEmail'] == email) {
          final phone = logData['leadPhone'] as String? ?? '';
          final name = logData['leadName'] as String? ?? 'unknown';
          final leadKey = phone.isNotEmpty ? phone : name;
          final action = logData['action'] as String? ?? '';

          if (action == 'Claim') {
            claimedSet.add(leadKey);
          } else if (action == 'Call' || action == 'Status Update: Contacted') {
            contactedSet.add(leadKey);
          } else if (action == 'Status Update: Interested') {
            interestedSet.add(leadKey);
          } else if (action == 'Status Update: Closed') {
            closedSet.add(leadKey);
          } else if (action == 'Status Update: Not Interested') {
            notInterestedSet.add(leadKey);
          }
        }
      }

      stats.add(UserStat(
        email: email,
        leadsClaimed: claimedSet.length,
        leadsContacted: contactedSet.length,
        leadsInterested: interestedSet.length,
        leadsClosed: closedSet.length,
        leadsNotInterested: notInterestedSet.length,
        leadsGenerated: generated,
      ));
    }

    return stats;
  }
}

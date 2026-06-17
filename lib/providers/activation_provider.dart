import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lead_provider.dart';

final userActivationProvider = StreamProvider<bool>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(false);
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return false;
        final data = doc.data() as Map<String, dynamic>?;
        return data != null && data.containsKey('activationCode') && data['activationCode'] != null && data['activationCode'].toString().isNotEmpty;
      });
});

final ownerActivationProvider = StreamProvider.family<bool, String>((ref, ownerId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(ownerId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return false;
        final data = doc.data() as Map<String, dynamic>?;
        return data != null && data.containsKey('activationCode') && data['activationCode'] != null && data['activationCode'].toString().isNotEmpty;
      });
});

final appAccessProvider = Provider<AsyncValue<bool>>((ref) {
  final userActivated = ref.watch(userActivationProvider);
  
  return userActivated.when(
    data: (isActive) {
      if (isActive) return const AsyncData(true);
      
      // If user is not activated, check their team owner
      final teamAsync = ref.watch(activeTeamProvider);
      return teamAsync.when(
        data: (team) {
          if (team == null) return const AsyncData(false); // No team, no owner to check
          final ownerId = team['ownerId'] as String?;
          if (ownerId == null) return const AsyncData(false);
          
          final ownerActivated = ref.watch(ownerActivationProvider(ownerId));
          return ownerActivated.when(
            data: (ownerActive) => AsyncData(ownerActive),
            loading: () => const AsyncLoading(),
            error: (err, st) => AsyncError(err, st),
          );
        },
        loading: () => const AsyncLoading(),
        error: (err, st) => AsyncError(err, st),
      );
    },
    loading: () => const AsyncLoading(),
    error: (err, st) => AsyncError(err, st),
  );
});

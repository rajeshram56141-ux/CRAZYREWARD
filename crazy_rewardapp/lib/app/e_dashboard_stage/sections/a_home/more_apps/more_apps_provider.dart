import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../b_splash_stage/splash_service.dart';
import 'more_apps_model.dart';

final moreAppsStreamProvider = StreamProvider.autoDispose<List<MoreAppsModel>>((ref) async* {
  if (SplashService.moreApps.isNotEmpty) {
    yield SplashService.moreApps;
  }

  final firestore = FirebaseFirestore.instance;

  // Listen to Firestore collection 'admin' -> doc 'appData' (primary app data)
  final appDataStream = firestore.collection('admin').doc('appData').snapshots();
  await for (final snap in appDataStream) {
    if (snap.exists && snap.data() != null) {
      final data = snap.data()!;
      final List<dynamic>? rawList = data['moreApps'] ?? data['ourApps'] ?? data['moreAppsList'] ?? data['apps'];
      if (rawList != null && rawList.isNotEmpty) {
        final list = rawList
            .whereType<Map>()
            .map((e) => MoreAppsModel.fromMap(Map<String, dynamic>.from(e)))
            .where((e) => e.enabled)
            .toList();
        if (list.isNotEmpty) {
          yield list;
          continue;
        }
      }
    }

    // Secondary check: /admin/moreApps
    try {
      final moreAppsSnap = await firestore.collection('admin').doc('moreApps').get();
      if (moreAppsSnap.exists && moreAppsSnap.data() != null) {
        final data = moreAppsSnap.data()!;
        final List<dynamic>? rawList = data['apps'] ?? data['moreApps'] ?? data['list'];
        if (rawList != null && rawList.isNotEmpty) {
          final list = rawList
              .whereType<Map>()
              .map((e) => MoreAppsModel.fromMap(Map<String, dynamic>.from(e)))
              .where((e) => e.enabled)
              .toList();
          if (list.isNotEmpty) {
            yield list;
            continue;
          }
        }
      }
    } catch (_) {}

    // Tertiary check: root collection /moreApps
    try {
      final collSnap = await firestore.collection('moreApps').get();
      if (collSnap.docs.isNotEmpty) {
        final list = collSnap.docs
            .map((doc) => MoreAppsModel.fromMap({'id': doc.id, ...doc.data()}))
            .where((e) => e.enabled)
            .toList();
        if (list.isNotEmpty) {
          yield list;
          continue;
        }
      }
    } catch (_) {}

    yield SplashService.moreApps;
  }
});

final moreAppsProvider = Provider<List<MoreAppsModel>>((ref) {
  ref.watch(SplashService.appDataProvider);
  final streamData = ref.watch(moreAppsStreamProvider);
  return streamData.maybeWhen(
    data: (data) => data.isNotEmpty ? data : SplashService.moreApps,
    orElse: () => SplashService.moreApps,
  );
});

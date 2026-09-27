import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../../../services/cloud_functions.dart';
import 'daily_challenge_model.dart';

final dailyChallengeProvider = FutureProvider.family
    .autoDispose<DailyChallengeData?, String>((ref, userId) async {
  try {
    final res = await CloudFunctions.getDailyChallengeStatus();
    if (res['success'] == true && res['data'] is Map<String, dynamic>) {
      return DailyChallengeData.fromJson(res['data'] as Map<String, dynamic>);
    }
  } catch (e) {
    // Return null on failure
  }
  return null;
});

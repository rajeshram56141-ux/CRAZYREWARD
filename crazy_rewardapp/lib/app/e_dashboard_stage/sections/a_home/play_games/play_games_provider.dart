import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../services/security_service.dart';
import '../../../../../../utils/constant/constant.dart';
import 'play_games_model.dart';

final playGamesProvider = FutureProvider.autoDispose.family<List<PlayGamesModel>, String>((
  ref,
  userId,
) async {
  final Dio dio = Dio();
  final effectiveUserId = userId.trim();

  final rawInput = {
    'userId': effectiveUserId,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };

  final encryptedPayload = SecurityService.encryptPayload(rawInput, userId: effectiveUserId);

  try {
    final Response response = await dio.post(
      AppConst.fetchGames,
      data: {'payload': encryptedPayload},
      options: Options(
        headers: {
          ...AppConst.apiHeader,
          if (effectiveUserId.isNotEmpty) 'x-user-id': effectiveUserId,
        },
        sendTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
      ),
    );

    Map<String, dynamic> data = response.data is Map<String, dynamic>
        ? response.data
        : jsonDecode(response.data.toString());

    if (data['responsePayload'] != null) {
      final decryptedStr = SecurityService.decryptPayload(
        data['responsePayload'].toString(),
        userId: effectiveUserId,
      );
      if (decryptedStr.isNotEmpty) {
        data = Map<String, dynamic>.from(jsonDecode(decryptedStr));
      }
    }

    if (response.statusCode == 200 && data['success'] == true) {
      return List<PlayGamesModel>.from(
        (data['games'] as List? ?? []).map((x) => PlayGamesModel.fromJson(x)),
      );
    }

    return [];
  } catch (_) {
    return [];
  }
});

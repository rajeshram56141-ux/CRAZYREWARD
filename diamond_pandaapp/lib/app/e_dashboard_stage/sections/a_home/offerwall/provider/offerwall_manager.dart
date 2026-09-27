import 'dart:math';

import 'package:flutter/material.dart';

import '../model/offerwall_data_model.dart';
import 'offerwall_provider.dart';

class OfferwallManager {
  static final OfferwallManager _instance = OfferwallManager._internal();
  factory OfferwallManager() => _instance;
  OfferwallManager._internal();

  static final Map<TaskName, OfferwallProvider> _taskOffers = {
    TaskName.growDeck: GrowDeckTaskProvider(),
    TaskName.playtimeAds: PlaytimeAdsTaskProvider(),
    TaskName.pubscale: PubscaleTaskProvider(),
    TaskName.bitlabs: BitlabsSurveyProvider(),
    TaskName.cpxResearch: CpxResearchSurveyProvider(),
    TaskName.timewall: WebViewTaskProvider(
      name: 'Timewall',
      gradient: [Color.fromRGBO(0, 123, 255, 1), Color.fromRGBO(1, 85, 175, 1)],
    ),
    TaskName.tapjoy: WebViewTaskProvider(
      name: 'Tapjoy',
      gradient: [Color.fromRGBO(174, 29, 29, 1), Color.fromRGBO(255, 0, 0, 1)],
    ),
    TaskName.adjoe: WebViewTaskProvider(
      name: 'Adjoe',
      gradient: [
        Color.fromRGBO(99, 94, 255, 1),
        Color.fromRGBO(89, 86, 176, 1),
      ],
    ),
    TaskName.cpidroid: WebViewTaskProvider(
      name: 'CpiDroid',
      gradient: [Color.fromRGBO(54, 179, 74, 1), Color.fromRGBO(0, 127, 89, 1)],
    ),
    TaskName.lootably: WebViewTaskProvider(
      name: 'Lootably',
      gradient: [Color.fromRGBO(236, 97, 91, 1), Color.fromRGBO(132, 5, 0, 1)],
    ),
    TaskName.notik: WebViewTaskProvider(
      name: 'Notik',
      gradient: [
        Color.fromRGBO(75, 170, 176, 1),
        Color.fromRGBO(0, 116, 123, 1),
      ],
    ),
    TaskName.sushiAds: WebViewTaskProvider(
      name: 'SushiAds',
      gradient: [
        Color.fromRGBO(255, 182, 0, 1),
        Color.fromRGBO(255, 237, 81, 1),
      ],
    ),
    TaskName.taskwall: WebViewTaskProvider(
      name: 'Taskwall',
      gradient: [Color.fromRGBO(0, 102, 222, 1), Color.fromRGBO(0, 55, 120, 1)],
    ),
    TaskName.wannads: WebViewTaskProvider(
      name: 'Wannads',
      gradient: [Color.fromRGBO(255, 154, 0, 1), Color.fromRGBO(134, 81, 0, 1)],
    ),
  };

  static final Map<SurveyName, OfferwallProvider> _surveyOffers = {
    SurveyName.bitlabs: BitlabsSurveyProvider(),
    SurveyName.cpxResearch: CpxResearchSurveyProvider(),
    SurveyName.timewall: WebViewTaskProvider(
      name: 'Timewall',
      gradient: [Color.fromRGBO(0, 123, 255, 1), Color.fromRGBO(1, 85, 175, 1)],
    ),
    SurveyName.wannads: WebViewTaskProvider(
      name: 'Wannads',
      gradient: [Color.fromRGBO(255, 154, 0, 1), Color.fromRGBO(134, 81, 0, 1)],
    ),
    SurveyName.tapjoy: WebViewTaskProvider(
      name: 'Tapjoy',
      gradient: [Color.fromRGBO(174, 29, 29, 1), Color.fromRGBO(255, 0, 0, 1)],
    ),
    SurveyName.cpidroid: WebViewTaskProvider(
      name: 'CpiDroid',
      gradient: [Color.fromRGBO(54, 179, 74, 1), Color.fromRGBO(0, 127, 89, 1)],
    ),
     SurveyName.theoremReach: WebViewTaskProvider(
      name: 'TheoremReach',
      gradient: [Colors.white, Colors.white],
    ),
  };

  static List<OfferwallProvider> _orderedSurveyOffers = [];
  static List<OfferwallProvider> _orderedTaskOffers = [];

  static void arrangeOffers({
    required List<OffersDataModel> surveyList,
    required List<OffersDataModel> taskList,
    int? shuffleSeed,
  }) {
    final rnd = shuffleSeed != null ? Random(shuffleSeed) : Random();

    List<OfferwallProvider> arrangeGeneric(
      List<OffersDataModel> models,
      Map<dynamic, OfferwallProvider> providerMap,
    ) {
      final Map<int, List<OfferwallProvider>> buckets = {};
      final disabled = <OfferwallProvider>[];

      for (final cfg in models) {
        OfferwallProvider? provider;
        final cleanName = cfg.providerName.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');

        // Match existing enum provider
        for (final entry in providerMap.entries) {
          final cleanEnumName = entry.key.toString().split('.').last.toLowerCase();
          if (cleanEnumName == cleanName) {
            provider = entry.value;
            break;
          }
        }

        // Dynamically instantiate a WebViewTaskProvider if it is custom
        if (provider == null) {
          provider = WebViewTaskProvider(
            name: cfg.providerName,
            gradient: const [Color(0xFF222B21), Color(0xFF151A14)], // Dark sage colors to match app theme
          );
        }

        provider.attachConfig(cfg);

        if (!cfg.enabled) {
          provider.enabled = false;
          disabled.add(provider);
          continue;
        }

        buckets
            .putIfAbsent(cfg.rank, () => <OfferwallProvider>[])
            .add(provider);
      }

      final ordered = <OfferwallProvider>[];
      final ranks = buckets.keys.toList()..sort();

      for (final r in ranks) {
        final group = buckets[r]!;
        if (group.length > 1) group.shuffle(rnd);
        ordered.addAll(group);
      }

      ordered.addAll(disabled);
      return ordered;
    }

    _orderedSurveyOffers = arrangeGeneric(surveyList, _surveyOffers);
    _orderedTaskOffers = arrangeGeneric(taskList, _taskOffers);
  }

  static Future<void> initAll({required String userId}) async {
    final allProviders = [..._taskOffers.values, ..._surveyOffers.values];
    for (final provider in allProviders) {
      await provider.init(userId: userId);
    }
  }

  static List<OfferwallProvider> getOffersByCategory({
    required OfferwallCategory category,
  }) {
    final rawList = category == OfferwallCategory.survey
        ? _orderedSurveyOffers
        : _orderedTaskOffers;
    final enabledList = rawList.where((e) => e.enabled).toList();
    final disabledList = rawList.where((e) => !e.enabled).toList();
    return [...enabledList, ...disabledList];
  }

  static OfferwallProvider? getOfferByName(dynamic name) {
    if (name is TaskName) return _taskOffers[name];
    if (name is SurveyName) return _surveyOffers[name];
    return null;
  }

  static OfferwallProvider? getProviderByName(String name) {
    final cleanName = name.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
    for (final entry in _taskOffers.entries) {
      final cleanEnumName = entry.key.toString().split('.').last.toLowerCase();
      final cleanProviderName = entry.value.name.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
      if (cleanEnumName == cleanName || cleanProviderName == cleanName) {
        return entry.value;
      }
    }
    for (final entry in _surveyOffers.entries) {
      final cleanEnumName = entry.key.toString().split('.').last.toLowerCase();
      final cleanProviderName = entry.value.name.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
      if (cleanEnumName == cleanName || cleanProviderName == cleanName) {
        return entry.value;
      }
    }
    return null;
  }
}

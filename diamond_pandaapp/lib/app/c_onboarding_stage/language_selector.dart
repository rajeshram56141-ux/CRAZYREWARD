import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class LanguageInfo {
  final String locale;
  final String languageName;
  final String countryName;
  final String countryCode;

  LanguageInfo({
    required this.locale,
    required this.languageName,
    required this.countryName,
    required this.countryCode,
  });
}

final List<LanguageInfo> languageList = [
  LanguageInfo(
    locale: 'en',
    languageName: 'english',
    countryName: 'United States',
    countryCode: 'US',
  ),
  LanguageInfo(
    locale: 'hi',
    languageName: 'हिन्दी',
    countryName: 'India',
    countryCode: 'IN',
  ),
  LanguageInfo(
    locale: 'es',
    languageName: 'español',
    countryName: 'Spain',
    countryCode: 'ES',
  ),
  LanguageInfo(
    locale: 'fr',
    languageName: 'français',
    countryName: 'France',
    countryCode: 'FR',
  ),
  LanguageInfo(
    locale: 'id',
    languageName: 'bahasa indonesia',
    countryName: 'Indonesia',
    countryCode: 'ID',
  ),
  LanguageInfo(
    locale: 'pt',
    languageName: 'português',
    countryName: 'Portugal',
    countryCode: 'PT',
  ),
  LanguageInfo(
    locale: 'de',
    languageName: 'deutsch',
    countryName: 'Germany',
    countryCode: 'DE',
  ),
  LanguageInfo(
    locale: 'ja',
    languageName: '日本語',
    countryName: 'Japan',
    countryCode: 'JP',
  ),
  LanguageInfo(
    locale: 'ko',
    languageName: '한국어',
    countryName: 'South Korea',
    countryCode: 'KR',
  ),
  LanguageInfo(
    locale: 'tl',
    languageName: 'tagalog',
    countryName: 'Philippines',
    countryCode: 'PH',
  ),
  LanguageInfo(
    locale: 'pl',
    languageName: 'polski',
    countryName: 'Poland',
    countryCode: 'PL',
  ),
];

List<LanguageInfo> orderedLanguageList(
  List<LanguageInfo> languageList,
  BuildContext context,
) {
  final String deviceLocale = context.deviceLocale.languageCode;

  final LanguageInfo deviceLang = languageList.firstWhere(
    (lang) => lang.locale == deviceLocale,
    orElse: () => LanguageInfo(
      locale: deviceLocale,
      languageName: deviceLocale,
      countryName: '',
      countryCode: '',
    ),
  );

  final LanguageInfo englishLang = languageList.firstWhere(
    (lang) => lang.locale == 'en',
    orElse: () => LanguageInfo(
      locale: 'en',
      languageName: 'English',
      countryName: 'United States',
      countryCode: 'US',
    ),
  );

  final remaining = languageList.where(
    (lang) =>
        lang.locale != deviceLang.locale && lang.locale != englishLang.locale,
  );

  return [
    if (deviceLang.locale.isNotEmpty) deviceLang,
    if (deviceLang.locale != 'en') englishLang,
    ...remaining,
  ];
}

// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i37;
import 'package:collection/collection.dart' as _i40;
import 'package:crazyreward/app/b_splash_stage/splash_screen.dart' as _i31;
import 'package:crazyreward/app/c_onboarding_stage/onboarding_screen.dart'
    as _i22;
import 'package:crazyreward/app/d_authentication_stage/a_authentication_screen.dart'
    as _i2;
import 'package:crazyreward/app/d_authentication_stage/b_account_details_screen.dart'
    as _i1;
import 'package:crazyreward/app/e_dashboard_stage/screens/_dashboard_screen.dart'
    as _i11;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/battle_arena/battle_arena_screen.dart'
    as _i3;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/battle_arena/battle_arena_splash_screen.dart'
    as _i4;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/daily_challenge/daily_challenge_screen.dart'
    as _i7;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/daily_task/daily_task_details_screen.dart'
    as _i8;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/daily_task/daily_task_history_screen.dart'
    as _i9;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/daily_task/daily_task_model.dart'
    as _i39;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/daily_task/daily_task_screen.dart'
    as _i10;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/diamond_catch/diamond_catch_screen.dart'
    as _i12;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/giveaway/giveaway_details_screen.dart'
    as _i15;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/giveaway/giveaway_screen.dart'
    as _i16;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/giveaway/model/giveaway_model.dart'
    as _i42;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/more_apps/more_apps_screen.dart'
    as _i19;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/notifications/notification_screen.dart'
    as _i20;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/offerwall/offerwall_screen.dart'
    as _i21;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/offerwall/provider/offerwall_provider.dart'
    as _i43;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/play_games/play_games_screen.dart'
    as _i23;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/promo_code/promo_code_screen.dart'
    as _i24;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/read_tsk/read_tsk_model.dart'
    as _i44;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/read_tsk/read_tsk_screen.dart'
    as _i25;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/read_tsk/read_tsk_verification_screen.dart'
    as _i26;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/super_offer/super_offer_screen.dart'
    as _i32;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/wallet/model/redeem_history_model.dart'
    as _i45;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/wallet/screen/_redeem_screen.dart'
    as _i29;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/wallet/screen/a_redeem_history_screen.dart'
    as _i28;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/wallet/screen/b_redeem_history_details_screen.dart'
    as _i27;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/watch_video/_watch_video_body.dart'
    as _i36;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/watch_video/screens/watch_video_category_screen.dart'
    as _i34;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/watch_video/screens/watch_video_details_screen.dart'
    as _i35;
import 'package:crazyreward/app/e_dashboard_stage/sections/a_home/widgets/follow_screen.dart'
    as _i14;
import 'package:crazyreward/app/e_dashboard_stage/sections/b_invite/widgets/_level_program_screen.dart'
    as _i18;
import 'package:crazyreward/app/e_dashboard_stage/sections/d_profile/screens/change_language_screen.dart'
    as _i5;
import 'package:crazyreward/app/e_dashboard_stage/sections/d_profile/screens/contact_support_screen.dart'
    as _i6;
import 'package:crazyreward/app/e_dashboard_stage/sections/d_profile/screens/edit_account_details_screen.dart'
    as _i13;
import 'package:crazyreward/app/e_dashboard_stage/sections/d_profile/screens/how_to_use_screen.dart'
    as _i17;
import 'package:crazyreward/app/e_dashboard_stage/sections/d_profile/screens/services_screen.dart'
    as _i30;
import 'package:crazyreward/app/e_dashboard_stage/sections/d_profile/task_history/task_history_screen.dart'
    as _i33;
import 'package:flutter/foundation.dart' as _i41;
import 'package:flutter/material.dart' as _i38;
import 'package:hooks_riverpod/hooks_riverpod.dart' as _i46;

/// generated route for
/// [_i1.AccountDetailsScreen]
class AccountDetailsScreenRoute
    extends _i37.PageRouteInfo<AccountDetailsScreenRouteArgs> {
  AccountDetailsScreenRoute({
    _i38.Key? key,
    required String userId,
    required String userEmail,
    required String userName,
    required String userPhotoUrl,
    required String fetchedReferralCode,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          AccountDetailsScreenRoute.name,
          args: AccountDetailsScreenRouteArgs(
            key: key,
            userId: userId,
            userEmail: userEmail,
            userName: userName,
            userPhotoUrl: userPhotoUrl,
            fetchedReferralCode: fetchedReferralCode,
          ),
          initialChildren: children,
        );

  static const String name = 'AccountDetailsScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AccountDetailsScreenRouteArgs>();
      return _i1.AccountDetailsScreen(
        key: args.key,
        userId: args.userId,
        userEmail: args.userEmail,
        userName: args.userName,
        userPhotoUrl: args.userPhotoUrl,
        fetchedReferralCode: args.fetchedReferralCode,
      );
    },
  );
}

class AccountDetailsScreenRouteArgs {
  const AccountDetailsScreenRouteArgs({
    this.key,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.userPhotoUrl,
    required this.fetchedReferralCode,
  });

  final _i38.Key? key;

  final String userId;

  final String userEmail;

  final String userName;

  final String userPhotoUrl;

  final String fetchedReferralCode;

  @override
  String toString() {
    return 'AccountDetailsScreenRouteArgs{key: $key, userId: $userId, userEmail: $userEmail, userName: $userName, userPhotoUrl: $userPhotoUrl, fetchedReferralCode: $fetchedReferralCode}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AccountDetailsScreenRouteArgs) return false;
    return key == other.key &&
        userId == other.userId &&
        userEmail == other.userEmail &&
        userName == other.userName &&
        userPhotoUrl == other.userPhotoUrl &&
        fetchedReferralCode == other.fetchedReferralCode;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      userId.hashCode ^
      userEmail.hashCode ^
      userName.hashCode ^
      userPhotoUrl.hashCode ^
      fetchedReferralCode.hashCode;
}

/// generated route for
/// [_i2.AuthenticationScreen]
class AuthenticationScreenRoute extends _i37.PageRouteInfo<void> {
  const AuthenticationScreenRoute({List<_i37.PageRouteInfo>? children})
      : super(AuthenticationScreenRoute.name, initialChildren: children);

  static const String name = 'AuthenticationScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i2.AuthenticationScreen();
    },
  );
}

/// generated route for
/// [_i3.BattleArenaScreen]
class BattleArenaScreenRoute
    extends _i37.PageRouteInfo<BattleArenaScreenRouteArgs> {
  BattleArenaScreenRoute({
    _i38.Key? key,
    required String userId,
    required String email,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          BattleArenaScreenRoute.name,
          args: BattleArenaScreenRouteArgs(
            key: key,
            userId: userId,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'BattleArenaScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<BattleArenaScreenRouteArgs>();
      return _i3.BattleArenaScreen(
        key: args.key,
        userId: args.userId,
        email: args.email,
      );
    },
  );
}

class BattleArenaScreenRouteArgs {
  const BattleArenaScreenRouteArgs({
    this.key,
    required this.userId,
    required this.email,
  });

  final _i38.Key? key;

  final String userId;

  final String email;

  @override
  String toString() {
    return 'BattleArenaScreenRouteArgs{key: $key, userId: $userId, email: $email}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BattleArenaScreenRouteArgs) return false;
    return key == other.key && userId == other.userId && email == other.email;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode ^ email.hashCode;
}

/// generated route for
/// [_i4.BattleArenaSplashScreen]
class BattleArenaSplashScreenRoute
    extends _i37.PageRouteInfo<BattleArenaSplashScreenRouteArgs> {
  BattleArenaSplashScreenRoute({
    _i38.Key? key,
    required String userId,
    required String email,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          BattleArenaSplashScreenRoute.name,
          args: BattleArenaSplashScreenRouteArgs(
            key: key,
            userId: userId,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'BattleArenaSplashScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<BattleArenaSplashScreenRouteArgs>();
      return _i4.BattleArenaSplashScreen(
        key: args.key,
        userId: args.userId,
        email: args.email,
      );
    },
  );
}

class BattleArenaSplashScreenRouteArgs {
  const BattleArenaSplashScreenRouteArgs({
    this.key,
    required this.userId,
    required this.email,
  });

  final _i38.Key? key;

  final String userId;

  final String email;

  @override
  String toString() {
    return 'BattleArenaSplashScreenRouteArgs{key: $key, userId: $userId, email: $email}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BattleArenaSplashScreenRouteArgs) return false;
    return key == other.key && userId == other.userId && email == other.email;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode ^ email.hashCode;
}

/// generated route for
/// [_i5.ChangeLanguageScreen]
class ChangeLanguageScreenRoute extends _i37.PageRouteInfo<void> {
  const ChangeLanguageScreenRoute({List<_i37.PageRouteInfo>? children})
      : super(ChangeLanguageScreenRoute.name, initialChildren: children);

  static const String name = 'ChangeLanguageScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i5.ChangeLanguageScreen();
    },
  );
}

/// generated route for
/// [_i6.ContactSupportScreen]
class ContactSupportScreenRoute
    extends _i37.PageRouteInfo<ContactSupportScreenRouteArgs> {
  ContactSupportScreenRoute({
    _i38.Key? key,
    required String userId,
    required String email,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          ContactSupportScreenRoute.name,
          args: ContactSupportScreenRouteArgs(
            key: key,
            userId: userId,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'ContactSupportScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ContactSupportScreenRouteArgs>();
      return _i6.ContactSupportScreen(
        key: args.key,
        userId: args.userId,
        email: args.email,
      );
    },
  );
}

class ContactSupportScreenRouteArgs {
  const ContactSupportScreenRouteArgs({
    this.key,
    required this.userId,
    required this.email,
  });

  final _i38.Key? key;

  final String userId;

  final String email;

  @override
  String toString() {
    return 'ContactSupportScreenRouteArgs{key: $key, userId: $userId, email: $email}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContactSupportScreenRouteArgs) return false;
    return key == other.key && userId == other.userId && email == other.email;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode ^ email.hashCode;
}

/// generated route for
/// [_i7.DailyChallengeScreen]
class DailyChallengeScreenRoute extends _i37.PageRouteInfo<void> {
  const DailyChallengeScreenRoute({List<_i37.PageRouteInfo>? children})
      : super(DailyChallengeScreenRoute.name, initialChildren: children);

  static const String name = 'DailyChallengeScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i7.DailyChallengeScreen();
    },
  );
}

/// generated route for
/// [_i8.DailyTaskDetailsScreen]
class DailyTaskDetailsScreenRoute
    extends _i37.PageRouteInfo<DailyTaskDetailsScreenRouteArgs> {
  DailyTaskDetailsScreenRoute({
    _i38.Key? key,
    required _i39.DailyTaskModel item,
    required _i38.Color cardColor,
    required String userId,
    required String email,
    required String country,
    String? heroTag,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          DailyTaskDetailsScreenRoute.name,
          args: DailyTaskDetailsScreenRouteArgs(
            key: key,
            item: item,
            cardColor: cardColor,
            userId: userId,
            email: email,
            country: country,
            heroTag: heroTag,
          ),
          initialChildren: children,
        );

  static const String name = 'DailyTaskDetailsScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DailyTaskDetailsScreenRouteArgs>();
      return _i8.DailyTaskDetailsScreen(
        key: args.key,
        item: args.item,
        cardColor: args.cardColor,
        userId: args.userId,
        email: args.email,
        country: args.country,
        heroTag: args.heroTag,
      );
    },
  );
}

class DailyTaskDetailsScreenRouteArgs {
  const DailyTaskDetailsScreenRouteArgs({
    this.key,
    required this.item,
    required this.cardColor,
    required this.userId,
    required this.email,
    required this.country,
    this.heroTag,
  });

  final _i38.Key? key;

  final _i39.DailyTaskModel item;

  final _i38.Color cardColor;

  final String userId;

  final String email;

  final String country;

  final String? heroTag;

  @override
  String toString() {
    return 'DailyTaskDetailsScreenRouteArgs{key: $key, item: $item, cardColor: $cardColor, userId: $userId, email: $email, country: $country, heroTag: $heroTag}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DailyTaskDetailsScreenRouteArgs) return false;
    return key == other.key &&
        item == other.item &&
        cardColor == other.cardColor &&
        userId == other.userId &&
        email == other.email &&
        country == other.country &&
        heroTag == other.heroTag;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      item.hashCode ^
      cardColor.hashCode ^
      userId.hashCode ^
      email.hashCode ^
      country.hashCode ^
      heroTag.hashCode;
}

/// generated route for
/// [_i9.DailyTaskHistoryScreen]
class DailyTaskHistoryScreenRoute
    extends _i37.PageRouteInfo<DailyTaskHistoryScreenRouteArgs> {
  DailyTaskHistoryScreenRoute({
    _i38.Key? key,
    required String userId,
    required String email,
    required String country,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          DailyTaskHistoryScreenRoute.name,
          args: DailyTaskHistoryScreenRouteArgs(
            key: key,
            userId: userId,
            email: email,
            country: country,
          ),
          initialChildren: children,
        );

  static const String name = 'DailyTaskHistoryScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DailyTaskHistoryScreenRouteArgs>();
      return _i9.DailyTaskHistoryScreen(
        key: args.key,
        userId: args.userId,
        email: args.email,
        country: args.country,
      );
    },
  );
}

class DailyTaskHistoryScreenRouteArgs {
  const DailyTaskHistoryScreenRouteArgs({
    this.key,
    required this.userId,
    required this.email,
    required this.country,
  });

  final _i38.Key? key;

  final String userId;

  final String email;

  final String country;

  @override
  String toString() {
    return 'DailyTaskHistoryScreenRouteArgs{key: $key, userId: $userId, email: $email, country: $country}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DailyTaskHistoryScreenRouteArgs) return false;
    return key == other.key &&
        userId == other.userId &&
        email == other.email &&
        country == other.country;
  }

  @override
  int get hashCode =>
      key.hashCode ^ userId.hashCode ^ email.hashCode ^ country.hashCode;
}

/// generated route for
/// [_i10.DailyTaskScreen]
class DailyTaskScreenRoute
    extends _i37.PageRouteInfo<DailyTaskScreenRouteArgs> {
  DailyTaskScreenRoute({
    _i38.Key? key,
    required String country,
    required String email,
    required String userId,
    List<_i39.DailyTaskModel>? tasks,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          DailyTaskScreenRoute.name,
          args: DailyTaskScreenRouteArgs(
            key: key,
            country: country,
            email: email,
            userId: userId,
            tasks: tasks,
          ),
          initialChildren: children,
        );

  static const String name = 'DailyTaskScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DailyTaskScreenRouteArgs>();
      return _i10.DailyTaskScreen(
        key: args.key,
        country: args.country,
        email: args.email,
        userId: args.userId,
        tasks: args.tasks,
      );
    },
  );
}

class DailyTaskScreenRouteArgs {
  const DailyTaskScreenRouteArgs({
    this.key,
    required this.country,
    required this.email,
    required this.userId,
    this.tasks,
  });

  final _i38.Key? key;

  final String country;

  final String email;

  final String userId;

  final List<_i39.DailyTaskModel>? tasks;

  @override
  String toString() {
    return 'DailyTaskScreenRouteArgs{key: $key, country: $country, email: $email, userId: $userId, tasks: $tasks}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DailyTaskScreenRouteArgs) return false;
    return key == other.key &&
        country == other.country &&
        email == other.email &&
        userId == other.userId &&
        const _i40.ListEquality<_i39.DailyTaskModel>().equals(
          tasks,
          other.tasks,
        );
  }

  @override
  int get hashCode =>
      key.hashCode ^
      country.hashCode ^
      email.hashCode ^
      userId.hashCode ^
      const _i40.ListEquality<_i39.DailyTaskModel>().hash(tasks);
}

/// generated route for
/// [_i11.DashboardScreen]
class DashboardScreenRoute
    extends _i37.PageRouteInfo<DashboardScreenRouteArgs> {
  DashboardScreenRoute({
    _i41.Key? key,
    required String userId,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          DashboardScreenRoute.name,
          args: DashboardScreenRouteArgs(key: key, userId: userId),
          initialChildren: children,
        );

  static const String name = 'DashboardScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DashboardScreenRouteArgs>();
      return _i11.DashboardScreen(key: args.key, userId: args.userId);
    },
  );
}

class DashboardScreenRouteArgs {
  const DashboardScreenRouteArgs({this.key, required this.userId});

  final _i41.Key? key;

  final String userId;

  @override
  String toString() {
    return 'DashboardScreenRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DashboardScreenRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [_i12.DiamondCatchScreen]
class DiamondCatchScreenRoute
    extends _i37.PageRouteInfo<DiamondCatchScreenRouteArgs> {
  DiamondCatchScreenRoute({
    _i38.Key? key,
    required String userId,
    required int gameGems,
    required int installGems,
    required int dailyGemsForInstall,
    required int gemsRequired,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          DiamondCatchScreenRoute.name,
          args: DiamondCatchScreenRouteArgs(
            key: key,
            userId: userId,
            gameGems: gameGems,
            installGems: installGems,
            dailyGemsForInstall: dailyGemsForInstall,
            gemsRequired: gemsRequired,
          ),
          initialChildren: children,
        );

  static const String name = 'DiamondCatchScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DiamondCatchScreenRouteArgs>();
      return _i12.DiamondCatchScreen(
        key: args.key,
        userId: args.userId,
        gameGems: args.gameGems,
        installGems: args.installGems,
        dailyGemsForInstall: args.dailyGemsForInstall,
        gemsRequired: args.gemsRequired,
      );
    },
  );
}

class DiamondCatchScreenRouteArgs {
  const DiamondCatchScreenRouteArgs({
    this.key,
    required this.userId,
    required this.gameGems,
    required this.installGems,
    required this.dailyGemsForInstall,
    required this.gemsRequired,
  });

  final _i38.Key? key;

  final String userId;

  final int gameGems;

  final int installGems;

  final int dailyGemsForInstall;

  final int gemsRequired;

  @override
  String toString() {
    return 'DiamondCatchScreenRouteArgs{key: $key, userId: $userId, gameGems: $gameGems, installGems: $installGems, dailyGemsForInstall: $dailyGemsForInstall, gemsRequired: $gemsRequired}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DiamondCatchScreenRouteArgs) return false;
    return key == other.key &&
        userId == other.userId &&
        gameGems == other.gameGems &&
        installGems == other.installGems &&
        dailyGemsForInstall == other.dailyGemsForInstall &&
        gemsRequired == other.gemsRequired;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      userId.hashCode ^
      gameGems.hashCode ^
      installGems.hashCode ^
      dailyGemsForInstall.hashCode ^
      gemsRequired.hashCode;
}

/// generated route for
/// [_i13.EditAccountDetailsScreen]
class EditAccountDetailsScreenRoute
    extends _i37.PageRouteInfo<EditAccountDetailsScreenRouteArgs> {
  EditAccountDetailsScreenRoute({
    _i38.Key? key,
    required String userId,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          EditAccountDetailsScreenRoute.name,
          args: EditAccountDetailsScreenRouteArgs(key: key, userId: userId),
          initialChildren: children,
        );

  static const String name = 'EditAccountDetailsScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EditAccountDetailsScreenRouteArgs>();
      return _i13.EditAccountDetailsScreen(key: args.key, userId: args.userId);
    },
  );
}

class EditAccountDetailsScreenRouteArgs {
  const EditAccountDetailsScreenRouteArgs({this.key, required this.userId});

  final _i38.Key? key;

  final String userId;

  @override
  String toString() {
    return 'EditAccountDetailsScreenRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EditAccountDetailsScreenRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [_i14.FollowScreen]
class FollowScreenRoute extends _i37.PageRouteInfo<FollowScreenRouteArgs> {
  FollowScreenRoute({
    _i38.Key? key,
    String userId = '',
    List<_i37.PageRouteInfo>? children,
  }) : super(
          FollowScreenRoute.name,
          args: FollowScreenRouteArgs(key: key, userId: userId),
          initialChildren: children,
        );

  static const String name = 'FollowScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FollowScreenRouteArgs>(
        orElse: () => const FollowScreenRouteArgs(),
      );
      return _i14.FollowScreen(key: args.key, userId: args.userId);
    },
  );
}

class FollowScreenRouteArgs {
  const FollowScreenRouteArgs({this.key, this.userId = ''});

  final _i38.Key? key;

  final String userId;

  @override
  String toString() {
    return 'FollowScreenRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FollowScreenRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [_i15.GiveawayDetailScreen]
class GiveawayDetailScreenRoute
    extends _i37.PageRouteInfo<GiveawayDetailScreenRouteArgs> {
  GiveawayDetailScreenRoute({
    _i38.Key? key,
    required _i42.GiveawayModel giveaway,
    required String userId,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          GiveawayDetailScreenRoute.name,
          args: GiveawayDetailScreenRouteArgs(
            key: key,
            giveaway: giveaway,
            userId: userId,
          ),
          initialChildren: children,
        );

  static const String name = 'GiveawayDetailScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<GiveawayDetailScreenRouteArgs>();
      return _i15.GiveawayDetailScreen(
        key: args.key,
        giveaway: args.giveaway,
        userId: args.userId,
      );
    },
  );
}

class GiveawayDetailScreenRouteArgs {
  const GiveawayDetailScreenRouteArgs({
    this.key,
    required this.giveaway,
    required this.userId,
  });

  final _i38.Key? key;

  final _i42.GiveawayModel giveaway;

  final String userId;

  @override
  String toString() {
    return 'GiveawayDetailScreenRouteArgs{key: $key, giveaway: $giveaway, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GiveawayDetailScreenRouteArgs) return false;
    return key == other.key &&
        giveaway == other.giveaway &&
        userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ giveaway.hashCode ^ userId.hashCode;
}

/// generated route for
/// [_i16.GiveawayScreen]
class GiveawayScreenRoute extends _i37.PageRouteInfo<GiveawayScreenRouteArgs> {
  GiveawayScreenRoute({
    _i38.Key? key,
    required String userId,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          GiveawayScreenRoute.name,
          args: GiveawayScreenRouteArgs(key: key, userId: userId),
          initialChildren: children,
        );

  static const String name = 'GiveawayScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<GiveawayScreenRouteArgs>();
      return _i16.GiveawayScreen(key: args.key, userId: args.userId);
    },
  );
}

class GiveawayScreenRouteArgs {
  const GiveawayScreenRouteArgs({this.key, required this.userId});

  final _i38.Key? key;

  final String userId;

  @override
  String toString() {
    return 'GiveawayScreenRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GiveawayScreenRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [_i17.HowToUseScreen]
class HowToUseScreenRoute extends _i37.PageRouteInfo<void> {
  const HowToUseScreenRoute({List<_i37.PageRouteInfo>? children})
      : super(HowToUseScreenRoute.name, initialChildren: children);

  static const String name = 'HowToUseScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i17.HowToUseScreen();
    },
  );
}

/// generated route for
/// [_i18.LevelProgramScreen]
class LevelProgramScreenRoute
    extends _i37.PageRouteInfo<LevelProgramScreenRouteArgs> {
  LevelProgramScreenRoute({
    _i38.Key? key,
    required String title,
    required int level,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          LevelProgramScreenRoute.name,
          args: LevelProgramScreenRouteArgs(
            key: key,
            title: title,
            level: level,
          ),
          initialChildren: children,
        );

  static const String name = 'LevelProgramScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LevelProgramScreenRouteArgs>();
      return _i18.LevelProgramScreen(
        key: args.key,
        title: args.title,
        level: args.level,
      );
    },
  );
}

class LevelProgramScreenRouteArgs {
  const LevelProgramScreenRouteArgs({
    this.key,
    required this.title,
    required this.level,
  });

  final _i38.Key? key;

  final String title;

  final int level;

  @override
  String toString() {
    return 'LevelProgramScreenRouteArgs{key: $key, title: $title, level: $level}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LevelProgramScreenRouteArgs) return false;
    return key == other.key && title == other.title && level == other.level;
  }

  @override
  int get hashCode => key.hashCode ^ title.hashCode ^ level.hashCode;
}

/// generated route for
/// [_i19.MoreAppsScreen]
class MoreAppsScreenRoute extends _i37.PageRouteInfo<MoreAppsScreenRouteArgs> {
  MoreAppsScreenRoute({
    _i38.Key? key,
    String userId = '',
    List<_i37.PageRouteInfo>? children,
  }) : super(
          MoreAppsScreenRoute.name,
          args: MoreAppsScreenRouteArgs(key: key, userId: userId),
          initialChildren: children,
        );

  static const String name = 'MoreAppsScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MoreAppsScreenRouteArgs>(
        orElse: () => const MoreAppsScreenRouteArgs(),
      );
      return _i19.MoreAppsScreen(key: args.key, userId: args.userId);
    },
  );
}

class MoreAppsScreenRouteArgs {
  const MoreAppsScreenRouteArgs({this.key, this.userId = ''});

  final _i38.Key? key;

  final String userId;

  @override
  String toString() {
    return 'MoreAppsScreenRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MoreAppsScreenRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [_i20.NotificationScreen]
class NotificationScreenRoute extends _i37.PageRouteInfo<void> {
  const NotificationScreenRoute({List<_i37.PageRouteInfo>? children})
      : super(NotificationScreenRoute.name, initialChildren: children);

  static const String name = 'NotificationScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i20.NotificationScreen();
    },
  );
}

/// generated route for
/// [_i21.OfferwallScreen]
class OfferwallScreenRoute
    extends _i37.PageRouteInfo<OfferwallScreenRouteArgs> {
  OfferwallScreenRoute({
    _i38.Key? key,
    required String userId,
    required List<_i43.OfferwallProvider> offerwallList,
    required String title,
    required String email,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          OfferwallScreenRoute.name,
          args: OfferwallScreenRouteArgs(
            key: key,
            userId: userId,
            offerwallList: offerwallList,
            title: title,
            email: email,
          ),
          initialChildren: children,
        );

  static const String name = 'OfferwallScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<OfferwallScreenRouteArgs>();
      return _i21.OfferwallScreen(
        key: args.key,
        userId: args.userId,
        offerwallList: args.offerwallList,
        title: args.title,
        email: args.email,
      );
    },
  );
}

class OfferwallScreenRouteArgs {
  const OfferwallScreenRouteArgs({
    this.key,
    required this.userId,
    required this.offerwallList,
    required this.title,
    required this.email,
  });

  final _i38.Key? key;

  final String userId;

  final List<_i43.OfferwallProvider> offerwallList;

  final String title;

  final String email;

  @override
  String toString() {
    return 'OfferwallScreenRouteArgs{key: $key, userId: $userId, offerwallList: $offerwallList, title: $title, email: $email}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OfferwallScreenRouteArgs) return false;
    return key == other.key &&
        userId == other.userId &&
        const _i40.ListEquality<_i43.OfferwallProvider>().equals(
          offerwallList,
          other.offerwallList,
        ) &&
        title == other.title &&
        email == other.email;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      userId.hashCode ^
      const _i40.ListEquality<_i43.OfferwallProvider>().hash(offerwallList) ^
      title.hashCode ^
      email.hashCode;
}

/// generated route for
/// [_i22.OnboardingScreen]
class OnboardingScreenRoute extends _i37.PageRouteInfo<void> {
  const OnboardingScreenRoute({List<_i37.PageRouteInfo>? children})
      : super(OnboardingScreenRoute.name, initialChildren: children);

  static const String name = 'OnboardingScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i22.OnboardingScreen();
    },
  );
}

/// generated route for
/// [_i23.PlayGamesScreen]
class PlayGamesScreenRoute
    extends _i37.PageRouteInfo<PlayGamesScreenRouteArgs> {
  PlayGamesScreenRoute({
    _i38.Key? key,
    String userId = '',
    List<_i37.PageRouteInfo>? children,
  }) : super(
          PlayGamesScreenRoute.name,
          args: PlayGamesScreenRouteArgs(key: key, userId: userId),
          initialChildren: children,
        );

  static const String name = 'PlayGamesScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PlayGamesScreenRouteArgs>(
        orElse: () => const PlayGamesScreenRouteArgs(),
      );
      return _i23.PlayGamesScreen(key: args.key, userId: args.userId);
    },
  );
}

class PlayGamesScreenRouteArgs {
  const PlayGamesScreenRouteArgs({this.key, this.userId = ''});

  final _i38.Key? key;

  final String userId;

  @override
  String toString() {
    return 'PlayGamesScreenRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PlayGamesScreenRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [_i24.PromoCodeScreen]
class PromoCodeScreenRoute extends _i37.PageRouteInfo<void> {
  const PromoCodeScreenRoute({List<_i37.PageRouteInfo>? children})
      : super(PromoCodeScreenRoute.name, initialChildren: children);

  static const String name = 'PromoCodeScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i24.PromoCodeScreen();
    },
  );
}

/// generated route for
/// [_i25.ReadTskScreen]
class ReadTskScreenRoute extends _i37.PageRouteInfo<ReadTskScreenRouteArgs> {
  ReadTskScreenRoute({
    _i38.Key? key,
    required String userId,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          ReadTskScreenRoute.name,
          args: ReadTskScreenRouteArgs(key: key, userId: userId),
          initialChildren: children,
        );

  static const String name = 'ReadTskScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ReadTskScreenRouteArgs>();
      return _i25.ReadTskScreen(key: args.key, userId: args.userId);
    },
  );
}

class ReadTskScreenRouteArgs {
  const ReadTskScreenRouteArgs({this.key, required this.userId});

  final _i38.Key? key;

  final String userId;

  @override
  String toString() {
    return 'ReadTskScreenRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ReadTskScreenRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [_i26.ReadTskVerificationScreen]
class ReadTskVerificationScreenRoute
    extends _i37.PageRouteInfo<ReadTskVerificationScreenRouteArgs> {
  ReadTskVerificationScreenRoute({
    _i38.Key? key,
    required _i44.ReadTskModel offer,
    required String userId,
    required String appName,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          ReadTskVerificationScreenRoute.name,
          args: ReadTskVerificationScreenRouteArgs(
            key: key,
            offer: offer,
            userId: userId,
            appName: appName,
          ),
          initialChildren: children,
        );

  static const String name = 'ReadTskVerificationScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ReadTskVerificationScreenRouteArgs>();
      return _i26.ReadTskVerificationScreen(
        key: args.key,
        offer: args.offer,
        userId: args.userId,
        appName: args.appName,
      );
    },
  );
}

class ReadTskVerificationScreenRouteArgs {
  const ReadTskVerificationScreenRouteArgs({
    this.key,
    required this.offer,
    required this.userId,
    required this.appName,
  });

  final _i38.Key? key;

  final _i44.ReadTskModel offer;

  final String userId;

  final String appName;

  @override
  String toString() {
    return 'ReadTskVerificationScreenRouteArgs{key: $key, offer: $offer, userId: $userId, appName: $appName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ReadTskVerificationScreenRouteArgs) return false;
    return key == other.key &&
        offer == other.offer &&
        userId == other.userId &&
        appName == other.appName;
  }

  @override
  int get hashCode =>
      key.hashCode ^ offer.hashCode ^ userId.hashCode ^ appName.hashCode;
}

/// generated route for
/// [_i27.RedeemHistoryDetailsScreen]
class RedeemHistoryDetailsScreenRoute
    extends _i37.PageRouteInfo<RedeemHistoryDetailsScreenRouteArgs> {
  RedeemHistoryDetailsScreenRoute({
    _i38.Key? key,
    required _i45.PayoutHistoryModel history,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          RedeemHistoryDetailsScreenRoute.name,
          args: RedeemHistoryDetailsScreenRouteArgs(key: key, history: history),
          initialChildren: children,
        );

  static const String name = 'RedeemHistoryDetailsScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<RedeemHistoryDetailsScreenRouteArgs>();
      return _i27.RedeemHistoryDetailsScreen(
        key: args.key,
        history: args.history,
      );
    },
  );
}

class RedeemHistoryDetailsScreenRouteArgs {
  const RedeemHistoryDetailsScreenRouteArgs({this.key, required this.history});

  final _i38.Key? key;

  final _i45.PayoutHistoryModel history;

  @override
  String toString() {
    return 'RedeemHistoryDetailsScreenRouteArgs{key: $key, history: $history}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RedeemHistoryDetailsScreenRouteArgs) return false;
    return key == other.key && history == other.history;
  }

  @override
  int get hashCode => key.hashCode ^ history.hashCode;
}

/// generated route for
/// [_i28.RedeemHistoryScreen]
class RedeemHistoryScreenRoute
    extends _i37.PageRouteInfo<RedeemHistoryScreenRouteArgs> {
  RedeemHistoryScreenRoute({
    _i38.Key? key,
    required String userId,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          RedeemHistoryScreenRoute.name,
          args: RedeemHistoryScreenRouteArgs(key: key, userId: userId),
          initialChildren: children,
        );

  static const String name = 'RedeemHistoryScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<RedeemHistoryScreenRouteArgs>();
      return _i28.RedeemHistoryScreen(key: args.key, userId: args.userId);
    },
  );
}

class RedeemHistoryScreenRouteArgs {
  const RedeemHistoryScreenRouteArgs({this.key, required this.userId});

  final _i38.Key? key;

  final String userId;

  @override
  String toString() {
    return 'RedeemHistoryScreenRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RedeemHistoryScreenRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [_i29.RedeemScreen]
class RedeemScreenRoute extends _i37.PageRouteInfo<RedeemScreenRouteArgs> {
  RedeemScreenRoute({
    _i38.Key? key,
    required String userId,
    required String country,
    required bool isGuest,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          RedeemScreenRoute.name,
          args: RedeemScreenRouteArgs(
            key: key,
            userId: userId,
            country: country,
            isGuest: isGuest,
          ),
          initialChildren: children,
        );

  static const String name = 'RedeemScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<RedeemScreenRouteArgs>();
      return _i29.RedeemScreen(
        key: args.key,
        userId: args.userId,
        country: args.country,
        isGuest: args.isGuest,
      );
    },
  );
}

class RedeemScreenRouteArgs {
  const RedeemScreenRouteArgs({
    this.key,
    required this.userId,
    required this.country,
    required this.isGuest,
  });

  final _i38.Key? key;

  final String userId;

  final String country;

  final bool isGuest;

  @override
  String toString() {
    return 'RedeemScreenRouteArgs{key: $key, userId: $userId, country: $country, isGuest: $isGuest}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RedeemScreenRouteArgs) return false;
    return key == other.key &&
        userId == other.userId &&
        country == other.country &&
        isGuest == other.isGuest;
  }

  @override
  int get hashCode =>
      key.hashCode ^ userId.hashCode ^ country.hashCode ^ isGuest.hashCode;
}

/// generated route for
/// [_i30.ServicesScreen]
class ServicesScreenRoute extends _i37.PageRouteInfo<ServicesScreenRouteArgs> {
  ServicesScreenRoute({
    _i38.Key? key,
    required String userId,
    required String email,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          ServicesScreenRoute.name,
          args: ServicesScreenRouteArgs(key: key, userId: userId, email: email),
          initialChildren: children,
        );

  static const String name = 'ServicesScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ServicesScreenRouteArgs>();
      return _i30.ServicesScreen(
        key: args.key,
        userId: args.userId,
        email: args.email,
      );
    },
  );
}

class ServicesScreenRouteArgs {
  const ServicesScreenRouteArgs({
    this.key,
    required this.userId,
    required this.email,
  });

  final _i38.Key? key;

  final String userId;

  final String email;

  @override
  String toString() {
    return 'ServicesScreenRouteArgs{key: $key, userId: $userId, email: $email}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ServicesScreenRouteArgs) return false;
    return key == other.key && userId == other.userId && email == other.email;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode ^ email.hashCode;
}

/// generated route for
/// [_i31.SplashScreen]
class SplashScreenRoute extends _i37.PageRouteInfo<void> {
  const SplashScreenRoute({List<_i37.PageRouteInfo>? children})
      : super(SplashScreenRoute.name, initialChildren: children);

  static const String name = 'SplashScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i31.SplashScreen();
    },
  );
}

/// generated route for
/// [_i32.SuperOfferScreen]
class SuperOfferScreenRoute
    extends _i37.PageRouteInfo<SuperOfferScreenRouteArgs> {
  SuperOfferScreenRoute({
    _i38.Key? key,
    required String userId,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          SuperOfferScreenRoute.name,
          args: SuperOfferScreenRouteArgs(key: key, userId: userId),
          initialChildren: children,
        );

  static const String name = 'SuperOfferScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SuperOfferScreenRouteArgs>();
      return _i32.SuperOfferScreen(key: args.key, userId: args.userId);
    },
  );
}

class SuperOfferScreenRouteArgs {
  const SuperOfferScreenRouteArgs({this.key, required this.userId});

  final _i38.Key? key;

  final String userId;

  @override
  String toString() {
    return 'SuperOfferScreenRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SuperOfferScreenRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [_i33.TaskHistoryScreen]
class TaskHistoryScreenRoute
    extends _i37.PageRouteInfo<TaskHistoryScreenRouteArgs> {
  TaskHistoryScreenRoute({
    _i38.Key? key,
    required String userId,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          TaskHistoryScreenRoute.name,
          args: TaskHistoryScreenRouteArgs(key: key, userId: userId),
          initialChildren: children,
        );

  static const String name = 'TaskHistoryScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TaskHistoryScreenRouteArgs>();
      return _i33.TaskHistoryScreen(key: args.key, userId: args.userId);
    },
  );
}

class TaskHistoryScreenRouteArgs {
  const TaskHistoryScreenRouteArgs({this.key, required this.userId});

  final _i38.Key? key;

  final String userId;

  @override
  String toString() {
    return 'TaskHistoryScreenRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TaskHistoryScreenRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [_i34.WatchVideoCategoryScreen]
class WatchVideoCategoryScreenRoute
    extends _i37.PageRouteInfo<WatchVideoCategoryScreenRouteArgs> {
  WatchVideoCategoryScreenRoute({
    _i38.Key? key,
    required String categoryTitle,
    required List<_i39.DailyTaskModel> items,
    required String email,
    required String userId,
    required String countryCode,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          WatchVideoCategoryScreenRoute.name,
          args: WatchVideoCategoryScreenRouteArgs(
            key: key,
            categoryTitle: categoryTitle,
            items: items,
            email: email,
            userId: userId,
            countryCode: countryCode,
          ),
          initialChildren: children,
        );

  static const String name = 'WatchVideoCategoryScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WatchVideoCategoryScreenRouteArgs>();
      return _i34.WatchVideoCategoryScreen(
        key: args.key,
        categoryTitle: args.categoryTitle,
        items: args.items,
        email: args.email,
        userId: args.userId,
        countryCode: args.countryCode,
      );
    },
  );
}

class WatchVideoCategoryScreenRouteArgs {
  const WatchVideoCategoryScreenRouteArgs({
    this.key,
    required this.categoryTitle,
    required this.items,
    required this.email,
    required this.userId,
    required this.countryCode,
  });

  final _i38.Key? key;

  final String categoryTitle;

  final List<_i39.DailyTaskModel> items;

  final String email;

  final String userId;

  final String countryCode;

  @override
  String toString() {
    return 'WatchVideoCategoryScreenRouteArgs{key: $key, categoryTitle: $categoryTitle, items: $items, email: $email, userId: $userId, countryCode: $countryCode}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WatchVideoCategoryScreenRouteArgs) return false;
    return key == other.key &&
        categoryTitle == other.categoryTitle &&
        const _i40.ListEquality<_i39.DailyTaskModel>().equals(
          items,
          other.items,
        ) &&
        email == other.email &&
        userId == other.userId &&
        countryCode == other.countryCode;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      categoryTitle.hashCode ^
      const _i40.ListEquality<_i39.DailyTaskModel>().hash(items) ^
      email.hashCode ^
      userId.hashCode ^
      countryCode.hashCode;
}

/// generated route for
/// [_i35.WatchVideoDetailsScreen]
class WatchVideoDetailsScreenRoute
    extends _i37.PageRouteInfo<WatchVideoDetailsScreenRouteArgs> {
  WatchVideoDetailsScreenRoute({
    _i38.Key? key,
    required _i39.DailyTaskModel item,
    required String email,
    required String userId,
    required String countryCode,
    required _i46.WidgetRef ref,
    String? heroTag,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          WatchVideoDetailsScreenRoute.name,
          args: WatchVideoDetailsScreenRouteArgs(
            key: key,
            item: item,
            email: email,
            userId: userId,
            countryCode: countryCode,
            ref: ref,
            heroTag: heroTag,
          ),
          initialChildren: children,
        );

  static const String name = 'WatchVideoDetailsScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WatchVideoDetailsScreenRouteArgs>();
      return _i35.WatchVideoDetailsScreen(
        key: args.key,
        item: args.item,
        email: args.email,
        userId: args.userId,
        countryCode: args.countryCode,
        ref: args.ref,
        heroTag: args.heroTag,
      );
    },
  );
}

class WatchVideoDetailsScreenRouteArgs {
  const WatchVideoDetailsScreenRouteArgs({
    this.key,
    required this.item,
    required this.email,
    required this.userId,
    required this.countryCode,
    required this.ref,
    this.heroTag,
  });

  final _i38.Key? key;

  final _i39.DailyTaskModel item;

  final String email;

  final String userId;

  final String countryCode;

  final _i46.WidgetRef ref;

  final String? heroTag;

  @override
  String toString() {
    return 'WatchVideoDetailsScreenRouteArgs{key: $key, item: $item, email: $email, userId: $userId, countryCode: $countryCode, ref: $ref, heroTag: $heroTag}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WatchVideoDetailsScreenRouteArgs) return false;
    return key == other.key &&
        item == other.item &&
        email == other.email &&
        userId == other.userId &&
        countryCode == other.countryCode &&
        ref == other.ref &&
        heroTag == other.heroTag;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      item.hashCode ^
      email.hashCode ^
      userId.hashCode ^
      countryCode.hashCode ^
      ref.hashCode ^
      heroTag.hashCode;
}

/// generated route for
/// [_i36.WatchVideoScreen]
class WatchVideoScreenRoute
    extends _i37.PageRouteInfo<WatchVideoScreenRouteArgs> {
  WatchVideoScreenRoute({
    _i38.Key? key,
    required String email,
    required String userId,
    required String country,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          WatchVideoScreenRoute.name,
          args: WatchVideoScreenRouteArgs(
            key: key,
            email: email,
            userId: userId,
            country: country,
          ),
          initialChildren: children,
        );

  static const String name = 'WatchVideoScreenRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WatchVideoScreenRouteArgs>();
      return _i36.WatchVideoScreen(
        key: args.key,
        email: args.email,
        userId: args.userId,
        country: args.country,
      );
    },
  );
}

class WatchVideoScreenRouteArgs {
  const WatchVideoScreenRouteArgs({
    this.key,
    required this.email,
    required this.userId,
    required this.country,
  });

  final _i38.Key? key;

  final String email;

  final String userId;

  final String country;

  @override
  String toString() {
    return 'WatchVideoScreenRouteArgs{key: $key, email: $email, userId: $userId, country: $country}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WatchVideoScreenRouteArgs) return false;
    return key == other.key &&
        email == other.email &&
        userId == other.userId &&
        country == other.country;
  }

  @override
  int get hashCode =>
      key.hashCode ^ email.hashCode ^ userId.hashCode ^ country.hashCode;
}

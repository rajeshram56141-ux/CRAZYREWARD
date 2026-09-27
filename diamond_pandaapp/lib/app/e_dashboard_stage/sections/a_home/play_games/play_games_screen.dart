import 'package:auto_route/auto_route.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

import '../../../../../services/launch_url.dart';
import '../../../../../services/security_service.dart';
import '../../../../../utils/constant/constant.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import '../../../../../widgets/common/internet_image.dart';
import '../../../../../widgets/common/screen_banner_widget.dart';
import '../../../../../widgets/ads/topon_native_ad_card.dart';
import '../../../../../widgets/common/shimmer_tag.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';
import '../watch_video/widgets/no_daily_task.dart';
import 'play_games_model.dart';
import 'play_games_provider.dart';

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

@RoutePage()
class PlayGamesScreen extends HookConsumerWidget {
  const PlayGamesScreen({super.key, this.userId = ''});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final topPadding = MediaQuery.of(context).padding.top;

    useEffect(() {
      Future.microtask(() {
        ref.invalidate(playGamesProvider(userId));
      });
      return () {
        if (userId.trim().isNotEmpty) {
          ref.invalidate(DashboardService.userDataProvider(userId));
        }
      };
    }, [userId]);

    final isTracking = useState(false);
    final clickTime = useState<DateTime?>(null);
    final selectedTask = useState<PlayGamesModel?>(null);
    final lifecycleState = useAppLifecycleState();

    useValueChanged<AppLifecycleState?, void>(lifecycleState, (_, __) {
      if (isTracking.value &&
          lifecycleState == AppLifecycleState.resumed &&
          clickTime.value != null &&
          selectedTask.value != null) {
        final task = selectedTask.value!;
        final secondsSpent = DateTime.now()
            .difference(clickTime.value!)
            .inSeconds;
        final success = secondsSpent >= task.trackingTime;

        isTracking.value = false;
        clickTime.value = null;
        selectedTask.value = null;

        Future.microtask(() async {
          if (!context.mounted) return;

          if (success) {
            final effectiveUserId = userId.trim();
            if (effectiveUserId.isNotEmpty) {
              try {
                final dio = Dio();
                final rawInput = {
                  'offerId': task.offerId,
                  'userId': effectiveUserId,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                };

                final encryptedPayload = SecurityService.encryptPayload(
                  rawInput,
                  userId: effectiveUserId,
                );

                await dio.post(
                  AppConst.fetchGames.replaceAll('/get-games', '/record-game-play'),
                  data: {
                    'payload': encryptedPayload,
                  },
                  options: Options(
                    headers: {
                      ...AppConst.apiHeader,
                      'x-user-id': effectiveUserId,
                    },
                    sendTimeout: const Duration(seconds: 5),
                    receiveTimeout: const Duration(seconds: 5),
                  ),
                );
              } catch (_) {}
            }
          }
          if (!context.mounted) return;

          if (success) {
            CustomStatusPopup.showSuccess(
              context: context,
              tag: 'Well Played!',
              title: 'Coins Earned!',
              message: 'You have earned ${task.coins} coins from playing ${task.offerName}.',
              primaryButtonText: 'GREAT!',
              onPrimaryTap: () {
                if (userId.trim().isNotEmpty) {
                  ref.invalidate(DashboardService.userDataProvider(userId));
                }
              },
            );
          } else {
            CustomStatusPopup.showFailed(
              context: context,
              tag: 'Time Incomplete',
              title: 'Play Longer!',
              message: 'Please play the game for at least ${task.trackingTime} seconds to receive your coins.',
              primaryButtonText: 'TRY AGAIN',
            );
          }
        });
      }
    });

    final asyncGames = ref.watch(playGamesProvider(userId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Solid Clean White Base Background
            Positioned.fill(
              child: Container(color: Colors.white),
            ),

            // 2. Main Content
            Positioned.fill(
              child: asyncGames.when(
                data: (offers) {
                  final categories = offers
                      .map((e) => e.category)
                      .where((c) => c.trim().isNotEmpty)
                      .toSet()
                      .toList();

                  final selectedCategory = ref.watch(selectedCategoryProvider);

                  final filteredGames = selectedCategory == null
                      ? offers
                      : offers
                          .where((g) => g.category == selectedCategory)
                          .toList();

                  return RefreshIndicator(
                    color: const Color(0xFF48C78E),
                    backgroundColor: Colors.white,
                    edgeOffset: topPadding + 60.h,
                    onRefresh: () async {
                      ref.invalidate(playGamesProvider(userId));
                      await ref.read(playGamesProvider(userId).future).catchError((_) => <PlayGamesModel>[]);
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Container(
                              color: Colors.transparent,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Header Bar
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      16.w,
                                      topPadding + 8.h,
                                      16.w,
                                      14.h,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Left: Back Button + Title
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                HapticFeedback.lightImpact();
                                                AutoRouter.of(context).maybePop();
                                              },
                                              child: Container(
                                                width: 40.w,
                                                height: 40.w,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(15.r),
                                                  border: Border.all(
                                                    color: const Color(0xFFF1F5F9),
                                                    width: 1.2,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
                                                      blurRadius: 10,
                                                      offset: const Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  Icons.arrow_back_rounded,
                                                  color: const Color(0xFFAB31DE),
                                                  size: 22.sp,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12.w),
                                            Text(
                                              'Play Games',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF1E1B4B),
                                                fontSize: 18.5.sp,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Right: "How To?" Button
                                        GestureDetector(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            LaunchUrl.inWeb(
                                              url: SplashService.getTutorialUrl(
                                                'playGames',
                                                SplashService.urlConfig.playGamesTutorial,
                                              ),
                                              context: context,
                                            );
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12.w,
                                              vertical: 8.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFAF5FF),
                                              borderRadius: BorderRadius.circular(14.r),
                                              border: Border.all(
                                                color: const Color(0xFFF3E8FF),
                                                width: 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFAB31DE).withValues(alpha: 0.05),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.help_outline_rounded,
                                                  color: const Color(0xFFAB31DE),
                                                  size: 15.sp,
                                                ),
                                                SizedBox(width: 5.w),
                                                Text(
                                                  'How To?',
                                                  style: GoogleFonts.outfit(
                                                    color: const Color(0xFFAB31DE),
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 4.h),

                                  // Screen Banner (Admin Configurable 700x200 with AD badge)
                                  const ScreenBannerWidget(
                                    screenKey: 'playGamesScreen',
                                    margin: EdgeInsets.only(left: 16, right: 16, bottom: 12),
                                  ),

                                  // Sub-Category Filter Chips Row
                                  if (categories.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 16.h),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                                        physics: const BouncingScrollPhysics(),
                                        child: Row(
                                          children: [
                                            _FilterChip(
                                              label: 'All',
                                              isSelected: selectedCategory == null,
                                              onTap: () {
                                                HapticFeedback.lightImpact();
                                                ref.read(selectedCategoryProvider.notifier).state = null;
                                              },
                                            ),
                                            for (final category in categories) ...[
                                              SizedBox(width: 8.w),
                                              _FilterChip(
                                                label: category,
                                                isSelected: selectedCategory == category,
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  ref.read(selectedCategoryProvider.notifier).state = category;
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Game Cards List Matching Uploaded Screenshot 1-to-1
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                                    child: offers.isEmpty
                                        ? Padding(
                                            padding: EdgeInsets.symmetric(vertical: 40.h),
                                            child: const NoDailyTask(),
                                          )
                                        : ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            padding: EdgeInsets.only(bottom: 32.h),
                                            itemCount: filteredGames.length,
                                            separatorBuilder: (_, __) => SizedBox(height: 12.h),
                                            itemBuilder: (context, index) {
                                              final item = filteredGames[index];
                                              final card = _ExecutiveGameCard(
                                                key: ValueKey(item.offerId),
                                                game: item,
                                                onPlay: () async {
                                                  isTracking.value = true;
                                                  clickTime.value = DateTime.now();
                                                  selectedTask.value = item;

                                                  if (context.mounted) {
                                                    LaunchUrl.inWeb(
                                                      url: item.redirectionUrl,
                                                      context: context,
                                                    );
                                                  }
                                                },
                                              );

                                              if (index == 1) {
                                                return Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    card,
                                                    ToponNativeAdCard(
                                                      isEnabled: AdKeys.isPlayGamesNativeEnabled,
                                                      margin: EdgeInsets.only(top: 12.h),
                                                    ),
                                                  ],
                                                );
                                              }

                                              return card;
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                error: (_, __) => const NoDailyTask(),
                loading: () => const _PlayGamesGridShimmer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SUB-CATEGORY FILTER CHIP
// ---------------------------------------------------------------------------
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        height: 36.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFFE39FFF),
                    Color(0xFFAB31DE),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : const Color(0xFFF1F5F9),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EXECUTIVE GAME CARD (MATCHING USER'S UPLOADED SCREENSHOT 1-TO-1)
// ---------------------------------------------------------------------------
class _ExecutiveGameCard extends StatefulWidget {
  final PlayGamesModel game;
  final VoidCallback onPlay;

  const _ExecutiveGameCard({
    super.key,
    required this.game,
    required this.onPlay,
  });

  @override
  State<_ExecutiveGameCard> createState() => _ExecutiveGameCardState();
}

class _ExecutiveGameCardState extends State<_ExecutiveGameCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    String formatTime(int seconds) {
      if (seconds <= 0) return '30 Sec';
      if (seconds < 60) return '$seconds Sec';
      final mins = seconds ~/ 60;
      final rem = seconds % 60;
      if (rem == 0) return '$mins Minutes';
      return '$mins m $rem s';
    }

    final durationText = formatTime(game.trackingTime);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onPlay();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: const Color(0xFFF1F5F9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
          child: Column(
            children: [
              // Top Row: Icon + Game Title + Easy Tag
              Row(
                children: [
                  // Game Icon
                  Container(
                    width: 58.w,
                    height: 58.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.r),
                      child: InternetImage(
                        url: game.imagePath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  SizedBox(width: 12.w),

                  // Game Title
                  Expanded(
                    child: Text(
                      game.offerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 16.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),

                  SizedBox(width: 8.w),

                  // Difficulty Tag (Easy)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4EA),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      game.category.isNotEmpty ? game.category : 'Easy',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E8E3E),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 14.h),

              // Bottom Row: Stopwatch Pill + Coin Pill + Play Button
              Row(
                children: [
                  // ⏱️ Stopwatch Pill
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: const Color(0xFF2E7D32),
                          size: 14.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          durationText,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF2E7D32),
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ▶️ Play Button
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF48C78E),
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF48C78E).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Play',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SHIMMER SKELETON FOR GAME CARDS LIST
// ---------------------------------------------------------------------------
class _PlayGamesGridShimmer extends StatelessWidget {
  const _PlayGamesGridShimmer();

  static const Color _shimmerBase = Color(0xFFF8FAFC);
  static const Color _shimmerHighlight = Color(0xFFF1F5F9);

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    double borderRadius = 12.0,
  }) {
    return ShimmerTag(
      type: ShimmerType.pulse,
      baseColor: _shimmerBase,
      highlightColor: _shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius.r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, topPadding + 8.h, 16.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Bar Shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildSkeletonBox(width: 40.w, height: 40.w, borderRadius: 15.r),
                  SizedBox(width: 12.w),
                  _buildSkeletonBox(width: 120.w, height: 22.h, borderRadius: 6.r),
                ],
              ),
              _buildSkeletonBox(width: 80.w, height: 36.h, borderRadius: 14.r),
            ],
          ),

          SizedBox(height: 16.h),

          // 2. Filter Chips Shimmer
          Row(
            children: [
              _buildSkeletonBox(width: 50.w, height: 36.h, borderRadius: 12.r),
              SizedBox(width: 8.w),
              _buildSkeletonBox(width: 75.w, height: 36.h, borderRadius: 12.r),
              SizedBox(width: 8.w),
              _buildSkeletonBox(width: 80.w, height: 36.h, borderRadius: 12.r),
            ],
          ),

          SizedBox(height: 18.h),

          // 3. List Shimmer
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: 4,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(
                    color: const Color(0xFFF1F5F9),
                    width: 1.2,
                  ),
                ),
                padding: EdgeInsets.all(14.r),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildSkeletonBox(width: 58.w, height: 58.w, borderRadius: 16.r),
                        SizedBox(width: 12.w),
                        _buildSkeletonBox(width: 140.w, height: 18.h, borderRadius: 6.r),
                        const Spacer(),
                        _buildSkeletonBox(width: 45.w, height: 22.h, borderRadius: 10.r),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    Row(
                      children: [
                        _buildSkeletonBox(width: 80.w, height: 28.h, borderRadius: 12.r),
                        SizedBox(width: 8.w),
                        _buildSkeletonBox(width: 55.w, height: 28.h, borderRadius: 12.r),
                        const Spacer(),
                        _buildSkeletonBox(width: 75.w, height: 32.h, borderRadius: 12.r),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

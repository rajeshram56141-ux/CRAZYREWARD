import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../../services/launch_url.dart';
import '../../../../../services/analytics_service.dart';
import '../../../../../utils/constant/constant.dart';
import '../../../../../utils/helper/helper.dart';
import '../../../../../widgets/common/internet_image.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';
import 'daily_task_model.dart';
import 'daily_task_popup.dart';
import 'daily_task_provider.dart';

@RoutePage()
class DailyTaskDetailsScreen extends HookConsumerWidget {
  const DailyTaskDetailsScreen({
    super.key,
    required this.item,
    required this.cardColor,
    required this.userId,
    required this.email,
    required this.country,
    this.heroTag,
  });

  final DailyTaskModel item;
  final Color cardColor;
  final String userId;
  final String email;
  final String country;
  final String? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final topPadding = MediaQuery.of(context).padding.top;

    final animController = useAnimationController(
      duration: const Duration(milliseconds: 500),
    );

    final parsedOfferType = item.offerType.toLowerCase().contains('watch')
        ? DailyTaskType.watchEarn
        : DailyTaskType.dailyTask;

    final taskParam = (
      userId: userId,
      email: email,
      countryCode: country,
      offerType: parsedOfferType,
    );

    useEffect(() {
      animController.forward();
      Future.microtask(() async {
        ref.invalidate(dailyTaskProvider(taskParam));
        await ref.read(dailyTaskProvider(taskParam).future).catchError((_) => <DailyTaskModel>[]);
      });
      return null;
    }, [item.offerId, userId]);

    final contentFadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animController,
      curve: Curves.easeOut,
    ));

    final taskListAsync = ref.watch(dailyTaskProvider(taskParam));
    final liveItem = taskListAsync.maybeWhen(
      data: (offers) {
        return offers.firstWhere(
          (o) => o.offerId == item.offerId,
          orElse: () => item,
        );
      },
      orElse: () => item,
    );

    // Calculate total coins
    final totalEventCoins = (liveItem.hasEvents && liveItem.events.isNotEmpty)
        ? liveItem.events.fold<int>(0, (sum, e) => sum + e.coins)
        : 0;
    final displayCoins = totalEventCoins > 0 ? totalEventCoins : liveItem.coins;

    final userAsync = ref.watch(DashboardService.userDataProvider(userId));
    final String rawName = userAsync.value?.name ?? '';
    final String userName = rawName.trim().isNotEmpty ? rawName.trim() : 'User';

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
              child: Container(
                color: Colors.white,
              ),
            ),

            // 2. Main Scrollable Content
            Positioned.fill(
              child: FadeTransition(
                opacity: contentFadeAnim,
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
                              // Executive Header Section (Matching Screenshot Mockup 1-to-1)
                              _TopHeroHeaderSection(
                                item: liveItem,
                                topPadding: topPadding,
                                displayCoins: displayCoins,
                                userName: userName,
                              ),

                              SizedBox(height: 12.h),

                              // Golden Coins Promo Banner Strip (Complete all tasks & earn upto X Coins!)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: _PromoBannerStrip(displayCoins: displayCoins),
                              ),

                              SizedBox(height: 14.h),



                              // "Task & Rewards" Stepper Section Header
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Instruction',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF1E1B4B),
                                        fontSize: 15.5.sp,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    if (liveItem.cleanSubtitle.isNotEmpty) ...[
                                      SizedBox(height: 4.h),
                                      Text(
                                        liveItem.cleanSubtitle,
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF64748B),
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              SizedBox(height: 12.h),

                              // Connected Stepper Roadmap List
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: _TaskStepperRoadmapCard(item: liveItem),
                              ),

                              // Disclaimer Section
                              if (liveItem.offerDisclaimer.isNotEmpty ||
                                  SplashService.defaultDisclaimer.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 0),
                                  child: _DisclaimerCard(
                                    disclaimers: liveItem.offerDisclaimer,
                                  ),
                                ),

                              // Bottom spacing for floating sticky action bar
                              SizedBox(
                                height: MediaQuery.of(context).padding.bottom + 95.h,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 3. Bottom Sticky Floating Action Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomTaskActionBar(
                item: liveItem,
                userId: userId,
                email: email,
                displayCoins: displayCoins,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TOP HERO HEADER SECTION (EXACT MOCKUP CARD WITH DAILY TASK BLUR ICON)
// ---------------------------------------------------------------------------
class _TopHeroHeaderSection extends StatelessWidget {
  const _TopHeroHeaderSection({
    required this.item,
    required this.topPadding,
    required this.displayCoins,
    required this.userName,
  });

  final DailyTaskModel item;
  final double topPadding;
  final int displayCoins;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Navigation Bar
        Padding(
          padding: EdgeInsets.fromLTRB(
            16.w,
            topPadding + 8.h,
            16.w,
            12.h,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hi 👋',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        userName,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 17.5.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (item.dailyReset)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: const Color(0xFFE39FFF).withValues(alpha: 0.8),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.autorenew_rounded,
                        color: const Color(0xFFAB31DE),
                        size: 14.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Daily Refresh',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFAB31DE),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Hero Card Container (Matching User Screenshot 1-to-1)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(
            height: 110.h,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: const Color(0xFFF3E8FF),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: const Color(0xFFAB31DE).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 1. CLEARLY VISIBLE BACKGROUND ICON (assets/icons/daily task blur.png enlarged with light depth blur & 50% opacity)
                Positioned(
                  right: -14.w,
                  top: -12.h,
                  bottom: -12.h,
                  width: 160.w,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                    child: Opacity(
                      opacity: 0.5,
                      child: Image.asset(
                        'assets/icons/daily task blur.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/icons/coin.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. CRISP FOREGROUND 3D BUCKET ASSET
                Positioned(
                  right: -6.w,
                  top: -2.h,
                  bottom: -2.h,
                  width: 135.w,
                  child: Image.asset(
                    'assets/icons/daily task blur.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.centerRight,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/icons/coin.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // 3. Foreground Left Content: App Logo + Title + Subtitle + Ratings/Downloads
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 10.h, 130.w, 10.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // App Logo
                        Container(
                          width: 60.w,
                          height: 60.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15.r),
                            border: Border.all(
                              color: const Color(0xFFF3E8FF),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15.r),
                            child: InternetImage(
                              url: item.imagePath,
                              width: 60.w,
                              height: 60.w,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),

                        // Title, Subtitle, Meta Chips Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.offerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF1E1B4B),
                                  fontSize: 15.5.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 4.h),

                              // Meta Chips Row (Rating ⭐ 4.5 & 📥 10M+ & Tag)
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 4.h,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (item.rating.trim().isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color: const Color(0xFFEAB308),
                                          size: 13.sp,
                                        ),
                                        SizedBox(width: 2.w),
                                        Text(
                                          item.rating.trim(),
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF475569),
                                            fontSize: 10.5.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (item.downloads.trim().isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.file_download_outlined,
                                          color: const Color(0xFF9333EA),
                                          size: 13.sp,
                                        ),
                                        SizedBox(width: 2.w),
                                        Text(
                                          item.downloads.trim(),
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF475569),
                                            fontSize: 10.5.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (!item.dailyReset && item.offerCategory.trim().isNotEmpty)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF5FF),
                                        borderRadius: BorderRadius.circular(6.r),
                                        border: Border.all(
                                          color: const Color(0xFFE39FFF).withValues(alpha: 0.6),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        item.offerCategory.trim(),
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFFAB31DE),
                                          fontSize: 9.5.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              if (item.watchTutorial.trim().isNotEmpty) ...[
                                SizedBox(height: 5.h),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    LaunchUrl.inWeb(
                                      url: item.watchTutorial.trim(),
                                      context: context,
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 7.w,
                                      vertical: 2.5.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: const Color(0xFFFECACA),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: const Color(0xFFEF4444),
                                          size: 11.sp,
                                        ),
                                        SizedBox(width: 3.w),
                                        Text(
                                          'Watch Tutorial',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFEF4444),
                                            fontSize: 9.5.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// GOLDEN COINS PROMO BANNER STRIP (Exact Screenshot Mockup Banner)
// ---------------------------------------------------------------------------
class _PromoBannerStrip extends StatelessWidget {
  const _PromoBannerStrip({required this.displayCoins});

  final int displayCoins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFEF9C3),
            Color(0xFFFEF3C7),
            Color(0xFFFDE68A),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFFDE047).withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Left Gold Coins Graphic
          Image.asset(
            'assets/icons/coin.png',
            width: 32.w,
            height: 32.w,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 10.w),

          // Center Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Complete all steps requirement and get up to',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF78350F),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${displayCoins.formatCoins()} Coins!',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          // Right Gold Coins Graphic Stack
          Image.asset(
            'assets/icons/coin.png',
            width: 36.w,
            height: 36.w,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}



// ---------------------------------------------------------------------------
// CONNECTED STEPPER ROADMAP CARD (MATCHING MOCKUP 1-TO-1)
// ---------------------------------------------------------------------------
class _TaskStepperRoadmapCard extends StatelessWidget {
  const _TaskStepperRoadmapCard({required this.item});

  final DailyTaskModel item;

  IconData _getStepIcon(int index, String title) {
    final t = title.toLowerCase();
    if (t.contains('download') || t.contains('install') || index == 1) {
      return Icons.install_mobile_rounded;
    } else if (t.contains('crown') || index == 2) {
      return Icons.workspace_premium_rounded;
    } else if (t.contains('play') || t.contains('game') || index == 3) {
      return Icons.sports_esports_rounded;
    } else if (t.contains('level') || t.contains('upgrade') || index == 4) {
      return Icons.military_tech_rounded;
    }
    return Icons.emoji_events_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMultiEvent = item.hasEvents && item.events.isNotEmpty;
    final List<_StepItemData> steps = [];

    if (isMultiEvent) {
      for (int i = 0; i < item.events.length; i++) {
        final event = item.events[i];
        final index = i + 1;
        final displayLabel = event.label.trim().isNotEmpty
            ? event.label.trim()
            : (item.dailyRewardEnabled ? 'Day $index' : 'Reach Level $index');

        final duration = event.timerDuration > 0
            ? event.timerDuration
            : item.timerDuration;

        String eventDescription = event.name.trim();
        eventDescription = eventDescription
            .replaceAll(
              RegExp(r'^Day\s*\d+\s*[\-\:\(]*\s*', caseSensitive: false),
              '',
            )
            .replaceAll(RegExp(r'\s*\)$'), '')
            .trim();

        if (eventDescription.isEmpty ||
            eventDescription.toLowerCase() == 'task') {
          if (duration > 0) {
            if (duration >= 60) {
              final mins = duration ~/ 60;
              final secs = duration % 60;
              eventDescription = secs == 0
                  ? 'Use app for $mins min${mins > 1 ? 's' : ''}'
                  : 'Use app for $mins min $secs sec';
            } else {
              eventDescription = 'Use app for $duration seconds';
            }
          } else {
            eventDescription = 'Complete this task in app';
          }
        }

        final bool isStepCompleted = event.completed ||
            event.status.toLowerCase() == 'completed' ||
            event.status.toLowerCase() == 'success' ||
            event.status.toLowerCase() == 'claimed';

        steps.add(_StepItemData(
          stepNumber: index,
          title: displayLabel,
          subtitle: eventDescription,
          coins: event.coins,
          isCompleted: isStepCompleted,
          icon: _getStepIcon(index, displayLabel),
        ));
      }
    } else if (item.offerDescription.isNotEmpty) {
      for (int i = 0; i < item.offerDescription.length; i++) {
        final index = i + 1;
        final raw = item.offerDescription[i].trim();
        String title = '';
        String subtitle = '';

        if (raw.contains(':::')) {
          final parts = raw.split(':::');
          title = parts[0].trim();
          subtitle = parts.length > 1 ? parts[1].trim() : '';
        } else {
          title = raw;
          subtitle = '';
        }

        if (title.isEmpty) {
          title = index == 1
              ? 'Download & Install App'
              : (index == 2 ? 'Open & Play Game' : 'Step $index');
        }

        steps.add(_StepItemData(
          stepNumber: index,
          title: title,
          subtitle: subtitle,
          coins: 0,
          isCompleted: false,
          icon: _getStepIcon(index, title),
        ));
      }
    } else {
      steps.add(_StepItemData(
        stepNumber: 1,
        title: 'Download & install the Game',
        subtitle: 'Install and open the game for the first time',
        coins: 0,
        isCompleted: false,
        icon: Icons.install_mobile_rounded,
      ));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final bool isCompleted = step.isCompleted;

        return Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isCompleted
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFF1F5F9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left Step Number / Check Circle Container Inside Card
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isCompleted ? const Color(0xFF86EFAC) : const Color(0xFFF3E8FF),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isCompleted
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: const Color(0xFF16A34A),
                          size: 20.sp,
                        )
                      : Text(
                          '${step.stepNumber}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF9333EA),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),

                        SizedBox(width: 10.w),

                        // Center: Title & Subtitle Instruction
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                step.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF1E1B4B),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (step.subtitle.isNotEmpty) ...[
                                SizedBox(height: 2.h),
                                Text(
                                  step.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF64748B),
                                    fontSize: 10.5.sp,
                                    fontWeight: FontWeight.w400,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        SizedBox(width: 6.w),

                        // Right: Coins Pill + Status Text (✓ Collected / In Progress)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/icons/coin.png',
                                    width: 11.sp,
                                    height: 11.sp,
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    '${(step.coins > 0 ? step.coins : item.coins).formatCoins()} Coins',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF78350F),
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCompleted) ...[
                              SizedBox(height: 2.h),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    color: const Color(0xFF16A34A),
                                    size: 11.sp,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    'Collected',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF16A34A),
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
  }
}

class _StepItemData {
  final int stepNumber;
  final String title;
  final String subtitle;
  final int coins;
  final bool isCompleted;
  final IconData icon;

  _StepItemData({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.coins,
    required this.isCompleted,
    required this.icon,
  });
}

// ---------------------------------------------------------------------------
// DISCLAIMER CARD
// ---------------------------------------------------------------------------
class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({this.disclaimers = const []});

  final List<String> disclaimers;

  @override
  Widget build(BuildContext context) {
    final textList = disclaimers.where((d) => d.trim().isNotEmpty).toList();
    final displayList = textList.isNotEmpty
        ? textList
        : SplashService.defaultDisclaimer
            .where((d) => d.trim().isNotEmpty)
            .toList();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFF3E8FF),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: const Color(0xFFAB31DE),
                size: 15.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                'Notice & Disclaimer',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1E1B4B),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          if (displayList.isNotEmpty)
            ...displayList.map(
              (d) => Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFAB31DE),
                        fontSize: 11.sp,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        d,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 11.sp,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              'Complete all instructions to earn rewards. Rewards are credited following advertiser verification.',
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 11.sp,
                height: 1.3,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BOTTOM TASK ACTION BAR (MATCHING DUAL-ACTION PILL DESIGN FROM MOCKUP)
// ---------------------------------------------------------------------------
class _BottomTaskActionBar extends HookConsumerWidget {
  const _BottomTaskActionBar({
    required this.item,
    required this.userId,
    required this.email,
    required this.displayCoins,
  });

  final DailyTaskModel item;
  final String userId;
  final String email;
  final int displayCoins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = useMemoized(() => GetStorage());
    final isInstalled = useState<bool>(false);
    final isSubmitting = useState<bool>(false);
    final isPostbackDone = useState<bool>(false);
    final isDialogShowing = useState<bool>(false);

    final wasTaskRedirected = useState<bool>(storage.read<bool>('redirected_${item.offerId}') ?? false);
    final pendingRedirection = useState<bool>(false);
    final proofStatus = useState<String>('none');
    final proofReason = useState<String>('');
    final isUploadingScreenshot = useState<bool>(false);

    useEffect(() {
      if (item.screenshotVerificationEnabled && userId.isNotEmpty) {
        Future.microtask(() async {
          try {
            final response = await http.post(
              Uri.parse('${AppConst.serverBaseUrl}/app/get-task-screenshot-status'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'userId': userId,
                'offerId': item.offerId,
              }),
            );
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['status'] != null) {
                proofStatus.value = json['status'];
                if (json['proof'] != null) {
                  proofReason.value = json['proof']['rejectionReason'] ?? '';
                }
              }
            }
          } catch (_) {}
        });
      }
      return null;
    }, [item.offerId, userId]);

    final lifecycleState = useAppLifecycleState();

    DailyTaskEvent? activeEvent;
    if (item.dailyRewardEnabled) {
      for (final e in item.events) {
        if (e.status == 'active') {
          activeEvent = e;
          break;
        }
      }
    }
    final incompleteEvents = item.dailyRewardEnabled
        ? <DailyTaskEvent>[]
        : item.events.where((e) => !e.completed).toList();
    final currentEvent =
        incompleteEvents.isNotEmpty ? incompleteEvents.first : null;

    final requiredDuration = (activeEvent != null && activeEvent.timerDuration > 0)
        ? activeEvent.timerDuration
        : ((currentEvent != null && currentEvent.timerDuration > 0)
            ? currentEvent.timerDuration
            : item.timerDuration);

    final allEventsCompletedToday = item.events.isNotEmpty &&
        item.events.every((e) => e.completed || e.status == 'completed');

    final isFullyCompleted = !item.dailyReset &&
        ((!item.dailyRewardEnabled &&
                currentEvent == null &&
                allEventsCompletedToday) ||
            (item.dailyRewardEnabled && allEventsCompletedToday));

    final isEligibleNextDay = (item.dailyRewardEnabled &&
            !isFullyCompleted &&
            activeEvent == null) ||
        (item.dailyReset && allEventsCompletedToday);

    final isCompleted = isFullyCompleted || isEligibleNextDay;

    Future<void> triggerPostback() async {
      if (isSubmitting.value || isPostbackDone.value) return;
      isSubmitting.value = true;

      final currentEventId = activeEvent?.eventId ?? currentEvent?.eventId;
      final errorMessage = await DailyTaskService.dailyTaskPostback(
        userId: userId,
        email: email,
        offerId: item.offerId,
        appName: SplashService.appName.lows(),
        packageName: item.packageEnabled ? item.packageName : null,
        elapsedSeconds: item.timerEnabled ? requiredDuration : null,
        eventId: currentEventId,
      );

      if (errorMessage == null) {
        final earnedCoins = activeEvent?.coins ?? item.coins;
        AnalyticsService.logCustomEvent(
          'complete_daily_task',
          parameters: {
            'userId': userId,
            'offerId': item.offerId,
            'coins': earnedCoins,
          },
        );
        isPostbackDone.value = true;
        storage.remove('timer_${item.offerId}_elapsed');
        storage.remove('timer_${item.offerId}_start_time');
        storage.remove('timer_${item.offerId}_running');
        storage.remove('redirected_${item.offerId}');

        final remainingDays = item.events.where((e) => e.eventId != currentEventId && e.status != 'completed' && !e.completed).toList();
        if (isFullyCompleted || !item.dailyRewardEnabled || remainingDays.isEmpty) {
          storage.remove('started_${item.offerId}');
        } else {
          storage.write('started_${item.offerId}', true);
        }

        ref.invalidate(dailyTaskProvider);

        if (context.mounted) {
          DailyTaskPopup.showSuccess(
            context: context,
            title: 'Task Completed!',
            message: (item.dailyRewardEnabled && remainingDays.isNotEmpty)
                ? 'Congratulations! +${earnedCoins.formatCoins()} Coins added to your account. Next day milestone will unlock tomorrow at 12:00 AM IST!'
                : 'Congratulations! +${earnedCoins.formatCoins()} Coins added to your account.',
            onDismiss: () {
              if (context.mounted) {
                context.router.maybePop();
              }
            },
          );
        }
      } else {
        isSubmitting.value = false;
        if (context.mounted) {
          DailyTaskPopup.showTaskNotCompleted(
            context: context,
            message: errorMessage,
          );
        }
      }
    }

    Future<void> checkTaskStatus(bool isResume) async {
      if (isSubmitting.value || isPostbackDone.value) return;

      final wasRedirected =
          storage.read<bool>('redirected_${item.offerId}') ?? false;
      final wasRunning =
          storage.read<bool>('timer_${item.offerId}_running') ?? false;

      if (!wasRedirected && !wasRunning) return;

      if (item.packageEnabled) {
        final installed = await AppManager.isAppInstalled(item.packageName);
        isInstalled.value = installed;

        if (installed) {
          if (item.timerEnabled && requiredDuration > 0) {
            final savedRunning =
                storage.read<bool>('timer_${item.offerId}_running') ?? false;
            final savedStartTimeMs =
                storage.read<int>('timer_${item.offerId}_start_time');

            DateTime? calculatedStart;
            if (savedRunning && savedStartTimeMs != null) {
              calculatedStart =
                  DateTime.fromMillisecondsSinceEpoch(savedStartTimeMs);
            } else {
              final installTimeMs =
                  await AppManager.getInstallTime(item.packageName);
              final redirected =
                  storage.read<bool>('redirected_${item.offerId}') ?? false;
              if (installTimeMs > 0 && redirected) {
                calculatedStart =
                    DateTime.fromMillisecondsSinceEpoch(installTimeMs);
              }
            }

            if (calculatedStart != null) {
              final hasPerm = await AppManager.checkUsagePermission();
              if (!hasPerm) {
                storage.write('timer_${item.offerId}_running', false);
                return;
              }

              final usageSec = await AppManager.getAppUsageDuration(
                item.packageName,
                calculatedStart.millisecondsSinceEpoch,
              );

              if (usageSec >= requiredDuration) {
                storage.write('timer_${item.offerId}_running', false);
                await triggerPostback();
              } else {
                if (isResume && context.mounted && !isDialogShowing.value) {
                  isDialogShowing.value = true;
                  final currentUsage = usageSec > 0 ? usageSec : 0;
                  final usageMessage =
                      'App Usage Incomplete\n\n'
                      '⏱️ Completed: ${currentUsage}s out of ${requiredDuration}s\n\n'
                      'Please open and use the app for the full duration to claim your reward.';

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    DailyTaskPopup.showTaskNotCompleted(
                      context: context,
                      message: usageMessage,
                      onDismiss: () {
                        isDialogShowing.value = false;
                      },
                    );
                  });
                }
              }
            }
          } else {
            if (!item.hasEvents) {
              await triggerPostback();
            }
          }
        } else {
          final redirected =
              storage.read<bool>('redirected_${item.offerId}') ?? false;
          if (redirected) {
            storage.write('redirected_${item.offerId}', false);
            if (isResume && context.mounted && !isDialogShowing.value) {
              isDialogShowing.value = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                DailyTaskPopup.showAppNotInstalled(
                  context: context,
                  message:
                      'The app is not installed yet. Please install the app to complete the task and receive your coins.',
                  onDismiss: () {
                    isDialogShowing.value = false;
                  },
                );
              });
            }
          }
        }
      } else {
        if (item.timerEnabled && requiredDuration > 0) {
          final savedRunning =
              storage.read<bool>('timer_${item.offerId}_running') ?? false;
          final savedStartTimeMs =
              storage.read<int>('timer_${item.offerId}_start_time');
          final wasRedirected =
              storage.read<bool>('redirected_${item.offerId}') ?? false;

          if (savedRunning || wasRedirected) {
            final savedStart = savedStartTimeMs != null
                ? DateTime.fromMillisecondsSinceEpoch(savedStartTimeMs)
                : DateTime.now();

            final diff = DateTime.now().difference(savedStart).inSeconds;

            if (diff >= requiredDuration) {
              storage.write('timer_${item.offerId}_running', false);
              storage.remove('timer_${item.offerId}_start_time');
              storage.write('redirected_${item.offerId}', false);
              await triggerPostback();
            } else {
              if (isResume && context.mounted && !isDialogShowing.value) {
                isDialogShowing.value = true;
                final currentDiff = diff > 0 ? diff : 0;
                storage.remove('timer_${item.offerId}_start_time');
                storage.remove('timer_${item.offerId}_running');
                storage.write('redirected_${item.offerId}', false);

                final timerMessage =
                    'Task Timer Incomplete\n\n'
                    '⏱️ Completed: ${currentDiff}s out of ${requiredDuration}s\n\n'
                    'Please stay on the page for the full duration to claim your reward.';

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  DailyTaskPopup.showTaskNotCompleted(
                    context: context,
                    message: timerMessage,
                    onDismiss: () {
                      isDialogShowing.value = false;
                    },
                  );
                });
              }
            }
          }
        } else {
          storage.write('redirected_${item.offerId}', false);
        }
      }
    }

    useEffect(() {
      if (item.packageEnabled && item.packageName.trim().isNotEmpty) {
        AppManager.isAppInstalled(item.packageName.trim()).then((installed) {
          isInstalled.value = installed;
          if (installed) {
            final started = storage.read<bool>('started_${item.offerId}') ?? false;
            final redirected = storage.read<bool>('redirected_${item.offerId}') ?? false;
            final hasProgress = started ||
                redirected ||
                (item.hasEvents &&
                    item.events.any((e) => e.completed || e.status == 'completed'));
            if (!hasProgress) {
              storage.write('pre_installed_${item.offerId}', true);
              storage.write('pre_installed_pkg_${item.packageName.trim()}', true);
            }
          }
        });
      }
      checkTaskStatus(false);
      return null;
    }, []);

    useEffect(() {
      if (lifecycleState == AppLifecycleState.resumed) {
        if (item.packageEnabled && item.packageName.trim().isNotEmpty) {
          AppManager.isAppInstalled(item.packageName.trim()).then((installed) {
            isInstalled.value = installed;
          });
        }
        if (pendingRedirection.value) {
          pendingRedirection.value = false;
          wasTaskRedirected.value = true;
          storage.write('redirected_${item.offerId}', true);
        }
        checkTaskStatus(true);
      }
      return null;
    }, [lifecycleState]);

    Future<void> onStartTaskTap() async {
      if (isSubmitting.value) return;

      if (isFullyCompleted) {
        if (item.dailyReset) {
          DailyTaskPopup.showSuccess(
            context: context,
            title: 'Completed for Today!',
            message:
                'You have completed all milestones for today! This task will refresh and become eligible again tomorrow at 12:00 AM IST.',
          );
        } else {
          DailyTaskPopup.showSuccess(
            context: context,
            title: 'Task Completed!',
            message:
                'You have already completed this task and earned all rewards.',
          );
        }
        return;
      }

      if (isEligibleNextDay) {
        DailyTaskPopup.showSuccess(
          context: context,
          title: 'Eligible Next Day',
          message:
              'You have completed today\'s milestone! The next day task will unlock tomorrow at 12:00 AM IST.',
        );
        return;
      }

      if (item.packageEnabled) {
        final wasPreInstalled =
            (storage.read<bool>('pre_installed_${item.offerId}') ?? false) ||
            (storage.read<bool>('pre_installed_pkg_${item.packageName}') ?? false);
        if (wasPreInstalled) {
          if (context.mounted) {
            DailyTaskPopup.showTaskNotCompleted(
              context: context,
              message:
                  'This offer is only for new users. This app was already installed on your device.',
            );
          }
          return;
        }
      }

      storage.write('started_${item.offerId}', true);
      final eventId = activeEvent?.eventId ?? currentEvent?.eventId ?? '';

      if (item.packageEnabled) {
        final needsUsagePermission =
            item.timerEnabled || item.dailyRewardEnabled;
        if (needsUsagePermission) {
          final hasPermission = await AppManager.checkUsagePermission();
          if (!hasPermission) {
            if (context.mounted) {
              await DailyTaskPopup.showUsagePermission(
                context: context,
                onAllow: () async {
                  await AppManager.openUsageSettings();
                },
              );
            }
            return;
          }
        }

        final installed = await AppManager.isAppInstalled(item.packageName);
        isInstalled.value = installed;

        if (installed) {
          final launched = await AppManager.launchApp(item.packageName);
          if (launched) {
            if (item.timerEnabled) {
              storage.write('timer_${item.offerId}_running', true);
              storage.write(
                'timer_${item.offerId}_start_time',
                DateTime.now().millisecondsSinceEpoch,
              );
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to open app. Please try again.'),
                ),
              );
            }
          }
        } else {
          final url = item.redirectionUrl.isEmpty
              ? 'https://play.google.com/store'
              : item.getRedirectionUrlForEvent(eventId);

          if (context.mounted) {
            await LaunchUrl.inWeb(url: url, context: context);
          }
        }
      } else {
        if (item.timerEnabled) {
          storage.write('timer_${item.offerId}_running', true);
          storage.write(
            'timer_${item.offerId}_start_time',
            DateTime.now().millisecondsSinceEpoch,
          );
        }
        final url = item.getRedirectionUrlForEvent(eventId);
        if (context.mounted) {
          await LaunchUrl.inWeb(url: url, context: context);
        }
      }
    }

    String getButtonText() {
      if (isFullyCompleted) {
        if (item.dailyReset) {
          return 'Eligible Next Day';
        }
        return 'Completed';
      }
      if (isEligibleNextDay) {
        return 'Eligible Next Day';
      }
      if (isSubmitting.value) return 'Submitting...';
      if (item.packageEnabled && item.packageName.trim().isNotEmpty) {
        final wasPreInstalled =
            (storage.read<bool>('pre_installed_${item.offerId}') ?? false) ||
            (storage.read<bool>('pre_installed_pkg_${item.packageName}') ?? false);
        if (wasPreInstalled) {
          return 'Not Eligible';
        }
        if (isInstalled.value) {
          return 'Open App';
        }
        if (item.redirectionUrl.isEmpty) {
          return 'Open Store';
        }
      }
      return 'Start';
    }

    Future<void> handleUploadScreenshot() async {
      // Package verification check
      if (item.packageEnabled && item.packageName.trim().isNotEmpty) {
        final installed = await AppManager.isAppInstalled(item.packageName.trim());
        if (!installed) {
          if (!context.mounted) return;
          DailyTaskPopup.showTaskNotCompleted(
            context: context,
            message: 'Targeted app installation requirement not fulfilled. Please install the app first before uploading screenshot proof.',
          );
          return;
        }
      }

      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image == null) return;

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (dialogCtx) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
            backgroundColor: Colors.white,
            elevation: 8,
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Confirm Screenshot Proof',
                    style: GoogleFonts.outfit(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E1B4B),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: Image.file(
                      File(image.path),
                      height: 210.h,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'Submit this screenshot proof for admin verification and reward processing?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 13.sp, color: const Color(0xFF64748B)),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFAB31DE),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          onPressed: () async {
                            Navigator.pop(dialogCtx);
                            isUploadingScreenshot.value = true;
                            try {
                              final request = http.MultipartRequest(
                                'POST',
                                Uri.parse('${AppConst.serverBaseUrl}/app/submit-task-screenshot'),
                              );
                              request.fields['userId'] = userId;
                              request.fields['userEmail'] = email;
                              request.fields['appName'] = 'crazyreward';
                              request.fields['offerId'] = item.offerId;
                              request.fields['offerName'] = item.offerName;
                              request.fields['coins'] = '${item.coins}';

                              request.files.add(
                                await http.MultipartFile.fromPath('screenshot', image.path),
                              );

                              final streamedRes = await request.send();
                              final res = await http.Response.fromStream(streamedRes);

                              if (res.statusCode == 200) {
                                proofStatus.value = 'pending';
                                if (context.mounted) {
                                  DailyTaskPopup.showSuccess(
                                    context: context,
                                    title: 'Verification Pending!',
                                    message: 'Your proof has been submitted for admin verification. Reward coins will be credited upon approval.',
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  DailyTaskPopup.showTaskNotCompleted(
                                    context: context,
                                    message: 'Failed to upload screenshot proof. Please try again.',
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                DailyTaskPopup.showTaskNotCompleted(
                                  context: context,
                                  message: 'Network connection error. Please check your internet connection.',
                                );
                              }
                            } finally {
                              isUploadingScreenshot.value = false;
                            }
                          },
                          child: Text(
                            'Submit',
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16.w,
        10.h,
        16.w,
        MediaQuery.of(context).padding.bottom + 12.h,
      ),
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              pendingRedirection.value = true;
              onStartTaskTap();
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 52.h,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE39FFF),
                        Color(0xFFAB31DE),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(26.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: (displayCoins > 0 && !isCompleted)
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left: Coin Reward Pill
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/icons/coin.png',
                                    width: 16.sp,
                                    height: 16.sp,
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${displayCoins.formatCoins()} Coins',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 12.5.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Right: Action Text & Arrow Icon
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSubmitting.value)
                                  SizedBox(
                                    width: 18.w,
                                    height: 18.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else ...[
                                  Text(
                                    getButtonText(),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 15.5.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Icon(
                                    isCompleted
                                        ? (item.dailyReset || isEligibleNextDay
                                            ? Icons.schedule_rounded
                                            : Icons.check_circle_rounded)
                                        : Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 18.sp,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        )
                      : Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSubmitting.value)
                                SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else ...[
                                Text(
                                  getButtonText(),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 15.5.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Icon(
                                  isCompleted
                                      ? (item.dailyReset || isEligibleNextDay
                                          ? Icons.schedule_rounded
                                          : Icons.check_circle_rounded)
                                      : Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18.sp,
                                ),
                              ],
                            ],
                          ),
                        ),
                ),

                // Top-Right Circular White/Black "AD" Badge
                Positioned(
                  top: -4.h,
                  right: 12.w,
                  child: Container(
                    width: 22.w,
                    height: 22.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'AD',
                      style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (item.screenshotVerificationEnabled && (proofStatus.value != 'none' || wasTaskRedirected.value) && !isCompleted) ...[
            SizedBox(height: 10.h),
            if (proofStatus.value == 'pending')
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: const Color(0xFFD97706), size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Verification Pending',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF92400E),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else if (proofStatus.value == 'approved')
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: const Color(0xFF059669), size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Verification Approved',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF065F46),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else if (proofStatus.value == 'rejected_final')
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_rounded, color: const Color(0xFFDC2626), size: 18.sp),
                        SizedBox(width: 8.w),
                        Text(
                          'Verification Rejected (0 Coins)',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF991B1B),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (proofReason.value.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        'Reason: ${proofReason.value}',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFB91C1C),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              )
            else
              GestureDetector(
                onTap: isUploadingScreenshot.value ? null : handleUploadScreenshot,
                child: Container(
                  height: 50.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF7E22CE),
                        Color(0xFF9333EA),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isUploadingScreenshot.value
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.upload_file_rounded, color: Colors.white, size: 19.sp),
                              SizedBox(width: 8.w),
                              Text(
                                proofStatus.value == 'rejected' ? 'RE-UPLOAD SCREENSHOT PROOF' : 'UPLOAD SCREENSHOT PROOF',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
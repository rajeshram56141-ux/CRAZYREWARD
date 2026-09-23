import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/helper/helper.dart';
import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../widgets/common/custom_loading.dart';
import '../../../../../widgets/common/internet_image.dart';
import '../../../../../widgets/common/shimmer_tag.dart';
import '../watch_video/widgets/no_daily_task.dart';
import 'daily_task_model.dart';
import 'daily_task_provider.dart';

@RoutePage()
class DailyTaskScreen extends HookConsumerWidget {
  const DailyTaskScreen({
    super.key,
    required this.country,
    required this.email,
    required this.userId,
    this.tasks,
  });

  final String userId;
  final String email;
  final String country;
  final List<DailyTaskModel>? tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = dailyTaskProvider((
      userId: userId,
      email: email,
      countryCode: country,
      offerType: DailyTaskType.dailyTask,
    ));

    useEffect(() {
      Future.microtask(() async {
        ref.invalidate(provider);
        await ref.read(provider.future).catchError((_) => <DailyTaskModel>[]);
      });
      return null;
    }, [userId]);

    final asyncOffers = ref.watch(provider);

    final selectedFilter = useState<String?>(null);
    final categoriesState = useState<List<String>>([]);

    if (asyncOffers.value != null && asyncOffers.value!.isNotEmpty) {
      final allTypes = {
        for (final o in asyncOffers.value!)
          if (o.offerCategory.trim().isNotEmpty) o.offerCategory.trim(),
      }.toList();
      if (categoriesState.value.length != allTypes.length ||
          !categoriesState.value.every((e) => allTypes.contains(e))) {
        categoriesState.value = allTypes;
      }
    }

    final loadingId = useState<String?>(null);
    final scrollController = useScrollController();
    final topPadding = MediaQuery.of(context).padding.top;

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
            // 1. Clean White Background (Matching Home Screen)
            Positioned.fill(
              child: Container(
                color: Colors.white,
              ),
            ),

            // 2. Main Scrollable Feed
            Positioned.fill(
              child: RefreshIndicator(
                color: const Color(0xFF26262B),
                backgroundColor: Colors.white,
                edgeOffset: topPadding + 60.h,
                onRefresh: () async {
                  try {
                    final _ = await ref.refresh(provider.future);
                  } catch (_) {}
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Bar (Back Button, "Hot Offers" Kaushan Header, History Button)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                16.w,
                                topPadding + 8.h,
                                16.w,
                                10.h,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Left: Back Arrow
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
                                        borderRadius: BorderRadius.circular(14.r),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: const Color(0xFF26262B),
                                        size: 20.sp,
                                      ),
                                    ),
                                  ),

                                  // Center Title: "Hot Offers" (Exact Home Screen Style)
                                  Text(
                                    'Hot Offers',
                                    style: GoogleFonts.kaushanScript(
                                      color: const Color(0xFF26262B),
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),

                                  // Right: History Button
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      AutoRouter.of(context).push(
                                        DailyTaskHistoryScreenRoute(
                                          userId: userId,
                                          email: email,
                                          country: country,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      height: 40.w,
                                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF26262B),
                                        borderRadius: BorderRadius.circular(14.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.history_rounded,
                                            color: Colors.white,
                                            size: 16.sp,
                                          ),
                                          SizedBox(width: 5.w),
                                          Text(
                                            'History',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Top Hot Offers Featured Hero Card (Matching Home Screen Rectangle 13 style)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: _buildHomeStyleHeroCard(context, asyncOffers.value),
                            ),
                            SizedBox(height: 14.h),

                            // Category Filter Chips
                            if (categoriesState.value.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(bottom: 14.h),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: [
                                      _HomeStyleFilterChip(
                                        label: 'All Tasks',
                                        isSelected: selectedFilter.value == null ||
                                            selectedFilter.value == '__all__',
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          selectedFilter.value = null;
                                        },
                                      ),
                                      for (final category in categoriesState.value) ...[
                                        SizedBox(width: 8.w),
                                        _HomeStyleFilterChip(
                                          label: category,
                                          isSelected: selectedFilter.value == category,
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            selectedFilter.value = category;
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                            // Section Heading with Home Screen Vertical Bar
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 4.w,
                                        height: 18.h,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF26262B),
                                          borderRadius: BorderRadius.circular(2.r),
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        'All Tasks',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF1E1B4B),
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (asyncOffers.value != null)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.5.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10.r),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '${asyncOffers.value!.length} Offers',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF475569),
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12.h),

                            // Task Cards Section
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: () {
                                final asyncOffers = ref.watch(provider);
                                if (asyncOffers.value != null) {
                                  return _buildTaskListSection(
                                    context,
                                    asyncOffers.value!,
                                    selectedFilter.value,
                                    loadingId,
                                  );
                                }
                                return asyncOffers.when(
                                  data: (offers) => _buildTaskListSection(
                                    context,
                                    offers,
                                    selectedFilter.value,
                                    loadingId,
                                  ),
                                  error: (_, __) => SizedBox(
                                    height: 300.h,
                                    child: const NoDailyTask(),
                                  ),
                                  loading: () => const _DailyTaskListShimmer(),
                                );
                              }(),
                            ),

                            SizedBox(
                              height: MediaQuery.of(context).padding.bottom + 30.h,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeStyleHeroCard(BuildContext context, List<DailyTaskModel>? offers) {
    final totalCoins = (offers != null && offers.isNotEmpty)
        ? offers.fold<int>(0, (sum, o) => sum + o.coins)
        : 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 14.w, 14.h),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/Icons1/Rectangle 13.png'),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26262E),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: const Color(0xFF383842),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: const Color(0xFFF97316),
                        size: 12.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Featured Tasks',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),

                // Headline
                Text(
                  'Daily Refresh Offers',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 3.h),

                // Subtitle
                Text(
                  'Complete tasks and build your rewards',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9E9EA7),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 8.h),

                // Get Coins Upto Row
                Row(
                  children: [
                    Text(
                      'Get Coins Upto',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    _HeroCoinBadge(coins: totalCoins > 0 ? totalCoins : 500),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),

          // 3D Graphic (super_offer_3d or Frame 3)
          Image.asset(
            'assets/Icons1/super_offer_3d.png',
            width: 76.w,
            height: 76.w,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/Icons1/Frame 3 (1).png',
              width: 70.w,
              height: 70.w,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskListSection(
    BuildContext context,
    List<DailyTaskModel> offers,
    String? selectedFilter,
    ValueNotifier<String?> loadingId,
  ) {
    if (offers.isEmpty) {
      return SizedBox(
        height: 300.h,
        child: const NoDailyTask(),
      );
    }

    // Filter by Category
    final categoryFiltered = (selectedFilter == null || selectedFilter == '__all__'
        ? offers
        : offers.where((o) => o.offerCategory == selectedFilter).toList())
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (categoryFiltered.isEmpty) {
      return SizedBox(
        height: 250.h,
        child: Center(
          child: Text(
            'No tasks found for this category',
            style: GoogleFonts.poppins(
              color: const Color(0xFF64748B),
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: categoryFiltered.length,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = categoryFiltered[index];
        final heroTag = 'task_card_list_${item.offerId}_$index';
        return _HomeStyleDailyTaskCard(
          item: item,
          heroTag: heroTag,
          isLoading: loadingId.value == item.offerId,
          onTap: () {
            _navigateToTaskDetails(
              context,
              item,
              heroTag: heroTag,
            );
          },
        );
      },
    );
  }

  void _navigateToTaskDetails(
    BuildContext context,
    DailyTaskModel item, {
    String? heroTag,
  }) {
    AutoRouter.of(context).push(
      DailyTaskDetailsScreenRoute(
        item: item,
        cardColor: item.color,
        userId: userId,
        email: email,
        country: country,
        heroTag: heroTag,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HERO COIN BADGE (Exact Home Screen Style)
// ---------------------------------------------------------------------------
class _HeroCoinBadge extends StatelessWidget {
  const _HeroCoinBadge({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: const Color(0xFF26262E),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: const Color(0xFF383842),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 11.w,
            height: 11.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFE5E7EB), Color(0xFF9CA3AF)],
              ),
            ),
            padding: EdgeInsets.all(1.w),
            child: Image.asset(
              'assets/icons/coin.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.monetization_on,
                color: Color(0xFFFBBF24),
                size: 9,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            coins.formatCoins(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HOME STYLE CATEGORY FILTER CHIP
// ---------------------------------------------------------------------------
class _HomeStyleFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _HomeStyleFilterChip({
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
          color: isSelected ? const Color(0xFF26262B) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected ? const Color(0xFF26262B) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : const Color(0xFF26262B),
            fontSize: 12.5.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HOME STYLE DAILY TASK CARD WIDGET
// ---------------------------------------------------------------------------
class _HomeStyleDailyTaskCard extends StatefulWidget {
  final DailyTaskModel item;
  final String heroTag;
  final bool isLoading;
  final VoidCallback onTap;

  const _HomeStyleDailyTaskCard({
    required this.item,
    required this.heroTag,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_HomeStyleDailyTaskCard> createState() => _HomeStyleDailyTaskCardState();
}

class _HomeStyleDailyTaskCardState extends State<_HomeStyleDailyTaskCard> {
  bool _isPressed = false;

  Widget _buildCategoryTag(String category, bool dailyReset) {
    final cleanCat = category.toLowerCase().trim();
    String tagText = 'Popular';
    Color bgColor = const Color(0xFFFFF7ED);
    Color borderColor = const Color(0xFFFED7AA);
    Color textColor = const Color(0xFFEA580C);

    if (dailyReset) {
      tagText = 'Daily Refresh';
      bgColor = const Color(0xFFF1F5F9);
      borderColor = const Color(0xFFCBD5E1);
      textColor = const Color(0xFF334155);
    } else if (cleanCat.contains('game') || cleanCat.contains('ludo') || cleanCat.contains('play')) {
      tagText = 'Games';
      bgColor = const Color(0xFFFEF9C3);
      borderColor = const Color(0xFFFDE047);
      textColor = const Color(0xFFB45309);
    } else if (cleanCat.contains('finance') || cleanCat.contains('bank') || cleanCat.contains('upi') || cleanCat.contains('pay')) {
      tagText = 'Finance';
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFFBFDBFE);
      textColor = const Color(0xFF2563EB);
    } else if (cleanCat.contains('shop') || cleanCat.contains('store')) {
      tagText = 'Shopping';
      bgColor = const Color(0xFFFDF2F8);
      borderColor = const Color(0xFFFBCFE8);
      textColor = const Color(0xFFDB2777);
    } else if (category.isNotEmpty) {
      tagText = category.trim();
      bgColor = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFE2E8F0);
      textColor = const Color(0xFF475569);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        tagText,
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final totalEventCoins = (item.hasEvents && item.events.isNotEmpty)
        ? item.events.fold<int>(0, (sum, e) => sum + e.coins)
        : 0;
    final displayCoins = totalEventCoins > 0 ? totalEventCoins : item.coins;
    final subtitle = item.cleanSubtitle;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (!widget.isLoading) {
          HapticFeedback.lightImpact();
          widget.onTap();
        }
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: const Color(0xFFF1F5F9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. App Thumbnail Box
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13.r),
                  child: InternetImage(
                    url: item.imagePath.isNotEmpty
                        ? item.imagePath
                        : item.bannerPath,
                    width: 52.w,
                    height: 52.w,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // 2. Middle Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.offerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 3.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.rating.trim().isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: const Color(0xFFEAB308),
                                size: 12.sp,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                item.rating.trim(),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF475569),
                                  fontSize: 9.5.sp,
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
                                color: const Color(0xFF26262B),
                                size: 12.sp,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                item.downloads.trim(),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF475569),
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        _buildCategoryTag(item.offerCategory, item.dailyReset),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),

              // 3. Right: Coin Badge + Silver Action Button
              widget.isLoading
                  ? SizedBox(
                      width: 36.w,
                      height: 36.w,
                      child: const Center(
                        child: GlowLightingSpinner(size: 16),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Home Screen Metallic Coin Badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF26262E),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: const Color(0xFF383842),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/icons/coin.png',
                                width: 14.sp,
                                height: 14.sp,
                                fit: BoxFit.contain,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                displayCoins.formatCoins(),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: 8.w),

                        // Silver Metallic Circular Arrow Button
                        Container(
                          width: 28.w,
                          height: 28.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white,
                                Color(0xFFE5E7EB),
                                Color(0xFFB0B5C2),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: const Color(0xFF16161A),
                            size: 13.5.sp,
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
// SHIMMER SKELETON
// ---------------------------------------------------------------------------
class _DailyTaskListShimmer extends StatelessWidget {
  const _DailyTaskListShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        return ShimmerTag(
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            height: 78.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: const Color(0xFFF1F5F9),
                width: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }
}

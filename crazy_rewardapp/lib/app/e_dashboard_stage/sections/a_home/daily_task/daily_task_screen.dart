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
            // 1. Solid Clean White Background (Matching Home, Redeem & Offerwall Screen)
            Positioned.fill(
              child: Container(
                color: Colors.white,
              ),
            ),

            // 2. Main Scrollable Feed
            Positioned.fill(
              child: RefreshIndicator(
                color: const Color(0xFFAB31DE),
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
                        child: Container(
                          color: Colors.transparent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Executive Top Header Bar
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
                                    // Left: Executive Back Arrow + Title
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

                                        // Main Title: "Daily Task"
                                        Text(
                                          'Daily Task',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF1E1B4B),
                                            fontSize: 18.5.sp,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Right: Executive Task History Icon Button
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
                                        width: 40.w,
                                        height: 40.w,
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
                                        child: Center(
                                          child: Icon(
                                            Icons.history_rounded,
                                            color: const Color(0xFFAB31DE),
                                            size: 20.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Executive Category Filter Chips Row (All, Popular, Sports, Education, etc.)
                              if (categoriesState.value.isNotEmpty)
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
                                          isSelected: selectedFilter.value == null ||
                                              selectedFilter.value == '__all__',
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            selectedFilter.value = null;
                                          },
                                        ),
                                        for (final category in categoriesState.value) ...[
                                          SizedBox(width: 8.w),
                                          _FilterChip(
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
            style: GoogleFonts.outfit(
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
        return _DailyTaskCardWidget(
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
// EXECUTIVE CATEGORY FILTER CHIP
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
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isSelected ? null : const Color(0xFFFAF5FF),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFE39FFF).withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : const Color(0xFF1E1B4B),
            fontSize: 12.5.sp,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EXECUTIVE WHITE DAILY TASK CARD (Exact 1-to-1 Screenshot Mockup Layout)
// ---------------------------------------------------------------------------
class _DailyTaskCardWidget extends StatefulWidget {
  final DailyTaskModel item;
  final String heroTag;
  final bool isLoading;
  final VoidCallback onTap;

  const _DailyTaskCardWidget({
    required this.item,
    required this.heroTag,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_DailyTaskCardWidget> createState() => _DailyTaskCardWidgetState();
}

class _DailyTaskCardWidgetState extends State<_DailyTaskCardWidget> {
  bool _isPressed = false;

  Widget _buildCategoryTag(String category, bool dailyReset) {
    final cleanCat = category.toLowerCase().trim();
    String tagText = 'Most Popular';
    Color bgColor = const Color(0xFFFFF7ED);
    Color borderColor = const Color(0xFFFED7AA);
    Color textColor = const Color(0xFFEA580C);

    if (dailyReset) {
      tagText = 'Daily Refresh';
      bgColor = const Color(0xFFFAF5FF);
      borderColor = const Color(0xFFE39FFF).withValues(alpha: 0.6);
      textColor = const Color(0xFFAB31DE);
    } else if (cleanCat.contains('game') || cleanCat.contains('ludo') || cleanCat.contains('play')) {
      tagText = 'Games';
      bgColor = const Color(0xFFFEF9C3);
      borderColor = const Color(0xFFFDE047);
      textColor = const Color(0xFFCA8A04);
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
      bgColor = const Color(0xFFFAF5FF);
      borderColor = const Color(0xFFE39FFF).withValues(alpha: 0.5);
      textColor = const Color(0xFFAB31DE);
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
        style: GoogleFonts.outfit(
          color: textColor,
          fontSize: 9.5.sp,
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
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: const Color(0xFFF1F5F9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFAB31DE).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. App / Game Logo Box
              Container(
                width: 54.w,
                height: 54.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFFF3E8FF),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: InternetImage(
                    url: item.imagePath.isNotEmpty
                        ? item.imagePath
                        : item.bannerPath,
                    width: 54.w,
                    height: 54.w,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // 2. Middle Column: Title, Subtitle & Tag Pill
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
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 4.h),
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
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF475569),
                                  fontSize: 10.sp,
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
                                size: 12.sp,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                item.downloads.trim(),
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF475569),
                                  fontSize: 10.sp,
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

              // 3. Right Area: Soft Lavender Coin Badge + Small Arrow Button
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
                        // Soft Lavender Coin Pill Badge (Matching Screenshot)
                        Container(
                          height: 30.h,
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(15.r),
                            border: Border.all(
                              color: const Color(0xFFF3E8FF),
                              width: 1,
                            ),
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
                              SizedBox(width: 5.w),
                              Text(
                                displayCoins.formatCoins(),
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFAB31DE),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: 8.w),

                        // Light Purple Circle Arrow Button (Matching Screenshot)
                        Container(
                          width: 26.w,
                          height: 26.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFAF5FF),
                            border: Border.all(
                              color: const Color(0xFFF3E8FF),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: const Color(0xFFAB31DE),
                            size: 13.sp,
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
// SHIMMER SKELETON FOR DAILY TASK LIST
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
            height: 76.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
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

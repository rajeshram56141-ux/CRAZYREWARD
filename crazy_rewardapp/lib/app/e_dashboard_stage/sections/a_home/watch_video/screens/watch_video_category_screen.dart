import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../widgets/screens/loading_screen.dart';
import '../../daily_task/daily_task_model.dart';
import '../provider/watch_video_provider.dart';
import '../widgets/no_daily_task.dart';
import '../widgets/watch_video_full_video_widget.dart';

@RoutePage()
class WatchVideoCategoryScreen extends ConsumerWidget {
  const WatchVideoCategoryScreen({
    super.key,
    required this.categoryTitle,
    required this.items,
    required this.email,
    required this.userId,
    required this.countryCode,
  });

  final String categoryTitle;
  final List<DailyTaskModel> items;
  final String userId;
  final String email;
  final String countryCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Bar
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
                    child: Row(
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
                          categoryTitle,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 18.5.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content List
                  Expanded(
                    child: ref
                        .watch(
                          watchVideoProvider((
                            countryCode: countryCode,
                            email: email,
                            userId: userId,
                          )),
                        )
                        .when(
                          data: (offers) {
                            final liveCategoryOffers = offers
                                .where((offer) =>
                                    offer.offerCategory.trim().toLowerCase() ==
                                    categoryTitle.trim().toLowerCase())
                                .toList();

                            if (liveCategoryOffers.isEmpty) {
                              return const NoDailyTask(isVideo: true);
                            }

                            return RefreshIndicator(
                              color: const Color(0xFFAB31DE),
                              backgroundColor: Colors.white,
                              onRefresh: () async {
                                final p = watchVideoProvider((
                                  countryCode: countryCode,
                                  email: email,
                                  userId: userId,
                                ));
                                ref.invalidate(p);
                                await ref.read(p.future).catchError((_) => <DailyTaskModel>[]);
                              },
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
                                itemCount: liveCategoryOffers.length,
                                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                                itemBuilder: (context, index) => WatchVideoFullVideoWidget(
                                  item: liveCategoryOffers[index],
                                  email: email,
                                  userId: userId,
                                  countryCode: countryCode,
                                  ref: ref,
                                  isVerticalList: true,
                                  enableHero: true,
                                ),
                              ),
                            );
                          },
                          error: (_, __) => const NoDailyTask(isVideo: true),
                          loading: () => LoadingInfoWidget(),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

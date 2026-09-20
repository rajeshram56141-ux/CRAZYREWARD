import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../../widgets/common/internet_image.dart';
import '../../daily_task/daily_task_model.dart';
import '../provider/watch_video_provider.dart';

class WatchVideoFullVideoWidget extends StatefulWidget {
  const WatchVideoFullVideoWidget({
    super.key,
    required this.item,
    required this.email,
    required this.userId,
    required this.countryCode,
    required this.ref,
    this.isGrid = false,
    this.isVerticalList = false,
    this.enableHero = true,
  });

  final DailyTaskModel item;
  final bool isGrid;
  final bool isVerticalList;
  final String userId;
  final String email;
  final String countryCode;
  final WidgetRef ref;
  final bool enableHero;

  @override
  State<WatchVideoFullVideoWidget> createState() => _WatchVideoFullVideoWidgetState();
}

class _WatchVideoFullVideoWidgetState extends State<WatchVideoFullVideoWidget> {
  bool _isPressed = false;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '30 Sec';
    if (seconds < 60) return '$seconds Sec';
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    if (rem == 0) return '$minutes Min';
    return '$minutes m $rem s';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        HapticFeedback.lightImpact();
        final currentHeroTag = 'video_banner_${item.offerId}_${widget.isVerticalList ? "list" : (widget.isGrid ? "grid" : "reel")}';
        await AutoRouter.of(context).push(
          WatchVideoDetailsScreenRoute(
            item: item,
            email: widget.email,
            userId: widget.userId,
            countryCode: widget.countryCode,
            ref: widget.ref,
            heroTag: currentHeroTag,
          ),
        );

        // Always invalidate provider so the list refreshes with new data & status
        widget.ref.invalidate(
          watchVideoProvider((
            countryCode: widget.countryCode,
            email: widget.email,
            userId: widget.userId,
          )),
        );
      },
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
                color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(10.w, 10.h, 12.w, 10.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Left Rounded Video Thumbnail Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: SizedBox(
                  width: 116.w,
                  height: 78.h,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.enableHero
                          ? Hero(
                              tag: 'video_banner_${item.offerId}_${widget.isVerticalList ? "list" : (widget.isGrid ? "grid" : "reel")}',
                              child: InternetImage(
                                url: item.bannerPath,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          : InternetImage(
                              url: item.bannerPath,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),

                      // Subtle Dark Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.10),
                              Colors.black.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),

                      // Center Dark Circular Play Icon Button
                      Center(
                        child: Container(
                          width: 28.w,
                          height: 28.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.65),
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                        ),
                      ),

                      // Duration Badge (Top-Right)
                      Positioned(
                        top: 5.h,
                        right: 6.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.60),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            _formatDuration(item.trackingTime),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              // 2. Right Details Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Video Title
                    Text(
                      item.offerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),

                    SizedBox(height: 2.h),

                    // Subtitle / Description
                    Text(
                      item.subDescription.trim().isNotEmpty
                          ? item.subDescription
                          : (item.offerDescription.isNotEmpty
                              ? item.offerDescription.join(' • ')
                              : '${item.offerName} • Watch video and complete task to earn reward coins'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),

                    SizedBox(height: 8.h),

                    // Bottom Row (Coins Pill & Play Button)
                    Row(
                      children: [
                        // Coin Pill
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: const Color(0xFFBBF7D0),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/icons/coin.png',
                                width: 14.w,
                                height: 14.w,
                                fit: BoxFit.contain,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '+${item.coins}',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF15803D),
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Purple Gradient "Play" Pill Button
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFE39FFF),
                                Color(0xFFAB31DE),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.30),
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
                                size: 16.sp,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                'Watch',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
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
            ],
          ),
        ),
      ),
    );
  }
}

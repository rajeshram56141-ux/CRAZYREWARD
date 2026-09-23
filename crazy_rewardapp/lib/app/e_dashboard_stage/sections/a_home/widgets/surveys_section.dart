import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../offerwall/model/offerwall_data_model.dart';
import '../offerwall/provider/offerwall_manager.dart';
import '../offerwall/provider/offerwall_provider.dart';

class SurveysSection extends StatelessWidget {
  const SurveysSection({
    super.key,
    required this.userId,
    required this.email,
    required this.country,
  });

  final String userId;
  final String email;
  final String country;

  @override
  Widget build(BuildContext context) {
    if (SplashService.isScreenHidden('survey') && SplashService.isScreenHidden('offerwall')) {
      return const SizedBox.shrink();
    }

    final List<_SurveyItemData> surveyItems = [
      _SurveyItemData(
        title: 'CPX Research',
        logoAsset: 'assets/icons/cpxresearch-logo.png',
        surveyName: SurveyName.cpxResearch,
        bgColor: Colors.white,
      ),
      _SurveyItemData(
        title: 'TimeWall',
        logoAsset: 'assets/icons/timewall-logo.png',
        surveyName: SurveyName.timewall,
        bgColor: const Color(0xFF86EFAC),
      ),
      _SurveyItemData(
        title: 'BitLabz',
        logoAsset: 'assets/icons/bitlabs-logo.png',
        surveyName: SurveyName.bitlabs,
        bgColor: Colors.white,
      ),
      _SurveyItemData(
        title: 'Wannads',
        logoAsset: 'assets/icons/wannads-logo.png',
        surveyName: SurveyName.wannads,
        bgColor: Colors.white,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header: "Surveys"
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Container(
                width: 4.w,
                height: 18.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'Surveys',
                style: GoogleFonts.kaushanScript(
                  color: const Color(0xFF26262B),
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12.h),

        // Horizontal List of 4 Survey Badges + 5th "View More" Button
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in surveyItems) ...[
                _buildSurveyBadge(
                  context: context,
                  item: item,
                ),
                SizedBox(width: 14.w),
              ],

              // 5th Button: "View More"
              _buildViewMoreBadge(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSurveyBadge({
    required BuildContext context,
    required _SurveyItemData item,
  }) {
    return _PopScaleButton(
      onTap: () async {
        HapticFeedback.lightImpact();
        final surveyList = OfferwallManager.getOffersByCategory(category: OfferwallCategory.survey);
        OfferwallProvider? targetProvider;
        final searchKey = item.surveyName.name.toLowerCase();
        for (final offer in surveyList) {
          final offerKey = offer.name.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
          if (offerKey.contains(searchKey) ||
              searchKey.contains(offerKey) ||
              offer.name.toLowerCase().contains(item.title.toLowerCase().split(' ').first)) {
            targetProvider = offer;
            break;
          }
        }

        if (targetProvider != null && targetProvider.enabled) {
          await targetProvider.show(
            context: context,
            userId: userId,
            email: email,
          );
        } else {
          AutoRouter.of(context).push(
            OfferwallScreenRoute(
              userId: userId,
              email: email,
              title: 'Surveys',
              offerwallList: surveyList,
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.bgColor,
              border: Border.all(
                color: const Color(0xFFFFF2A8),
                width: 2.5.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: item.customWidget ??
                  Padding(
                    padding: EdgeInsets.all(7.w),
                    child: Image.asset(
                      item.logoAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.poll_rounded,
                        color: const Color(0xFF26262B),
                        size: 24.sp,
                      ),
                    ),
                  ),
            ),
          ),
          SizedBox(height: 6.h),
          SizedBox(
            width: 66.w,
            child: Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: const Color(0xFF1E1B4B),
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMoreBadge(BuildContext context) {
    return _PopScaleButton(
      onTap: () {
        HapticFeedback.lightImpact();
        final surveyList = OfferwallManager.getOffersByCategory(category: OfferwallCategory.survey);
        AutoRouter.of(context).push(
          OfferwallScreenRoute(
            userId: userId,
            email: email,
            title: 'Surveys',
            offerwallList: surveyList,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF2A8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: const Color(0xFF1E1B4B),
                size: 18.sp,
              ),
            ),
          ),
          SizedBox(height: 6.h),
          SizedBox(
            width: 66.w,
            child: Text(
              'View More',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: const Color(0xFF1E1B4B),
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurveyItemData {
  final String title;
  final String logoAsset;
  final SurveyName surveyName;
  final Color bgColor;
  final Widget? customWidget;

  const _SurveyItemData({
    required this.title,
    required this.logoAsset,
    required this.surveyName,
    required this.bgColor,
    this.customWidget,
  });
}

class _PopScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;

  const _PopScaleButton({
    required this.child,
    required this.onTap,
    this.scaleDown = 0.93,
  });

  @override
  State<_PopScaleButton> createState() => _PopScaleButtonState();
}

class _PopScaleButtonState extends State<_PopScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

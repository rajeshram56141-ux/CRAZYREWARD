import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'audio_service.dart';
import 'car_upgrade_model.dart';
import 'garage_car_model.dart';
import 'storage_service.dart';
import '../widgets/turbo_car_showcase.dart';

/// ============================================================================
/// PREMIUM PERFORMANCE TUNING & CAR UPGRADE WORKSHOP
/// ============================================================================
/// Features:
/// - 5 Upgrade Categories:
///   1. SPEED
///   2. ACCELERATION
///   3. HANDLING
///   4. BRAKING
///   5. NITRO
/// - Multi-level progression (Level 1 -> 5)
/// - Shows:
///   * Current Level & Spec (e.g. Level 2: 110)
///   * Next Level & Spec (e.g. Level 3: 120)
///   * Upgrade Cost in Coins
///   * Interactive Upgrade Button with Coin Verification
///   * Prevents upgrade if player does not have enough coins
///   * Local persistence via RunnerStorageService
/// - Live 3D Vector Car Preview
/// - Celebration spark/particle effects on successful upgrade
/// ============================================================================

class RunnerCarUpgradeDialog extends StatefulWidget {
  final GarageCarConfig car;
  final VoidCallback? onUpgraded;

  const RunnerCarUpgradeDialog({
    super.key,
    required this.car,
    this.onUpgraded,
  });

  static Future<void> show(
    BuildContext context, {
    required GarageCarConfig car,
    VoidCallback? onUpgraded,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (_) => RunnerCarUpgradeDialog(
        car: car,
        onUpgraded: onUpgraded,
      ),
    );
  }

  @override
  State<RunnerCarUpgradeDialog> createState() => _RunnerCarUpgradeDialogState();
}

class _RunnerCarUpgradeDialogState extends State<RunnerCarUpgradeDialog>
    with SingleTickerProviderStateMixin {
  late int _playerCoins;
  late final Map<UpgradeCategory, int> _categoryLevels;

  // Visual animation & feedback
  late AnimationController _sparkleController;
  UpgradeCategory? _lastUpgradedCategory;
  bool _showFeedback = false;
  String _feedbackText = "";
  bool _isFeedbackSuccess = true;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _loadLevels();
  }

  void _loadLevels() {
    _playerCoins = RunnerStorageService.getTotalCoins();
    _categoryLevels = {
      UpgradeCategory.speed: RunnerStorageService.getCategoryUpgradeLevel(widget.car.id, 'speed'),
      UpgradeCategory.acceleration: RunnerStorageService.getCategoryUpgradeLevel(widget.car.id, 'acceleration'),
      UpgradeCategory.handling: RunnerStorageService.getCategoryUpgradeLevel(widget.car.id, 'handling'),
      UpgradeCategory.braking: RunnerStorageService.getCategoryUpgradeLevel(widget.car.id, 'braking'),
      UpgradeCategory.nitro: RunnerStorageService.getCategoryUpgradeLevel(widget.car.id, 'nitro'),
    };
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  void _triggerFeedback(String message, {bool isSuccess = true}) {
    setState(() {
      _feedbackText = message;
      _isFeedbackSuccess = isSuccess;
      _showFeedback = true;
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _showFeedback = false;
        });
      }
    });
  }

  void _upgradeCategory(UpgradeCategory category) {
    final int currentLvl = _categoryLevels[category] ?? 1;
    if (currentLvl >= CarUpgradeSystem.maxLevel) {
      RunnerAudioService().playClick();
      _triggerFeedback("${category.displayName} IS ALREADY AT MAX LEVEL! ⭐", isSuccess: false);
      return;
    }

    final int cost = CarUpgradeSystem.getUpgradeCost(category, currentLvl);

    // Coin check verification
    if (_playerCoins < cost) {
      RunnerAudioService().playShieldBreak();
      HapticFeedback.lightImpact();
      final int needed = cost - _playerCoins;
      _triggerFeedback("NOT ENOUGH COINS! NEED $needed MORE 🪙", isSuccess: false);
      return;
    }

    // Deduct coins & persist locally
    final bool success = RunnerStorageService.deductCoins(cost);
    if (success) {
      final int newLevel = currentLvl + 1;
      RunnerStorageService.setCategoryUpgradeLevel(widget.car.id, category.name, newLevel);

      RunnerAudioService().playVictory();
      HapticFeedback.heavyImpact();

      setState(() {
        _lastUpgradedCategory = category;
        _loadLevels();
      });

      final tierData = CarUpgradeSystem.getTier(category, newLevel);
      _triggerFeedback(
        "${category.displayName} UPGRADED TO LVL $newLevel (${tierData.value} ${category.unit})! 🚀",
        isSuccess: true,
      );

      widget.onUpgraded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int overallRating = CarUpgradeSystem.calculateOverallRating(
      speedLvl: _categoryLevels[UpgradeCategory.speed] ?? 1,
      accelLvl: _categoryLevels[UpgradeCategory.acceleration] ?? 1,
      handlingLvl: _categoryLevels[UpgradeCategory.handling] ?? 1,
      brakingLvl: _categoryLevels[UpgradeCategory.braking] ?? 1,
      nitroLvl: _categoryLevels[UpgradeCategory.nitro] ?? 1,
    );

    final int totalPoints = _categoryLevels.values.fold(0, (sum, lvl) => sum + lvl);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: BoxConstraints(maxHeight: 760.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0F172A),
                Color(0xFF1E293B),
                Color(0xFF070B14),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(
              color: widget.car.category.color.withValues(alpha: 0.7),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.car.category.color.withValues(alpha: 0.35),
                blurRadius: 36,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.9),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Top Header Bar: Title, Power Rating, Coins & Close Button
              _buildHeader(overallRating, totalPoints),

              Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),

              // 2. Scrollable Body: Car Preview & 5 Category Cards
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  child: Column(
                    children: [
                      // Interactive Feedback Toast
                      if (_showFeedback)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: EdgeInsets.only(bottom: 10.h),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isFeedbackSuccess
                                  ? [
                                      const Color(0xFF22C55E),
                                      const Color(0xFF10B981),
                                    ]
                                  : [
                                      const Color(0xFFEF4444),
                                      const Color(0xFFDC2626),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: (_isFeedbackSuccess
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFEF4444))
                                    .withValues(alpha: 0.6),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isFeedbackSuccess
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 16.sp,
                              ),
                              SizedBox(width: 6.w),
                              Flexible(
                                child: Text(
                                  _feedbackText,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 3D Car Vector Showcase
                      TurboSupercarShowcase(
                        width: 240.w,
                        height: 120.h,
                        theme: widget.car.theme,
                        badgeText: "${widget.car.name.toUpperCase()} • RATING $overallRating",
                        showSpecs: false,
                      ),

                      SizedBox(height: 6.h),

                      // Tuning Level Summary Bar
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFF334155),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  color: widget.car.category.color,
                                  size: 14.sp,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  "TOTAL TUNING:",
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "$totalPoints / 25 PTS (STAGE ${((totalPoints - 5) ~/ 4) + 1})",
                              style: GoogleFonts.blackOpsOne(
                                color: const Color(0xFFFFD700),
                                fontSize: 11.sp,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 12.h),

                      // 5 UPGRADE CATEGORY CARDS
                      ...UpgradeCategory.values.map((category) {
                        return _buildUpgradeCard(category);
                      }),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Close/Done Bar
              Container(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 14.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      RunnerAudioService().playClick();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF22C55E).withValues(alpha: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 20.sp),
                        SizedBox(width: 8.w),
                        Text(
                          "APPLY & RETURN TO GARAGE",
                          style: GoogleFonts.blackOpsOne(
                            fontSize: 13.sp,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int overallRating, int totalPoints) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title & Car Info
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(7.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.car.category.color == const Color(0xFFEF4444)
                          ? const [Color(0xFFFF3366), Color(0xFFFF5E3A)]
                          : [widget.car.category.color, widget.car.category.color.withValues(alpha: 0.6)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.car.category.color.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.build_circle_rounded,
                    color: Colors.white,
                    size: 18.sp,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "PERFORMANCE TUNING",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.blackOpsOne(
                          color: Colors.white,
                          fontSize: 15.sp,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        "${widget.car.name.toUpperCase()} • RATING $overallRating/100",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),

          // Total Coins Pill
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF451A03), Color(0xFF1E293B)],
              ),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  color: const Color(0xFFFFD700),
                  size: 15.sp,
                ),
                SizedBox(width: 5.w),
                Text(
                  "$_playerCoins",
                  style: GoogleFonts.blackOpsOne(
                    color: const Color(0xFFFFD700),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),

          // Close Button
          GestureDetector(
            onTap: () {
              RunnerAudioService().playClick();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: const Color(0xFF334155).withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 18.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard(UpgradeCategory category) {
    final int currentLevel = _categoryLevels[category] ?? 1;
    final bool isMax = currentLevel >= CarUpgradeSystem.maxLevel;
    final currentTier = CarUpgradeSystem.getTier(category, currentLevel);
    final nextTier = CarUpgradeSystem.getNextTier(category, currentLevel);
    final int cost = CarUpgradeSystem.getUpgradeCost(category, currentLevel);
    final bool canAfford = _playerCoins >= cost;
    final bool wasJustUpgraded = _lastUpgradedCategory == category;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: wasJustUpgraded
              ? category.primaryColor
              : const Color(0xFF334155),
          width: wasJustUpgraded ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (wasJustUpgraded)
            BoxShadow(
              color: category.primaryColor.withValues(alpha: 0.4),
              blurRadius: 14,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Category Icon, Name, Subtitle & Level Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: category.gradientColors),
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(
                          color: category.primaryColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      category.icon,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.displayName,
                        style: GoogleFonts.blackOpsOne(
                          color: Colors.white,
                          fontSize: 13.sp,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        currentTier.label,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 8.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Level Pill Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: isMax
                      ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                      : category.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: isMax
                        ? const Color(0xFFFFD700)
                        : category.primaryColor,
                    width: 1,
                  ),
                ),
                child: Text(
                  isMax ? "MAX LEVEL 5" : "LEVEL $currentLevel / 5",
                  style: GoogleFonts.blackOpsOne(
                    color: isMax ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: 9.sp,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          // Row 2: Current Level vs Next Level Specs Comparison
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Current Spec
                Row(
                  children: [
                    Text(
                      "CURRENT: ",
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      "${currentTier.value} ${category.unit}",
                      style: GoogleFonts.blackOpsOne(
                        color: Colors.white,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),

                // Arrow indicator
                if (!isMax && nextTier != null) ...[
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: const Color(0xFF22C55E),
                    size: 14.sp,
                  ),

                  // Next Spec + Difference
                  Row(
                    children: [
                      Text(
                        "NEXT: ",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "${nextTier.value} ${category.unit}",
                        style: GoogleFonts.blackOpsOne(
                          color: const Color(0xFF4ADE80),
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          "+${nextTier.value - currentTier.value}",
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF4ADE80),
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    "MAX PERFORMANCE REACHED ⭐",
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFFFD700),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 8.h),

          // Row 3: 5 Segmented Neon Progress Bars
          Row(
            children: List.generate(CarUpgradeSystem.maxLevel, (index) {
              final int stepLvl = index + 1;
              final bool isFilled = stepLvl <= currentLevel;
              final bool isNext = stepLvl == currentLevel + 1;

              return Expanded(
                child: Container(
                  height: 7.h,
                  margin: EdgeInsets.only(right: index < 4 ? 5.w : 0),
                  decoration: BoxDecoration(
                    color: isFilled
                        ? category.primaryColor
                        : isNext
                            ? category.primaryColor.withValues(alpha: 0.25)
                            : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(4.r),
                    border: isNext
                        ? Border.all(
                            color: category.primaryColor.withValues(alpha: 0.6),
                            width: 1,
                          )
                        : null,
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: category.primaryColor.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),

          SizedBox(height: 10.h),

          // Row 4: Action / Upgrade Button
          SizedBox(
            width: double.infinity,
            height: 42.h,
            child: isMax
                ? Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B2F08), Color(0xFF1E293B)],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          color: const Color(0xFFFFD700),
                          size: 18.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          "MAXED OUT",
                          style: GoogleFonts.blackOpsOne(
                            color: const Color(0xFFFFD700),
                            fontSize: 12.sp,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => _upgradeCategory(category),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford
                          ? category.primaryColor
                          : const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(
                          color: canAfford
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      elevation: canAfford ? 6 : 0,
                      shadowColor: canAfford
                          ? category.primaryColor.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              canAfford ? Icons.upgrade_rounded : Icons.lock_outline_rounded,
                              size: 18.sp,
                              color: canAfford ? Colors.white : const Color(0xFF94A3B8),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              canAfford ? "UPGRADE TO LVL ${currentLevel + 1}" : "NEED COINS",
                              style: GoogleFonts.blackOpsOne(
                                fontSize: 11.sp,
                                letterSpacing: 0.8,
                                color: canAfford ? Colors.white : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),

                        // Upgrade Cost Badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(
                              color: canAfford
                                  ? const Color(0xFFFFD700)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.6),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.monetization_on_rounded,
                                color: canAfford
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFFEF4444),
                                size: 13.sp,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                "$cost",
                                style: GoogleFonts.blackOpsOne(
                                  color: canAfford
                                      ? const Color(0xFFFFD700)
                                      : const Color(0xFFFCA5A5),
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

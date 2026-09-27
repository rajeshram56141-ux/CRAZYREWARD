import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'audio_service.dart';
import 'car_upgrade_dialog.dart';
import 'car_upgrade_model.dart';
import 'garage_car_model.dart';
import 'player_car.dart';
import 'storage_service.dart';
import '../widgets/turbo_car_showcase.dart';

/// ============================================================================
/// PREMIUM SUPERCAR GARAGE & FLEET CUSTOMIZATION SCREEN
/// ============================================================================
/// Features:
/// - 3D Showcase with Live Vector In-Game Car Rendering & Ground Pedestal
/// - Direct Left/Right Arrow Car Navigation & Horizontal Fleet Selector Strip
/// - Telemetry Performance Stats (Speed, Acceleration, Handling, Nitro, Braking)
/// - Integrated Tuning Rating (1-100 Rating) & Perk Badges
/// - Instant Unlock & Equip System with Coin Verification
/// - Direct Gateway to Full 5-Category Tuning Workshop
/// ============================================================================

class RunnerGarageDialog extends StatefulWidget {
  const RunnerGarageDialog({
    super.key,
    required this.onCarEquipped,
  });

  final void Function(PlayerCarTheme equippedTheme) onCarEquipped;

  static Future<void> show(
    BuildContext context, {
    required void Function(PlayerCarTheme equippedTheme) onCarEquipped,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => RunnerGarageDialog(onCarEquipped: onCarEquipped),
    );
  }

  @override
  State<RunnerGarageDialog> createState() => _RunnerGarageDialogState();
}

class _RunnerGarageDialogState extends State<RunnerGarageDialog>
    with SingleTickerProviderStateMixin {
  late final List<GarageCarConfig> _cars;
  late int _selectedIndex;
  late String _equippedCarId;

  int _playerCoins = 0;

  // Visual feedback toast state
  bool _showFeedback = false;
  String _feedbackMessage = "";
  bool _feedbackIsSuccess = true;

  @override
  void initState() {
    super.initState();
    _cars = GarageCarConfig.allCars;
    _refreshPlayerData();

    // Determine initial selected index from saved equipped car
    final equippedIdx = _cars.indexWhere((c) => c.id == _equippedCarId);
    _selectedIndex = equippedIdx != -1 ? equippedIdx : 0;
  }

  void _refreshPlayerData() {
    _playerCoins = RunnerStorageService.getTotalCoins();
    _equippedCarId = RunnerStorageService.getSelectedCarId();

    // Ensure default starter car is unlocked
    for (final car in _cars) {
      if (car.isDefaultUnlocked) {
        RunnerStorageService.unlockCar(car.id);
      }
    }
  }

  bool _isUnlocked(GarageCarConfig car) {
    return RunnerStorageService.isCarUnlocked(car.id, defaultUnlocked: car.isDefaultUnlocked);
  }

  int _getUpgradeLevel(GarageCarConfig car) {
    return RunnerStorageService.getCarUpgradeLevel(car.id);
  }

  void _triggerFeedback(String message, {bool isSuccess = true}) {
    setState(() {
      _feedbackMessage = message;
      _feedbackIsSuccess = isSuccess;
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

  void _selectPreviousCar() {
    RunnerAudioService().playClick();
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = (_selectedIndex - 1 + _cars.length) % _cars.length;
    });
  }

  void _selectNextCar() {
    RunnerAudioService().playClick();
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = (_selectedIndex + 1) % _cars.length;
    });
  }

  void _equipCar(GarageCarConfig car) {
    RunnerAudioService().playClick();
    HapticFeedback.heavyImpact();
    RunnerStorageService.setSelectedCarId(car.id);
    RunnerStorageService.setSelectedCarIndex(_selectedIndex);

    setState(() {
      _equippedCarId = car.id;
    });

    widget.onCarEquipped(car.theme);
    _triggerFeedback("${car.name.toUpperCase()} EQUIPPED! 🏎️", isSuccess: true);
  }

  void _unlockCar(GarageCarConfig car) {
    final int price = car.unlockPriceCoins;

    if (_playerCoins >= price) {
      RunnerAudioService().playCoinPickup();
      HapticFeedback.heavyImpact();
      final bool success = RunnerStorageService.deductCoins(price);
      if (success) {
        RunnerStorageService.unlockCar(car.id);
        _refreshPlayerData();
        _equipCar(car);
        _triggerFeedback("UNLOCKED ${car.name.toUpperCase()}! 🎉", isSuccess: true);
      }
    } else {
      RunnerAudioService().playGameOverSound();
      HapticFeedback.lightImpact();
      final int needed = price - _playerCoins;
      _triggerFeedback("NEED $needed MORE COINS TO UNLOCK! 🪙", isSuccess: false);
    }
  }

  void _openUpgradeWorkshop(GarageCarConfig car) {
    RunnerAudioService().playClick();
    RunnerCarUpgradeDialog.show(
      context,
      car: car,
      onUpgraded: () {
        setState(() {
          _refreshPlayerData();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCar = _cars[_selectedIndex];
    final bool isUnlocked = _isUnlocked(activeCar);
    final bool isEquipped = _equippedCarId == activeCar.id;

    // 5-Category Upgrade Levels
    final int speedLvl = RunnerStorageService.getCategoryUpgradeLevel(activeCar.id, 'speed');
    final int accelLvl = RunnerStorageService.getCategoryUpgradeLevel(activeCar.id, 'acceleration');
    final int handlingLvl = RunnerStorageService.getCategoryUpgradeLevel(activeCar.id, 'handling');
    final int brakingLvl = RunnerStorageService.getCategoryUpgradeLevel(activeCar.id, 'braking');
    final int nitroLvl = RunnerStorageService.getCategoryUpgradeLevel(activeCar.id, 'nitro');

    final int totalPoints = speedLvl + accelLvl + handlingLvl + brakingLvl + nitroLvl;
    final int overallRating = CarUpgradeSystem.calculateOverallRating(
      speedLvl: speedLvl,
      accelLvl: accelLvl,
      handlingLvl: handlingLvl,
      brakingLvl: brakingLvl,
      nitroLvl: nitroLvl,
    );
    final bool isMaxUpgrade = totalPoints >= 25;

    // Effective Performance Stats
    final double effectiveSpeed = activeCar.getEffectiveSpeed(speedLvl);
    final double effectiveHandling = activeCar.getEffectiveHandling(handlingLvl);
    final double effectiveAccel = activeCar.getEffectiveAcceleration(accelLvl);
    final double effectiveBraking = activeCar.getEffectiveBraking(brakingLvl);
    final double effectiveNitro = activeCar.getEffectiveNitro(nitroLvl);

    final int upgradeLevel = (totalPoints / 5).round().clamp(1, 5);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: BoxConstraints(maxHeight: 740.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0D1322),
                Color(0xFF151E32),
                Color(0xFF090D16),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(
              color: activeCar.category.color.withValues(alpha: 0.7),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: activeCar.category.color.withValues(alpha: 0.3),
                blurRadius: 28,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.85),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // ===============================================================
              // 1. TOP HEADER: TITLE, COINS PILL & CLOSE BUTTON
              // ===============================================================
              Container(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 14.w, 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E1A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Garage Title & Neon Icon
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: BoxDecoration(
                              color: activeCar.category.color.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: activeCar.category.color,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.garage_rounded,
                              color: Colors.white,
                              size: 16.sp,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "SUPER GARAGE",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.blackOpsOne(
                                    color: Colors.white,
                                    fontSize: 15.sp,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  "FLEET & PERFORMANCE WORKSHOP",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),

                    // Right Group: Coins Pill + Close Button
                    Row(
                      children: [
                        // Racing Gold Coins Badge Pill
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF451A03), Color(0xFF1E293B)],
                            ),
                            borderRadius: BorderRadius.circular(16.r),
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

                        SizedBox(width: 8.w),

                        // Close Button (3D Circular)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155).withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ===============================================================
              // 2. MAIN SCROLLABLE CONTENT BODY
              // ===============================================================
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  child: Column(
                    children: [
                      // Floating Feedback Toast Banner
                      if (_showFeedback)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: EdgeInsets.only(bottom: 8.h),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _feedbackIsSuccess
                                  ? [
                                      const Color(0xFF15803D),
                                      const Color(0xFF22C55E),
                                    ]
                                  : [
                                      const Color(0xFF991B1B),
                                      const Color(0xFFEF4444),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: [
                              BoxShadow(
                                color: (_feedbackIsSuccess
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFEF4444))
                                    .withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Text(
                            _feedbackMessage,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                      // =======================================================
                      // 3. HERO 3D VEHICLE STAGE WITH DIRECT LEFT/RIGHT ARROWS
                      // =======================================================
                      SizedBox(
                        height: 155.h,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 3D Car Vector Showcase Stage
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: KeyedSubtree(
                                key: ValueKey("${activeCar.id}_$upgradeLevel"),
                                child: TurboSupercarShowcase(
                                  width: 250.w,
                                  height: 140.h,
                                  theme: activeCar.theme,
                                  badgeText: "${activeCar.category.displayName.toUpperCase()} • LVL $upgradeLevel",
                                  showSpecs: false,
                                ),
                              ),
                            ),

                            // Floating Left Arrow
                            Positioned(
                              left: 0,
                              child: GestureDetector(
                                onTap: _selectPreviousCar,
                                child: Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: activeCar.category.color.withValues(alpha: 0.7),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 14.sp,
                                  ),
                                ),
                              ),
                            ),

                            // Floating Right Arrow
                            Positioned(
                              right: 0,
                              child: GestureDetector(
                                onTap: _selectNextCar,
                                child: Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: activeCar.category.color.withValues(alpha: 0.7),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white,
                                    size: 14.sp,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Car Category Pill, Name & Status Badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Category Tag
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: activeCar.category.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: activeCar.category.color,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  activeCar.category.icon,
                                  color: activeCar.category.color,
                                  size: 11.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  activeCar.category.displayName.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    color: activeCar.category.color,
                                    fontSize: 8.5.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 8.w),

                          // Model Name
                          Text(
                            activeCar.name,
                            style: GoogleFonts.blackOpsOne(
                              color: Colors.white,
                              fontSize: 16.sp,
                              letterSpacing: 1.0,
                            ),
                          ),

                          SizedBox(width: 8.w),

                          // Equipped / Locked Status Pill
                          if (isEquipped)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: const Color(0xFF22C55E),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: const Color(0xFF4ADE80), size: 10.sp),
                                  SizedBox(width: 3.w),
                                  Text(
                                    "ACTIVE",
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF4ADE80),
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (!isUnlocked)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB703).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: const Color(0xFFFFB703),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_rounded,
                                      color: const Color(0xFFFFB703), size: 10.sp),
                                  SizedBox(width: 3.w),
                                  Text(
                                    "LOCKED",
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFFFB703),
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      SizedBox(height: 3.h),

                      // Tuning Level & Rating Summary Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "TUNING RATING: ",
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF94A3B8),
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              "$overallRating/100 ($totalPoints/25 PTS)",
                              style: GoogleFonts.blackOpsOne(
                                color: const Color(0xFFFFD700),
                                fontSize: 9.sp,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8.h),

                      // =======================================================
                      // 4. HORIZONTAL CAR FLEET SELECTOR STRIP
                      // =======================================================
                      SizedBox(
                        height: 68.h,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _cars.length,
                          separatorBuilder: (_, __) => SizedBox(width: 8.w),
                          itemBuilder: (context, index) {
                            final car = _cars[index];
                            final bool isSelected = _selectedIndex == index;
                            final bool unlocked = _isUnlocked(car);
                            final bool equipped = _equippedCarId == car.id;
                            final int lvl = _getUpgradeLevel(car);

                            return GestureDetector(
                              onTap: () {
                                RunnerAudioService().playClick();
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedIndex = index;
                                });
                              },
                              child: Container(
                                width: 104.w,
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 5.h),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isSelected
                                        ? [
                                            car.category.color.withValues(alpha: 0.35),
                                            const Color(0xFF1E293B),
                                          ]
                                        : [
                                            const Color(0xFF1E293B).withValues(alpha: 0.8),
                                            const Color(0xFF0F172A).withValues(alpha: 0.8),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: isSelected
                                        ? car.category.color
                                        : const Color(0xFF334155),
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: car.category.color.withValues(alpha: 0.4),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Category Header
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                                          decoration: BoxDecoration(
                                            color: car.category.color.withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(4.r),
                                          ),
                                          child: Text(
                                            car.category.displayName.toUpperCase(),
                                            style: GoogleFonts.outfit(
                                              color: car.category.color,
                                              fontSize: 6.5.sp,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        if (!unlocked)
                                          Icon(
                                            Icons.lock_rounded,
                                            color: const Color(0xFFFFB703),
                                            size: 10.sp,
                                          )
                                        else if (equipped)
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: const Color(0xFF22C55E),
                                            size: 10.sp,
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 2.h),

                                    // Car Name
                                    Text(
                                      car.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                        fontSize: 9.5.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),

                                    // Status Badge / Level
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                                      decoration: BoxDecoration(
                                        color: equipped
                                            ? const Color(0xFF22C55E).withValues(alpha: 0.25)
                                            : !unlocked
                                                ? const Color(0xFFFFB703).withValues(alpha: 0.2)
                                                : Colors.black38,
                                        borderRadius: BorderRadius.circular(5.r),
                                      ),
                                      child: Text(
                                        equipped
                                            ? "ACTIVE"
                                            : !unlocked
                                                ? "${car.unlockPriceCoins} 🪙"
                                                : "LVL $lvl/5",
                                        style: GoogleFonts.outfit(
                                          color: equipped
                                              ? const Color(0xFF4ADE80)
                                              : !unlocked
                                                  ? const Color(0xFFFFB703)
                                                  : const Color(0xFF94A3B8),
                                          fontSize: 7.5.sp,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      SizedBox(height: 10.h),

                      // =======================================================
                      // 5. PROGRESSIVE 5-CATEGORY PERFORMANCE STATS GRID
                      // =======================================================
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: const Color(0xFF334155),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Row 1: Speed & Acceleration
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactStatGauge(
                                    label: "TOP SPEED",
                                    level: speedLvl,
                                    valueDisplay: "${CarUpgradeSystem.getTier(UpgradeCategory.speed, speedLvl).value} KM/H",
                                    percentage: effectiveSpeed,
                                    color: const Color(0xFFFF3366),
                                    icon: Icons.speed_rounded,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: _buildCompactStatGauge(
                                    label: "ACCEL",
                                    level: accelLvl,
                                    valueDisplay: "${CarUpgradeSystem.getTier(UpgradeCategory.acceleration, accelLvl).value} PTS",
                                    percentage: effectiveAccel,
                                    color: const Color(0xFF00F2FE),
                                    icon: Icons.flash_on_rounded,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),

                            // Row 2: Handling & Nitro Power
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactStatGauge(
                                    label: "HANDLING",
                                    level: handlingLvl,
                                    valueDisplay: "${CarUpgradeSystem.getTier(UpgradeCategory.handling, handlingLvl).value} PTS",
                                    percentage: effectiveHandling,
                                    color: const Color(0xFF22C55E),
                                    icon: Icons.tune_rounded,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: _buildCompactStatGauge(
                                    label: "NITRO",
                                    level: nitroLvl,
                                    valueDisplay: "+${CarUpgradeSystem.getTier(UpgradeCategory.nitro, nitroLvl).value}%",
                                    percentage: effectiveNitro,
                                    color: const Color(0xFFA855F7),
                                    icon: Icons.local_fire_department_rounded,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),

                            // Row 3: Braking
                            _buildCompactStatGauge(
                              label: "BRAKING STABILITY",
                              level: brakingLvl,
                              valueDisplay: "${CarUpgradeSystem.getTier(UpgradeCategory.braking, brakingLvl).value} PTS",
                              percentage: effectiveBraking,
                              color: const Color(0xFFF59E0B),
                              icon: Icons.pan_tool_alt_rounded,
                            ),
                          ],
                        ),
                      ),

                      // Special Perk Banner
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: activeCar.category.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: activeCar.category.color.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: activeCar.category.color,
                              size: 13.sp,
                            ),
                            SizedBox(width: 5.w),
                            Flexible(
                              child: Text(
                                "PERK: ${activeCar.specialPerk.toUpperCase()}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===============================================================
              // 6. BOTTOM DUAL ACTION BAR: EQUIP/UNLOCK & TUNING WORKSHOP
              // ===============================================================
              Container(
                padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E1A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(26.r)),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // BUTTON 1: EQUIP / SELECT / UNLOCK
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 46.h,
                        child: isUnlocked
                            ? ElevatedButton(
                                onPressed: isEquipped ? null : () => _equipCar(activeCar),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isEquipped
                                      ? const Color(0xFF334155)
                                      : const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(23.r),
                                    side: BorderSide(
                                      color: isEquipped
                                          ? Colors.transparent
                                          : Colors.white.withValues(alpha: 0.4),
                                      width: 1.2,
                                    ),
                                  ),
                                  elevation: isEquipped ? 0 : 6,
                                  shadowColor: const Color(0xFF22C55E).withValues(alpha: 0.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isEquipped
                                          ? Icons.check_circle_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 18.sp,
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      isEquipped ? "EQUIPPED" : "EQUIP CAR",
                                      style: GoogleFonts.blackOpsOne(
                                        fontSize: 13.sp,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ElevatedButton(
                                onPressed: () => _unlockCar(activeCar),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(23.r),
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      width: 1.2,
                                    ),
                                  ),
                                  elevation: 6,
                                  shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_open_rounded, size: 16.sp),
                                    SizedBox(width: 5.w),
                                    Flexible(
                                      child: Text(
                                        "UNLOCK (${activeCar.unlockPriceCoins} 🪙)",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.blackOpsOne(
                                          fontSize: 11.5.sp,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),

                    SizedBox(width: 8.w),

                    // BUTTON 2: TUNING & UPGRADE WORKSHOP
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 46.h,
                        child: ElevatedButton(
                          onPressed: !isUnlocked ? null : () => _openUpgradeWorkshop(activeCar),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMaxUpgrade
                                ? const Color(0xFF334155)
                                : const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23.r),
                              side: BorderSide(
                                color: isUnlocked
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            elevation: isUnlocked ? 6 : 0,
                            shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isMaxUpgrade
                                    ? Icons.stars_rounded
                                    : Icons.build_circle_rounded,
                                size: 18.sp,
                              ),
                              SizedBox(width: 5.w),
                              Flexible(
                                child: Text(
                                  isMaxUpgrade
                                      ? "MAX TUNED"
                                      : "TUNING 🚀",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.blackOpsOne(
                                    fontSize: 12.sp,
                                    letterSpacing: 0.6,
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatGauge({
    required String label,
    required String valueDisplay,
    required double percentage,
    required Color color,
    required IconData icon,
    int? level,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 11.sp),
                SizedBox(width: 4.w),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                if (level != null) ...[
                  SizedBox(width: 4.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                    child: Text(
                      "L$level",
                      style: GoogleFonts.outfit(
                        color: color,
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              valueDisplay,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 8.5.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        SizedBox(height: 3.h),
        Stack(
          children: [
            // Background track
            Container(
              height: 5.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(2.5.r),
              ),
            ),
            // Filled dynamic progress
            LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: 5.h,
                  width: constraints.maxWidth * percentage.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.7),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2.5.r),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

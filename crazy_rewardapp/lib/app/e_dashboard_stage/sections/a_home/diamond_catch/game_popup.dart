import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/ad_manager.dart';
import '../../../../../services/cloud_functions.dart';
import '../../../../../services/launch_url.dart';
import '../../../../../widgets/common/custom_toast.dart';
import '../../../provider/dashboard_provider.dart';
import 'diamond_catch_model.dart';
import 'diamond_catch_provider.dart';
import '../../../../b_splash_stage/splash_service.dart';

enum _PopupState {
  winResult,
  finishToUnlock,
  taskFailed,
  taskSuccess,
}

class GameResultPopup extends ConsumerStatefulWidget {
  const GameResultPopup({
    super.key,
    required this.isWin,
    required this.score,
    required this.stars,
    required this.onRestart,
    required this.onHome,
    required this.gameGems,
    required this.installGems,
    required this.dailyGems,
    required this.dailyGemsForInstall,
    this.isInstallTask = false,
    this.onResume,
  });

  final bool isWin;
  final int score;
  final int stars;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final VoidCallback? onResume;
  final int gameGems;
  final int installGems;
  final int dailyGems;
  final int dailyGemsForInstall;
  final bool isInstallTask;

  @override
  ConsumerState<GameResultPopup> createState() => _GameResultPopupState();
}

class _GameResultPopupState extends ConsumerState<GameResultPopup>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _starController;
  late Animation<double> _star1Anim;
  late Animation<double> _star2Anim;
  late Animation<double> _star3Anim;

  _PopupState _popupState = _PopupState.winResult;
  bool _isClaimed = false;
  bool _isAdLoading = false;
  DateTime? _installClickTime;
  int? _initialAvailableStorage;

  static const MethodChannel _appManagerChannel =
      MethodChannel('com.crazyreward.games/app_manager');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdManager().preloadRewarded();
    AdManager().preloadInterstitial();

    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _star1Anim = CurvedAnimation(
      parent: _starController,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    _star2Anim = CurvedAnimation(
      parent: _starController,
      curve: const Interval(0.25, 0.75, curve: Curves.elasticOut),
    );
    _star3Anim = CurvedAnimation(
      parent: _starController,
      curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
    );

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _starController.forward();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _starController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && _installClickTime != null) {
      _installClickTime = null;
      if (!mounted) return;
      setState(() => _isAdLoading = true);

      bool isSuccess = false;
      try {
        final currentStorage =
            await _appManagerChannel.invokeMethod<int>('getAvailableStorage') ?? 0;
        if (_initialAvailableStorage != null &&
            _initialAvailableStorage! > 0 &&
            currentStorage > 0) {
          final diffBytes = _initialAvailableStorage! - currentStorage;
          final diffMB = diffBytes / (1024.0 * 1024.0);
          final double requiredMB =
              (SplashService.superOfferConfig['installTaskMb'] as num?)?.toDouble() ?? 15.0;
          isSuccess = diffMB >= requiredMB;
        }
      } catch (_) {}

      _initialAvailableStorage = null;

      if (!mounted) return;
      setState(() => _isAdLoading = false);

      if (isSuccess) {
        try {
          await CloudFunctions.claimGems(
            widget.installGems > 0 ? widget.installGems : 5,
            true,
          );
        } catch (e) {
           // debugPrint("Claim gems error in install flow: $e");
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          ref.invalidate(DashboardService.userDataProvider(user.uid));
          ref.invalidate(DashboardService.superOfferDataProvider(user.uid));
          ref.invalidate(diamondCatchVerifierProvider(user.uid));
        }

        if (mounted) {
          setState(() {
            _isClaimed = true;
            _popupState = _PopupState.taskSuccess;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _popupState = _PopupState.taskFailed;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWin = widget.isWin;

    Color borderColor;
    List<Color> bgGradient;
    List<Color> orbGradient;
    Color orbBorderColor;
    Color orbShadowColor;
    List<Color> arcColors;
    List<Color> closeBtnColors;
    Color closeGlowColor;

    switch (_popupState) {
      case _PopupState.winResult:
        borderColor = isWin
            ? const Color(0xFFFFD700)
            : const Color(0xFFFF4D4D);
        bgGradient = isWin
            ? const [Color(0xFF6E370F), Color(0xFF8B4513), Color(0xFF532809)]
            : const [Color(0xFF532809), Color(0xFF3E1C03), Color(0xFF241002)];
        orbGradient = isWin
            ? const [Color(0xFFFEF08A), Color(0xFFFBBF24), Color(0xFFD97706)]
            : const [Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFB91C1C)];
        orbBorderColor = isWin
            ? const Color(0xFFFFD700)
            : const Color(0xFFFF4D4D);
        orbShadowColor = isWin
            ? const Color(0xFFFFD700).withValues(alpha: 0.50)
            : const Color(0xFFEF4444).withValues(alpha: 0.50);
        arcColors = isWin
            ? [
                const Color(0xFFFFD700).withValues(alpha: 0.35),
                const Color(0xFFD97706).withValues(alpha: 0.20),
                Colors.transparent,
              ]
            : [
                const Color(0xFFEF4444).withValues(alpha: 0.35),
                const Color(0xFFB91C1C).withValues(alpha: 0.20),
                Colors.transparent,
              ];
        closeBtnColors = const [Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFB91C1C)];
        closeGlowColor = const Color(0xFFEF4444);
        break;

      case _PopupState.finishToUnlock:
        borderColor = const Color(0xFFFFD700);
        bgGradient = const [Color(0xFF6E370F), Color(0xFF8B4513), Color(0xFF532809)];
        orbGradient = const [Color(0xFFFEF08A), Color(0xFFFBBF24), Color(0xFFD97706)];
        orbBorderColor = const Color(0xFFFFD700);
        orbShadowColor = const Color(0xFFFFD700).withValues(alpha: 0.50);
        arcColors = [
          const Color(0xFFFFD700).withValues(alpha: 0.35),
          const Color(0xFFD97706).withValues(alpha: 0.20),
          Colors.transparent,
        ];
        closeBtnColors = const [Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFB91C1C)];
        closeGlowColor = const Color(0xFFEF4444);
        break;

      case _PopupState.taskFailed:
        borderColor = const Color(0xFFFF4D4D);
        bgGradient = const [Color(0xFF532809), Color(0xFF3E1C03), Color(0xFF241002)];
        orbGradient = const [Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFB91C1C)];
        orbBorderColor = const Color(0xFFFF4D4D);
        orbShadowColor = const Color(0xFFEF4444).withValues(alpha: 0.50);
        arcColors = [
          const Color(0xFFEF4444).withValues(alpha: 0.35),
          const Color(0xFFB91C1C).withValues(alpha: 0.20),
          Colors.transparent,
        ];
        closeBtnColors = const [Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFB91C1C)];
        closeGlowColor = const Color(0xFFEF4444);
        break;

      case _PopupState.taskSuccess:
        borderColor = const Color(0xFF4ADE80);
        bgGradient = const [Color(0xFF14532D), Color(0xFF0F3E22), Color(0xFF0A2916)];
        orbGradient = const [Color(0xFF86EFAC), Color(0xFF22C55E), Color(0xFF15803D)];
        orbBorderColor = const Color(0xFF4ADE80);
        orbShadowColor = const Color(0xFF22C55E).withValues(alpha: 0.50);
        arcColors = [
          const Color(0xFF22C55E).withValues(alpha: 0.35),
          const Color(0xFF15803D).withValues(alpha: 0.20),
          Colors.transparent,
        ];
        closeBtnColors = const [Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFB91C1C)];
        closeGlowColor = const Color(0xFFEF4444);
        break;
    }

    return PopScope(
      canPop: !_isAdLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _popupState != _PopupState.winResult && !_isAdLoading) {
          setState(() => _popupState = _PopupState.winResult);
        }
      },
      child: AbsorbPointer(
        absorbing: _isAdLoading,
        child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // 1. 3D Cartoon Wooden Dialog Base Card
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(top: 22.h),
              padding: EdgeInsets.fromLTRB(20.w, 32.h, 20.w, 20.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: bgGradient,
                ),
                borderRadius: BorderRadius.circular(26.r),
                border: Border.all(
                  color: borderColor,
                  width: 2.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _buildCurrentStateBody(
                  isWin: isWin,
                  orbGradient: orbGradient,
                  orbBorderColor: orbBorderColor,
                  orbShadowColor: orbShadowColor,
                ),
              ),
            ),

            // 2. Top Overlapping 3D Cartoon Gold Header Ribbon Banner
            Positioned(
              top: 4.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 7.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isWin
                        ? const [Color(0xFFFFF176), Color(0xFFFFB300), Color(0xFFE65100)]
                        : const [Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFB91C1C)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: const Color(0xFFFFD700),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Stroke outline
                    Text(
                      isWin ? 'LEVEL CLEARED!' : 'GAME OVER!',
                      style: GoogleFonts.fredoka(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 4.5
                          ..color = const Color(0xFF3E1C03),
                      ),
                    ),
                    // Inner text
                    Text(
                      isWin ? 'LEVEL CLEARED!' : 'GAME OVER!',
                      style: GoogleFonts.fredoka(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Top-Right Floating 3D Red Gloss Close (X) Button
            Positioned(
              top: 10.h,
              right: 6.w,
              child: _PopScaleButton(
                onTap: _isAdLoading
                    ? () {}
                    : () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        widget.onRestart();
                      },
                child: Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFB91C1C)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
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

  Widget _buildCurrentStateBody({
    required bool isWin,
    required List<Color> orbGradient,
    required Color orbBorderColor,
    required Color orbShadowColor,
  }) {
    switch (_popupState) {
      case _PopupState.winResult:
        return _buildWinResultBody(isWin, orbGradient, orbBorderColor, orbShadowColor);
      case _PopupState.finishToUnlock:
        return _buildFinishToUnlockBody(orbGradient, orbBorderColor, orbShadowColor);
      case _PopupState.taskFailed:
        return _buildTaskFailedBody(orbGradient, orbBorderColor, orbShadowColor);
      case _PopupState.taskSuccess:
        return _buildTaskSuccessBody(orbGradient, orbBorderColor, orbShadowColor);
    }
  }

  // ---------------------------------------------------------------------------
  // VIEW 1: WIN / LOSS RESULT BODY (DONE BUTTON MECHANISM FOR COLLECT BUTTON)
  // ---------------------------------------------------------------------------
  Widget _buildWinResultBody(
    bool isWin,
    List<Color> orbGradient,
    Color orbBorderColor,
    Color orbShadowColor,
  ) {
    final int rewardGems = widget.gameGems > 0
        ? widget.gameGems
        : (widget.dailyGems > 0 ? widget.dailyGems : 1);

    return Column(
      key: const ValueKey('winResultView'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Top 3D Animated Stars (On Win) or Subtitle Tag (On Loss)
        if (isWin) ...[
          Padding(
            padding: EdgeInsets.only(top: 8.h, bottom: 2.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _star1Anim,
                  child: Icon(Icons.star_rounded,
                      color: const Color(0xFFFFECB3), size: 30.sp),
                ),
                ScaleTransition(
                  scale: _star2Anim,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: Icon(Icons.star_rounded,
                        color: const Color(0xFFFFD700), size: 44.sp),
                  ),
                ),
                ScaleTransition(
                  scale: _star3Anim,
                  child: Icon(Icons.star_rounded,
                      color: const Color(0xFFFFECB3), size: 30.sp),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            'GAME OVER',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: const Color(0xFFFF4D4D),
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 4.h),
        ],

        // 2. Large Bold Main Title (Only on Game Over)
        if (!isWin) ...[
          Text(
            'TRY AGAIN!',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 26.sp,
              fontWeight: FontWeight.w900,
              height: 1.18,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 12.h),
        ],
        SizedBox(height: 16.h),

        // 3. Center Glowing 3D Panda Mascot Badge
        Container(
          width: 110.w,
          height: 110.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: orbGradient,
            ),
            border: Border.all(
              color: orbBorderColor,
              width: 2.2,
            ),
            boxShadow: [
              BoxShadow(
                color: orbShadowColor,
                blurRadius: 26,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/icons/panda1.png',
              width: 85.w,
              height: 85.w,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/icons/gems.png',
                width: 60.w,
                height: 60.w,
              ),
            ),
          ),
        ),

        SizedBox(height: 16.h),

        // 4. Stats: Reached Score (Only on Win)
        if (isWin) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF2C1607),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: const Color(0xFF8B4513),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'REACHED SCORE',
                  style: GoogleFonts.fredoka(
                    color: const Color(0xFFFFD700),
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${widget.score}',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18.h),
        ],

        // 5. Primary Action Button: COLLECT GEMS / CLAIMED (On Win) or RESUME (On Game Over)
        if (isWin) ...[
          Stack(
            clipBehavior: Clip.none,
            children: [
              _GlossyActionButton(
                title: _isClaimed ? 'CLAIMED' : 'COLLECT $rewardGems GEMS',
                isLoading: _isAdLoading,
                fillColors: _isClaimed
                    ? const [
                        Color(0xFF86EFAC),
                        Color(0xFF22C55E),
                        Color(0xFF15803D),
                        Color(0xFF166534),
                      ]
                    : const [
                        Color(0xFFFEF08A), // Gloss Yellow
                        Color(0xFFBEF264), // Bright Lime
                        Color(0xFF22C55E), // Candy Green
                        Color(0xFF15803D), // Dark Green Shadow
                      ],
                shadowColor: const Color(0xFF15803D).withValues(alpha: 0.70),
                prefix: _isClaimed
                    ? Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 20.sp)
                    : Image.asset(
                        'assets/icons/gems.png',
                        height: 22.w,
                        width: 22.w,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.diamond_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                      ),
                onTap: _isClaimed || _isAdLoading ? () {} : _handleClaimGems,
              ),
              if (!_isClaimed)
                Positioned(
                  top: -8.h,
                  right: 8.w,
                  child: Container(
                    width: 22.w,
                    height: 22.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.black,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'AD',
                      style: GoogleFonts.fredoka(
                        color: Colors.black,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
        ] else ...[
          Stack(
            clipBehavior: Clip.none,
            children: [
              _GlossyActionButton(
                title: 'RESUME',
                isLoading: _isAdLoading,
                fillColors: const [
                  Color(0xFFF87171),
                  Color(0xFFEF4444),
                  Color(0xFFB91C1C),
                  Color(0xFF991B1B),
                ],
                shadowColor: const Color(0xFF7F1D1D).withValues(alpha: 0.70),
                prefix: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22.sp,
                ),
                onTap: _isAdLoading ? () {} : _handleResumeGame,
              ),
              Positioned(
                top: -8.h,
                right: 8.w,
                child: Container(
                  width: 22.w,
                  height: 22.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.black,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'AD',
                    style: GoogleFonts.fredoka(
                      color: Colors.black,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
        ],

        // 6. Secondary Action: PLAY AGAIN
        _PopScaleButton(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            widget.onRestart();
          },
          child: Container(
            width: double.infinity,
            height: 46.h,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFEF08A), Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFB45309)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.replay_rounded,
                    color: Colors.white, size: 20.sp),
                SizedBox(width: 6.w),
                Text(
                  'PLAY AGAIN',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW 2: FINISH TO UNLOCK BODY (EXACT SUPER OFFER DESIGN)
  // ---------------------------------------------------------------------------
  Widget _buildFinishToUnlockBody(
    List<Color> orbGradient,
    Color orbBorderColor,
    Color orbShadowColor,
  ) {
    return Column(
      key: const ValueKey('finishToUnlockView'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Tag
        Text(
          'Diamond Catch',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: const Color(0xFFDDD6FE),
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 4.h),

        // 2. Title
        Text(
          'Finish To Unlock',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            height: 1.18,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 16.h),

        // 3. Glowing Orb with Unlock Icon
        Container(
          width: 76.w,
          height: 76.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: orbGradient,
            ),
            border: Border.all(
              color: orbBorderColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: orbShadowColor,
                blurRadius: 26,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.lock_open_rounded,
                color: Colors.white,
                size: 22.sp,
              ),
            ),
          ),
        ),

        SizedBox(height: 14.h),

        // 4. Description
        Text(
          'ad-description'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            fontSize: 12.5.sp,
            color: const Color(0xFFCBD5E1),
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        SizedBox(height: 12.h),

        // 4 Step Cards
        _buildStepCard('1', 'step-1'.tr()),
        _buildStepCard('2', 'step-2'.tr()),
        _buildStepCard('3', 'step-3'.tr()),
        _buildStepCard('4', 'step-4'.tr()),

        SizedBox(height: 12.h),

        // Action Buttons Row: HOW TO ? & WATCH AD
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _PopScaleButton(
                onTap: () {
                  final tutorialUrl =
                      SplashService.superOfferConfig['tutorialUrl']?.toString() ?? '';
                  if (tutorialUrl.isNotEmpty) {
                    LaunchUrl.inWeb(url: tutorialUrl, context: context);
                  } else {
                    _showHowToPlayDialog();
                  }
                },
                child: Container(
                  height: 48.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF140F2D),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.50),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.20),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        color: const Color(0xFFDDD6FE),
                        size: 16.sp,
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        'HOW TO ?',
                        style: GoogleFonts.fredoka(
                          color: const Color(0xFFDDD6FE),
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              flex: 3,
              child: _GlossyActionButton(
                title: 'WATCH AD',
                isLoading: _isAdLoading,
                fillColors: const [
                  Color(0xFFEADBFF),
                  Color(0xFFA565FF),
                  Color(0xFF6B15F6),
                  Color(0xFF550BD0),
                ],
                shadowColor: const Color(0xFF24007A).withValues(alpha: 0.70),
                prefix: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 18.sp,
                ),
                onTap: _isAdLoading ? () {} : _handleWatchAdInInstallTask,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW 3: TASK FAILED BODY (GLOSSY ACTION BUTTON)
  // ---------------------------------------------------------------------------
  Widget _buildTaskFailedBody(
    List<Color> orbGradient,
    Color orbBorderColor,
    Color orbShadowColor,
  ) {
    return Column(
      key: const ValueKey('taskFailedView'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Oops!',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: const Color(0xFFFDA4AF),
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Task Failed!',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            height: 1.18,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          width: 110.w,
          height: 110.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: orbGradient,
            ),
            border: Border.all(
              color: orbBorderColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: orbShadowColor,
                blurRadius: 26,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(Icons.close_rounded, color: Colors.white, size: 44.sp),
          ),
        ),
        SizedBox(height: 16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Text(
            'App not installed or requirements not completed. Please install the promoted app and try again!',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: const Color(0xFFCBD5E1),
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
        ),
        SizedBox(height: 20.h),
        _GlossyActionButton(
          title: 'TRY AGAIN',
          fillColors: const [
            Color(0xFFFFD1D6),
            Color(0xFFFB7185),
            Color(0xFFEF4444),
            Color(0xFF991B1B),
          ],
          shadowColor: const Color(0xFF7F1D1D).withValues(alpha: 0.70),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _popupState = _PopupState.winResult);
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW 4: TASK SUCCESS BODY (GLOSSY ACTION BUTTON)
  // ---------------------------------------------------------------------------
  Widget _buildTaskSuccessBody(
    List<Color> orbGradient,
    Color orbBorderColor,
    Color orbShadowColor,
  ) {
    final int gemsEarned =
        widget.installGems > 0 ? widget.installGems : 5;

    return Column(
      key: const ValueKey('taskSuccessView'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Diamond Catch',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: const Color(0xFFA7F3D0),
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '+$gemsEarned Gems',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            height: 1.18,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          width: 110.w,
          height: 110.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: orbGradient,
            ),
            border: Border.all(
              color: orbBorderColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: orbShadowColor,
                blurRadius: 26,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(Icons.check_rounded, color: Colors.white, size: 44.sp),
          ),
        ),
        SizedBox(height: 16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Text(
            'You\'ve successfully completed Diamond Catch and earned gems—keep going!',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: const Color(0xFFCBD5E1),
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
        ),
        SizedBox(height: 20.h),
        _GlossyActionButton(
          title: 'CONTINUE',
          fillColors: const [
            Color(0xFFD1FAE5),
            Color(0xFF34D399),
            Color(0xFF10B981),
            Color(0xFF047857),
          ],
          shadowColor: const Color(0xFF065F46).withValues(alpha: 0.70),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _popupState = _PopupState.winResult);
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP CARD WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildStepCard(String index, String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      margin: EdgeInsets.only(bottom: 7.h),
      decoration: BoxDecoration(
        color: const Color(0xFF140F2D),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFBA4FFF).withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22.w,
            height: 22.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFA855F7), Color(0xFF7E10C8)],
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              index,
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CLAIM HANDLERS
  // ---------------------------------------------------------------------------
  Future<void> _handleClaimGems() async {
    if (_isClaimed || _isAdLoading) return;

    setState(() => _isAdLoading = true);

    try {
      DiamondCatchSet? verifier;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          verifier = await ref.read(diamondCatchVerifierProvider(currentUser.uid).future);
          if (verifier != null && verifier.gameEligible == false) {
            CustomToast.showToast(
              context,
              msg: 'Today game limit over, come tomorrow!',
            );
            if (mounted) setState(() => _isAdLoading = false);
            return;
          }
        } catch (e) {
           // debugPrint("Limit check error in game collect: $e");
        }
      }

      final bool isInstallFlow =
          (verifier?.gameInstallTask == true) || widget.isInstallTask;

      if (isInstallFlow) {
        if (mounted) {
          setState(() {
            _isAdLoading = false;
            _popupState = _PopupState.finishToUnlock;
          });
        }
        return;
      }

      if (!mounted || !context.mounted) return;
      bool rewardGranted = false;

      Future<void> executeGemClaim() async {
        if (rewardGranted) return;
        rewardGranted = true;

        final int gemsToClaim = widget.gameGems > 0
            ? widget.gameGems
            : (widget.dailyGems > 0 ? widget.dailyGems : 1);

        try {
          await CloudFunctions.claimGems(
            gemsToClaim,
            false,
          );
        } catch (e) {
           // debugPrint("Claim gems error: $e");
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          ref.invalidate(DashboardService.userDataProvider(user.uid));
          ref.invalidate(DashboardService.superOfferDataProvider(user.uid));
          ref.invalidate(diamondCatchVerifierProvider(user.uid));
        }
        if (!mounted) return;
        setState(() {
          _isClaimed = true;
          _isAdLoading = false;
        });

        CustomToast.showToast(
          context,
          msg: '🎉 Gems Claimed Successfully!',
        );
      }

      final String adType = SplashService.superOfferConfig['adType']
              ?.toString()
              .toLowerCase() ??
          'rewarded';

      if (adType == 'interstitial') {
        await AdManager().showInterstitialAd(
          onClosed: () async {
            await executeGemClaim();
            if (mounted) {
              setState(() => _isAdLoading = false);
            }
          },
        );
      } else {
        await AdManager().showRewardedAd(
          context: context,
          onAdClicked: () async {},
          onReward: () async {
            await executeGemClaim();
          },
          onAdClosed: (_) {
            if (mounted) {
              setState(() => _isAdLoading = false);
            }
          },
          onAdFailed: () {
            if (mounted) {
              setState(() => _isAdLoading = false);
            }
          },
        );
      }
    } catch (e) {
       // debugPrint("Ad Error: $e");
      if (mounted) {
        setState(() => _isAdLoading = false);
      }
    }
  }

  Future<void> _handleWatchAdInInstallTask() async {
    if (_isAdLoading) return;
    HapticFeedback.lightImpact();
    setState(() => _isAdLoading = true);

    try {
      try {
        _initialAvailableStorage =
            await _appManagerChannel.invokeMethod<int>('getAvailableStorage') ?? 0;
      } catch (_) {}

      final adType = SplashService.superOfferConfig['adType']
              ?.toString()
              .toLowerCase() ??
          'rewarded';

      if (adType == 'interstitial') {
        await AdManager().showInterstitialAd(
          onClosed: () {
            _installClickTime = DateTime.now();
            if (mounted) setState(() => _isAdLoading = false);
          },
        );
      } else {
        await AdManager().showRewardedAd(
          context: context,
          onReward: () async {},
          onAdClicked: () async {
            _installClickTime = DateTime.now();
          },
          onAdClosed: (_) {
            _installClickTime = DateTime.now();
            if (mounted) setState(() => _isAdLoading = false);
          },
          onAdFailed: () {
            if (mounted) {
              setState(() => _isAdLoading = false);
            }
          },
        );
      }
    } catch (e) {
       // debugPrint("Ad watch error: $e");
      if (mounted) {
        setState(() => _isAdLoading = false);
      }
    }
  }

  Future<void> _handleResumeGame() async {
    if (_isAdLoading) return;
    HapticFeedback.lightImpact();
    setState(() => _isAdLoading = true);

    try {
      final adType = SplashService.superOfferConfig['adType']
              ?.toString()
              .toLowerCase() ??
          'rewarded';

      if (adType == 'interstitial') {
        await AdManager().showInterstitialAd(
          onClosed: () {
            if (mounted) {
              Navigator.pop(context);
              widget.onResume?.call();
            }
          },
        );
      } else {
        await AdManager().showRewardedAd(
          context: context,
          onReward: () async {},
          onAdClicked: () async {},
          onAdClosed: (_) {
            if (mounted) {
              Navigator.pop(context);
              widget.onResume?.call();
            }
          },
          onAdFailed: () {
            if (mounted) {
              setState(() => _isAdLoading = false);
              Navigator.pop(context);
              widget.onResume?.call();
            }
          },
        );
      }
    } catch (e) {
       // debugPrint("Resume Ad Error: $e");
      if (mounted) {
        setState(() => _isAdLoading = false);
        Navigator.pop(context);
        widget.onResume?.call();
      }
    }
  }

  void _showHowToPlayDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        backgroundColor: const Color(0xFF15103B),
        child: Padding(
          padding: EdgeInsets.all(22.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFFA855F7)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.help_center_rounded,
                    color: Colors.white, size: 30.sp),
              ),
              SizedBox(height: 14.h),
              Text(
                'How To Complete Task?',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                '1. Click on "WATCH AD" button.\n2. When ad plays, click to open Play Store.\n3. Install the promoted app.\n4. Open the installed app for at least 30 seconds.\n5. Return back to claim your gems!',
                style: GoogleFonts.fredoka(
                  fontSize: 12.5.sp,
                  color: const Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 20.h),
              GestureDetector(
                onTap: () => Navigator.pop(dialogCtx),
                child: Container(
                  width: double.infinity,
                  height: 44.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFF7E10C8)],
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'GOT IT!',
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
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
}

// ---------------------------------------------------------------------------
// 3D GLOSSY TAPERED ACTION BUTTON (DONE BUTTON MECHANISM)
// ---------------------------------------------------------------------------

class _GlossyActionButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final List<Color> fillColors;
  final Color shadowColor;
  final Widget? prefix;
  final bool isLoading;

  const _GlossyActionButton({
    required this.title,
    required this.onTap,
    required this.fillColors,
    required this.shadowColor,
    this.prefix,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return _PopScaleButton(
      onTap: isLoading ? () {} : onTap,
      child: CustomPaint(
        painter: _TaperedButtonPainter(
          taper: 7.0,
          radius: 16.0,
          fillColors: fillColors,
          shadowColor: shadowColor,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48.h,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (prefix != null) ...[
                          prefix!,
                          SizedBox(width: 7.w),
                        ],
                        Text(
                          title,
                          maxLines: 1,
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PopScaleButton extends StatefulWidget {
  const _PopScaleButton({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PopScaleButton> createState() => _PopScaleButtonState();
}

class _PopScaleButtonState extends State<_PopScaleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
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
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _TaperedButtonPainter extends CustomPainter {
  final double taper;
  final double radius;
  final List<Color> fillColors;
  final Color shadowColor;

  const _TaperedButtonPainter({
    this.taper = 7.0,
    this.radius = 16.0,
    required this.fillColors,
    required this.shadowColor,
  });

  Path getButtonPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final t = taper;
    final r = radius;

    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w - (t * 0.15), r * 0.7);
    path.lineTo(w - t + (t * 0.15), h - r * 0.7);
    path.quadraticBezierTo(w - t, h, w - t - r, h);
    path.lineTo(t + r, h);
    path.quadraticBezierTo(t, h, t - (t * 0.15), h - r * 0.7);
    path.lineTo(t * 0.15, r * 0.7);
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = getButtonPath(size);

    canvas.drawShadow(path, shadowColor, 8.0, true);

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: fillColors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.30, 0.75, 1.0],
      ).createShader(rect);

    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.25),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.45, 0.9],
      ).createShader(rect);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TaperedButtonPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// CENTER NOTCHED POPUP CLIPPER & PAINTERS
// ---------------------------------------------------------------------------

class _CenterNotchedClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double notchWidth;
  final double notchDepth;

  const _CenterNotchedClipper({
    this.cornerRadius = 24.0,
    this.notchWidth = 68.0,
    this.notchDepth = 22.0,
  });

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final cx = w / 2;
    final hw = notchWidth / 2;
    final d = notchDepth;

    final path = Path();
    path.moveTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);

    path.lineTo(cx - hw - 8, 0);

    path.cubicTo(
      cx - hw + 2, 0,
      cx - hw - 2, d * 0.5,
      cx - hw + 8, d * 0.85,
    );
    path.cubicTo(
      cx - hw + 16, d + 3,
      cx + hw - 16, d + 3,
      cx + hw - 8, d * 0.85,
    );
    path.cubicTo(
      cx + hw + 2, d * 0.5,
      cx + hw - 2, 0,
      cx + hw + 8, 0,
    );

    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);

    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);

    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CenterNotchedBorderPainter extends CustomPainter {
  final double cornerRadius;
  final double notchWidth;
  final double notchDepth;
  final Color borderColor;

  const _CenterNotchedBorderPainter({
    this.cornerRadius = 24.0,
    this.notchWidth = 68.0,
    this.notchDepth = 22.0,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final cx = w / 2;
    final hw = notchWidth / 2;
    final d = notchDepth;

    final path = Path();
    path.moveTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.lineTo(cx - hw - 8, 0);

    path.cubicTo(
      cx - hw + 2, 0,
      cx - hw - 2, d * 0.5,
      cx - hw + 8, d * 0.85,
    );
    path.cubicTo(
      cx - hw + 16, d + 3,
      cx + hw - 16, d + 3,
      cx + hw - 8, d * 0.85,
    );
    path.cubicTo(
      cx + hw + 2, d * 0.5,
      cx + hw - 2, 0,
      cx + hw + 8, 0,
    );

    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);

    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);

    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);
    path.close();

    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        borderColor.withValues(alpha: 0.90),
        borderColor.withValues(alpha: 0.45),
        borderColor.withValues(alpha: 0.70),
      ],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CenterNotchedBorderPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.notchWidth != notchWidth ||
        oldDelegate.notchDepth != notchDepth;
  }
}

// ---------------------------------------------------------------------------
// AMBIENT DUAL SWIRLING RIBBON ARCS BACKGROUND PAINTER
// ---------------------------------------------------------------------------

class _PopupSwirlingArcsPainter extends CustomPainter {
  final List<Color> arcColors;

  const _PopupSwirlingArcsPainter({required this.arcColors});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.44;
    final center = Offset(cx, cy);
    final radius = size.width * 0.30;
    const strokeW = 36.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Left Torus Ribbon Arc
    final leftShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomLeft,
      colors: arcColors,
    ).createShader(rect);

    final leftPaint = Paint()
      ..shader = leftShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    const leftStartAngle = 1.75;
    const leftSweepAngle = 2.45;
    canvas.drawArc(rect, leftStartAngle, leftSweepAngle, false, leftPaint);

    // Right Torus Ribbon Arc
    final rightShader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topRight,
      colors: arcColors,
    ).createShader(rect);

    final rightPaint = Paint()
      ..shader = rightShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    const rightStartAngle = 4.89;
    const rightSweepAngle = 2.45;
    canvas.drawArc(rect, rightStartAngle, rightSweepAngle, false, rightPaint);
  }

  @override
  bool shouldRepaint(covariant _PopupSwirlingArcsPainter oldDelegate) => true;
}

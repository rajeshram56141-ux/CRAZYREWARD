import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================================
/// ORIGINAL 3D WOODEN & GOLD ARCADE PAUSE OVERLAY
/// ============================================================================
/// - Matches the iconic original 3D Cartoon Wooden & Gold Game Popup design
/// - Blurred, dimmed semi-transparent background overlay
/// - Overlapping 3D Gold Ribbon Banner: PAUSED
/// - 3D Red Gloss Close (X) Button (Resumes Game)
/// - Wooden snapshot stats panel (Score, Distance, Coins)
/// - Sound, Music & Vibrate quick toggles
/// - 3D Glossy Tapered Action Buttons: RESUME, RESTART, HOME
/// ============================================================================

class RunnerPauseOverlay extends StatefulWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final VoidCallback? onSettings;
  final int currentScore;
  final double distanceMeters;
  final int coins;
  final double comboMultiplier;
  final bool isSoundOn;
  final bool isMusicOn;
  final bool isVibrateOn;
  final ValueChanged<bool>? onToggleSound;
  final ValueChanged<bool>? onToggleMusic;
  final ValueChanged<bool>? onToggleVibrate;

  const RunnerPauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onHome,
    this.onSettings,
    this.currentScore = 0,
    this.distanceMeters = 0.0,
    this.coins = 0,
    this.comboMultiplier = 1.0,
    this.isSoundOn = true,
    this.isMusicOn = true,
    this.isVibrateOn = true,
    this.onToggleSound,
    this.onToggleMusic,
    this.onToggleVibrate,
  });

  @override
  State<RunnerPauseOverlay> createState() => _RunnerPauseOverlayState();
}

class _RunnerPauseOverlayState extends State<RunnerPauseOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  late bool _sound;
  late bool _music;
  late bool _vibrate;

  @override
  void initState() {
    super.initState();
    _sound = widget.isSoundOn;
    _music = widget.isMusicOn;
    _vibrate = widget.isVibrateOn;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleResume() {
    HapticFeedback.lightImpact();
    widget.onResume();
  }

  void _handleRestart() {
    HapticFeedback.mediumImpact();
    widget.onRestart();
  }

  void _handleHome() {
    HapticFeedback.lightImpact();
    widget.onHome();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // 1. 3D Cartoon Wooden Dialog Base Card
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: 340.w),
                  margin: EdgeInsets.only(top: 22.h),
                  padding: EdgeInsets.fromLTRB(20.w, 32.h, 20.w, 20.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF6E370F),
                        Color(0xFF8B4513),
                        Color(0xFF532809),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26.r),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 2.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.75),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 6.h),

                      // 2. Race Snapshot Metrics (Score, Distance, Coins)
                      _buildRaceSnapshot(),

                      SizedBox(height: 14.h),

                      // 3. Audio & Haptic Quick Toggles Row
                      _buildQuickAudioToggles(),

                      SizedBox(height: 18.h),

                      // 4. Primary 3D Glossy Tapered Action Buttons
                      _buildActionButtons(),
                    ],
                  ),
                ),

                // 2. Top Overlapping 3D Cartoon Gold Header Ribbon Banner
                Positioned(
                  top: 4.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 26.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFF176),
                          Color(0xFFFFB300),
                          Color(0xFFE65100),
                        ],
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pause_circle_filled_rounded,
                            color: Colors.white, size: 20.sp),
                        SizedBox(width: 6.w),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Stroke outline
                            Text(
                              'GAME PAUSED',
                              style: GoogleFonts.fredoka(
                                fontSize: 17.sp,
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
                              'GAME PAUSED',
                              style: GoogleFonts.fredoka(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Top-Right Floating 3D Red Gloss Close (X) Button (Resumes Game)
                Positioned(
                  top: 10.h,
                  right: 6.w,
                  child: _PausePopScaleButton(
                    onTap: _handleResume,
                    child: Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF87171),
                            Color(0xFFEF4444),
                            Color(0xFFB91C1C),
                          ],
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
                        child: Icon(Icons.close_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // RACE SNAPSHOT STATS PILL (WOODEN EMBOSSED)
  // --------------------------------------------------------------------------
  Widget _buildRaceSnapshot() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1607),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF8B4513),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFFFD700),
            label: 'SCORE',
            value: '${widget.currentScore}',
          ),
          Container(
            width: 1.2,
            height: 26.h,
            color: const Color(0xFF8B4513),
          ),
          _buildStatItem(
            icon: Icons.near_me_rounded,
            color: const Color(0xFF38BDF8),
            label: 'DISTANCE',
            value: '${widget.distanceMeters.toInt()}m',
          ),
          Container(
            width: 1.2,
            height: 26.h,
            color: const Color(0xFF8B4513),
          ),
          _buildStatItem(
            icon: Icons.monetization_on_rounded,
            color: const Color(0xFFF59E0B),
            label: 'COINS',
            value: '${widget.coins}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14.sp),
            SizedBox(width: 4.w),
            Text(
              value,
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: GoogleFonts.fredoka(
            color: const Color(0xFFFFD700),
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // QUICK AUDIO & HAPTICS TOGGLES
  // --------------------------------------------------------------------------
  Widget _buildQuickAudioToggles() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAudioToggleBtn(
          icon: _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          active: _sound,
          onTap: () {
            setState(() => _sound = !_sound);
            widget.onToggleSound?.call(_sound);
          },
        ),
        SizedBox(width: 14.w),
        _buildAudioToggleBtn(
          icon: _music ? Icons.music_note_rounded : Icons.music_off_rounded,
          active: _music,
          onTap: () {
            setState(() => _music = !_music);
            widget.onToggleMusic?.call(_music);
          },
        ),
        SizedBox(width: 14.w),
        _buildAudioToggleBtn(
          icon: _vibrate ? Icons.vibration_rounded : Icons.mobile_off_rounded,
          active: _vibrate,
          onTap: () {
            setState(() => _vibrate = !_vibrate);
            widget.onToggleVibrate?.call(_vibrate);
          },
        ),
      ],
    );
  }

  Widget _buildAudioToggleBtn({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return _PausePopScaleButton(
      onTap: onTap,
      child: Container(
        width: 38.w,
        height: 38.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: active
                ? const [Color(0xFFFEF08A), Color(0xFFFBBF24), Color(0xFFD97706)]
                : const [Color(0xFF475569), Color(0xFF334155), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: active ? const Color(0xFFFFD700) : const Color(0xFF64748B),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: active ? const Color(0xFF3E1C03) : const Color(0xFF94A3B8),
            size: 19.sp,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ACTION BUTTONS (ORIGINAL 3D GLOSSY TAPERED)
  // --------------------------------------------------------------------------
  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. RESUME (Green 3D Glossy Button)
        _PauseGlossyActionButton(
          title: 'RESUME',
          prefix: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22.sp),
          fillColors: const [
            Color(0xFFFEF08A), // Gloss Yellow highlight
            Color(0xFFBEF264), // Bright Lime
            Color(0xFF22C55E), // Candy Green
            Color(0xFF15803D), // Dark Green Shadow
          ],
          shadowColor: const Color(0xFF15803D).withValues(alpha: 0.70),
          onTap: _handleResume,
        ),

        SizedBox(height: 10.h),

        // 2. RESTART (Amber 3D Glossy Button)
        _PauseGlossyActionButton(
          title: 'RESTART',
          prefix: Icon(Icons.replay_rounded, color: Colors.white, size: 19.sp),
          fillColors: const [
            Color(0xFFFFF176),
            Color(0xFFFFB300),
            Color(0xFFE65100),
            Color(0xFFB43403),
          ],
          shadowColor: const Color(0xFFB43403).withValues(alpha: 0.70),
          onTap: _handleRestart,
        ),

        SizedBox(height: 10.h),

        // 3. HOME (Red 3D Glossy Button)
        _PauseGlossyActionButton(
          title: 'HOME',
          prefix: Icon(Icons.home_rounded, color: Colors.white, size: 19.sp),
          fillColors: const [
            Color(0xFFFCA5A5),
            Color(0xFFEF4444),
            Color(0xFFDC2626),
            Color(0xFF991B1B),
          ],
          shadowColor: const Color(0xFF991B1B).withValues(alpha: 0.70),
          onTap: _handleHome,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3D GLOSSY TAPERED ACTION BUTTON COMPONENT
// ---------------------------------------------------------------------------

class _PauseGlossyActionButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final List<Color> fillColors;
  final Color shadowColor;
  final Widget? prefix;

  const _PauseGlossyActionButton({
    required this.title,
    required this.onTap,
    required this.fillColors,
    required this.shadowColor,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return _PausePopScaleButton(
      onTap: onTap,
      child: CustomPaint(
        painter: _PauseTaperedButtonPainter(
          taper: 7.0,
          radius: 16.0,
          fillColors: fillColors,
          shadowColor: shadowColor,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 46.h,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (prefix != null) ...[
                    prefix!,
                    SizedBox(width: 6.w),
                  ],
                  Text(
                    title,
                    maxLines: 1,
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
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

class _PausePopScaleButton extends StatefulWidget {
  const _PausePopScaleButton({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PausePopScaleButton> createState() => _PausePopScaleButtonState();
}

class _PausePopScaleButtonState extends State<_PausePopScaleButton>
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

class _PauseTaperedButtonPainter extends CustomPainter {
  final double taper;
  final double radius;
  final List<Color> fillColors;
  final Color shadowColor;

  const _PauseTaperedButtonPainter({
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
  bool shouldRepaint(covariant _PauseTaperedButtonPainter oldDelegate) => true;
}

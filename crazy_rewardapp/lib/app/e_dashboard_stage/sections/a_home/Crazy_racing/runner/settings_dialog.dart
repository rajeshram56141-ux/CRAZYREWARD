import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'audio_service.dart';
import 'storage_service.dart';

/// ============================================================================
/// PREMIUM RACING GAME SETTINGS SCREEN
/// ============================================================================
/// Options:
/// - Music ON/OFF
/// - Sound ON/OFF
/// - Vibration ON/OFF
/// - Graphics Quality (Low, Medium, High, Ultra)
/// - Show FPS (ON/OFF)
/// - Tutorial (ON/OFF)
///
/// Buttons:
/// - RESET DATA (with custom confirmation modal)
/// - BACK
///
/// All settings are persisted locally via [RunnerStorageService].
/// ============================================================================

class RunnerSettingsDialog extends StatefulWidget {
  final VoidCallback onDataReset;
  final VoidCallback onAudioSettingsChanged;

  const RunnerSettingsDialog({
    super.key,
    required this.onDataReset,
    required this.onAudioSettingsChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onDataReset,
    required VoidCallback onAudioSettingsChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (context) => RunnerSettingsDialog(
        onDataReset: onDataReset,
        onAudioSettingsChanged: onAudioSettingsChanged,
      ),
    );
  }

  @override
  State<RunnerSettingsDialog> createState() => _RunnerSettingsDialogState();
}

class _RunnerSettingsDialogState extends State<RunnerSettingsDialog> {
  late bool _sound;
  late bool _music;
  late bool _vibrate;
  late String _graphicsQuality;
  late bool _showFps;
  late bool _tutorialEnabled;
  late String _controlMode;
  late String _swipeSensitivity;

  bool _showToast = false;
  String _toastMessage = "";
  bool _isToastSuccess = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _sound = RunnerStorageService.isSoundEnabled();
    _music = RunnerStorageService.isMusicEnabled();
    _vibrate = RunnerStorageService.isVibrationEnabled();
    _graphicsQuality = RunnerStorageService.getGraphicsQuality();
    _showFps = RunnerStorageService.isShowFpsEnabled();
    _tutorialEnabled = RunnerStorageService.isTutorialEnabled();
    _controlMode = RunnerStorageService.getControlMode();
    _swipeSensitivity = RunnerStorageService.getSwipeSensitivity();
  }

  void _triggerToast(String message, {bool isSuccess = true}) {
    setState(() {
      _toastMessage = message;
      _isToastSuccess = isSuccess;
      _showToast = true;
    });

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _showToast = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: BoxConstraints(maxHeight: 720.h),
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
              color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                blurRadius: 32,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.9),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Top Header Bar: Title & Close Icon
              Padding(
                padding: EdgeInsets.fromLTRB(18.w, 14.h, 16.w, 10.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(7.w),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.settings_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SETTINGS',
                              style: GoogleFonts.blackOpsOne(
                                fontSize: 18.sp,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              'SYSTEM & GAMEPLAY PREFERENCES',
                              style: GoogleFonts.outfit(
                                fontSize: 9.sp,
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        RunnerAudioService().playClick();
                        Navigator.pop(context);
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
              ),

              Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),

              // 2. Scrollable Settings List
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Floating Feedback Toast
                      if (_showToast)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: EdgeInsets.only(bottom: 12.h),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isToastSuccess
                                  ? [const Color(0xFF22C55E), const Color(0xFF10B981)]
                                  : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: (_isToastSuccess
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFEF4444))
                                    .withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isToastSuccess
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 16.sp,
                              ),
                              SizedBox(width: 6.w),
                              Flexible(
                                child: Text(
                                  _toastMessage,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // SECTION 1: AUDIO & HAPTICS
                      _buildSectionTitle("AUDIO & HAPTICS"),
                      SizedBox(height: 8.h),

                      // 1. Music ON/OFF
                      _buildToggleCard(
                        icon: Icons.music_note_rounded,
                        title: "Music",
                        subtitle: "High-energy turbo background soundtrack",
                        value: _music,
                        activeColor: const Color(0xFFA855F7),
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _music = val);
                          RunnerStorageService.setMusicEnabled(val);
                          widget.onAudioSettingsChanged();
                          _triggerToast(val ? "MUSIC ENABLED 🎵" : "MUSIC MUTED 🔇");
                        },
                      ),
                      SizedBox(height: 8.h),

                      // 2. Sound ON/OFF
                      _buildToggleCard(
                        icon: Icons.volume_up_rounded,
                        title: "Sound Effects",
                        subtitle: "Engine roaring, coin pickups, and nitro jet audio",
                        value: _sound,
                        activeColor: const Color(0xFF00F2FE),
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _sound = val);
                          RunnerStorageService.setSoundEnabled(val);
                          widget.onAudioSettingsChanged();
                          if (val) RunnerAudioService().playClick();
                          _triggerToast(val ? "SOUND EFFECTS ON 🔊" : "SOUND EFFECTS MUTED 🔇");
                        },
                      ),
                      SizedBox(height: 8.h),

                      // 3. Vibration ON/OFF
                      _buildToggleCard(
                        icon: Icons.vibration_rounded,
                        title: "Haptic Vibration",
                        subtitle: "Force feedback on lane shifts, collisions & near-misses",
                        value: _vibrate,
                        activeColor: const Color(0xFF22C55E),
                        onChanged: (val) {
                          setState(() => _vibrate = val);
                          RunnerStorageService.setVibrationEnabled(val);
                          widget.onAudioSettingsChanged();
                          if (val) {
                            HapticFeedback.heavyImpact();
                          }
                          _triggerToast(val ? "HAPTIC FEEDBACK ENABLED 📳" : "HAPTIC VIBRATION OFF");
                        },
                      ),

                      SizedBox(height: 16.h),

                      // SECTION 2: GRAPHICS & PERFORMANCE
                      _buildSectionTitle("GRAPHICS & PERFORMANCE"),
                      SizedBox(height: 8.h),

                      // 4. Graphics Quality Selector
                      _buildGraphicsQualitySelector(),
                      SizedBox(height: 8.h),

                      // 5. Show FPS (ON/OFF)
                      _buildToggleCard(
                        icon: Icons.speed_rounded,
                        title: "Show FPS Counter",
                        subtitle: "Display real-time 60 FPS performance overlay",
                        value: _showFps,
                        activeColor: const Color(0xFFFF9100),
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _showFps = val);
                          RunnerStorageService.setShowFpsEnabled(val);
                          _triggerToast(val ? "FPS COUNTER ENABLED ⚡" : "FPS COUNTER HIDDEN");
                        },
                      ),

                      SizedBox(height: 16.h),

                      // SECTION 3: STEERING & CONTROLS
                      _buildSectionTitle("STEERING & TOUCH CONTROLS"),
                      SizedBox(height: 8.h),

                      // Control Mode (Hybrid, Swipe Only, Buttons Only)
                      _buildControlModeSelector(),
                      SizedBox(height: 8.h),

                      // Swipe Sensitivity (High, Normal, Low)
                      _buildSwipeSensitivitySelector(),

                      SizedBox(height: 16.h),

                      // SECTION 4: GAMEPLAY & DATA
                      _buildSectionTitle("GAMEPLAY & DATA"),
                      SizedBox(height: 8.h),

                      // 6. Tutorial ON/OFF
                      _buildToggleCard(
                        icon: Icons.menu_book_rounded,
                        title: "Show Tutorial",
                        subtitle: "Display interactive guide and controls before race",
                        value: _tutorialEnabled,
                        activeColor: const Color(0xFF38BDF8),
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _tutorialEnabled = val);
                          RunnerStorageService.setTutorialEnabled(val);
                          _triggerToast(val ? "TUTORIAL ENABLED ON START 📖" : "TUTORIAL SKIPPED");
                        },
                      ),

                      SizedBox(height: 12.h),

                      // 7. Reset Data Danger Button
                      _buildResetDataButton(),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Action Bar: BACK BUTTON
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
                      Navigator.pop(context);
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
                        Icon(Icons.arrow_back_rounded, size: 20.sp),
                        SizedBox(width: 8.w),
                        Text(
                          "BACK",
                          style: GoogleFonts.blackOpsOne(
                            fontSize: 14.sp,
                            letterSpacing: 1.2,
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

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          title,
          style: GoogleFonts.outfit(
            color: const Color(0xFF94A3B8),
            fontSize: 10.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.5)
              : const Color(0xFF334155),
          width: 1.0,
        ),
        boxShadow: value
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(7.w),
                  decoration: BoxDecoration(
                    color: value
                        ? activeColor.withValues(alpha: 0.2)
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: value ? activeColor : const Color(0xFF475569),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: value ? activeColor : const Color(0xFF94A3B8),
                    size: 17.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.blackOpsOne(
                              color: Colors.white,
                              fontSize: 12.5.sp,
                              letterSpacing: 0.6,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: value
                                  ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              value ? "ON" : "OFF",
                              style: GoogleFonts.outfit(
                                color: value
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFFFCA5A5),
                                fontSize: 7.5.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: activeColor,
            activeTrackColor: activeColor.withValues(alpha: 0.4),
            inactiveThumbColor: const Color(0xFF64748B),
            inactiveTrackColor: const Color(0xFF1E293B),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildGraphicsQualitySelector() {
    final List<String> qualities = ["Low", "Medium", "High", "Ultra"];

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(7.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: const Color(0xFF38BDF8),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: const Color(0xFF38BDF8),
                      size: 17.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Graphics Quality",
                        style: GoogleFonts.blackOpsOne(
                          color: Colors.white,
                          fontSize: 12.5.sp,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        "Particle density, shaders & lighting effects",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  _graphicsQuality.toUpperCase(),
                  style: GoogleFonts.blackOpsOne(
                    color: const Color(0xFF38BDF8),
                    fontSize: 8.5.sp,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          // 4 Segmented Quality Pills
          Row(
            children: qualities.map((q) {
              final bool isSelected = _graphicsQuality.toLowerCase() == q.toLowerCase();

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _graphicsQuality = q);
                    RunnerStorageService.setGraphicsQuality(q);
                    _triggerToast("GRAPHICS SET TO $q ⭐");
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 2.w),
                    padding: EdgeInsets.symmetric(vertical: 7.h),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF334155),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      q.toUpperCase(),
                      style: GoogleFonts.blackOpsOne(
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        fontSize: 9.5.sp,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlModeSelector() {
    final modes = [
      {"id": "hybrid", "label": "HYBRID", "desc": "Swipes + Buttons"},
      {"id": "swipeOnly", "label": "SWIPE ONLY", "desc": "Full Gestures"},
      {"id": "buttonsOnly", "label": "BUTTONS", "desc": "On-Screen Keys"},
    ];

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: const Color(0xFF34D399),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.touch_app_rounded,
                  color: const Color(0xFF34D399),
                  size: 17.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Control Input Mode",
                    style: GoogleFonts.blackOpsOne(
                      color: Colors.white,
                      fontSize: 12.5.sp,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    "Select preferred steering mechanism",
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: modes.map((m) {
              final bool isSelected = _controlMode == m['id'];

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _controlMode = m['id']!);
                    RunnerStorageService.setControlMode(m['id']!);
                    _triggerToast("CONTROLS SET TO ${m['label']} 🎮");
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 2.w),
                    padding: EdgeInsets.symmetric(vertical: 7.h),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF047857)],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF34D399)
                            : const Color(0xFF334155),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF059669).withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      m['label']!,
                      style: GoogleFonts.blackOpsOne(
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        fontSize: 9.sp,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeSensitivitySelector() {
    final List<String> sensList = ["High", "Normal", "Low"];

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: const Color(0xFFA78BFA),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: const Color(0xFFA78BFA),
                  size: 17.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Swipe Sensitivity",
                    style: GoogleFonts.blackOpsOne(
                      color: Colors.white,
                      fontSize: 12.5.sp,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    "Distance threshold for lane shift registration",
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: sensList.map((s) {
              final bool isSelected = _swipeSensitivity.toLowerCase() == s.toLowerCase();

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _swipeSensitivity = s);
                    RunnerStorageService.setSwipeSensitivity(s);
                    _triggerToast("SENSITIVITY SET TO $s ⚡");
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 2.w),
                    padding: EdgeInsets.symmetric(vertical: 7.h),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFA78BFA)
                            : const Color(0xFF334155),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      s.toUpperCase(),
                      style: GoogleFonts.blackOpsOne(
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        fontSize: 9.5.sp,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResetDataButton() {
    return GestureDetector(
      onTap: _showConfirmResetDialog,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_forever_rounded,
              color: const Color(0xFFF87171),
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              "RESET ALL GAME DATA",
              style: GoogleFonts.blackOpsOne(
                fontSize: 12.sp,
                color: const Color(0xFFFCA5A5),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmResetDialog() {
    RunnerAudioService().playClick();
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 22.w),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: const Color(0xFFEF4444),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEF4444),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: const Color(0xFFEF4444),
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 12.h),

                Text(
                  'RESET ALL GAME DATA?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.blackOpsOne(
                    color: Colors.white,
                    fontSize: 16.sp,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 8.h),

                Text(
                  'This will permanently erase your High Score, Total Coins, Car Unlocks, and Upgrades. This action cannot be undone!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFCBD5E1),
                    fontSize: 11.sp,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 20.h),

                Row(
                  children: [
                    // CANCEL BUTTON
                    Expanded(
                      child: SizedBox(
                        height: 44.h,
                        child: OutlinedButton(
                          onPressed: () {
                            RunnerAudioService().playClick();
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF64748B), width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          child: Text(
                            'CANCEL',
                            style: GoogleFonts.blackOpsOne(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),

                    // CONFIRM RESET BUTTON
                    Expanded(
                      child: SizedBox(
                        height: 44.h,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            RunnerStorageService.resetAllData();
                            widget.onDataReset();
                            Navigator.pop(ctx);
                            _loadSettings();
                            setState(() {});
                            _triggerToast("ALL GAME DATA RESET! 🗑️", isSuccess: false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            elevation: 8,
                            shadowColor: const Color(0xFFEF4444).withValues(alpha: 0.5),
                          ),
                          child: Text(
                            'YES, RESET',
                            style: GoogleFonts.blackOpsOne(
                              fontSize: 12.sp,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class LeaderboardTimer extends HookWidget {
  const LeaderboardTimer({
    super.key,
    required this.leaderboardTimeLeft,
    this.digitColor = Colors.white,
    this.labelColor = Colors.white70,
  });

  final int leaderboardTimeLeft;
  final Color digitColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    // 1. Calculate the initial remaining time
    final timeLeftMillis = useState<int>(
      (leaderboardTimeLeft - DateTime.now().millisecondsSinceEpoch)
          .clamp(0, double.infinity)
          .toInt(),
    );

    // 2. Timer Logic
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final remaining =
            leaderboardTimeLeft - DateTime.now().millisecondsSinceEpoch;
        timeLeftMillis.value = remaining.clamp(0, double.infinity).toInt();
      });
      return timer.cancel;
    }, [leaderboardTimeLeft]);

    final duration = Duration(milliseconds: timeLeftMillis.value);
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (days > 0) ...[
          _TimeUnitCard(
            value: days,
            label: 'DAYS',
            digitColor: digitColor,
            labelColor: labelColor,
          ),
          _Separator(color: digitColor),
        ],
        if (days > 0 || hours > 0) ...[
          _TimeUnitCard(
            value: hours,
            label: 'HOURS',
            digitColor: digitColor,
            labelColor: labelColor,
          ),
          _Separator(color: digitColor),
        ],
        _TimeUnitCard(
          value: minutes,
          label: 'MIN',
          digitColor: digitColor,
          labelColor: labelColor,
        ),
        _Separator(color: digitColor),
        _TimeUnitCard(
          value: seconds,
          label: 'SEC',
          isLast: true,
          digitColor: digitColor,
          labelColor: labelColor,
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _TimeUnitCard extends StatelessWidget {
  const _TimeUnitCard({
    required this.value,
    required this.label,
    required this.digitColor,
    required this.labelColor,
    this.isLast = false,
  });

  final int value;
  final String label;
  final Color digitColor;
  final Color labelColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final valueStr = value.toString().padLeft(2, '0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: valueStr
                .split('')
                .map((char) => _AnimatedDigit(char: char, color: digitColor))
                .toList(),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: labelColor,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}

class _AnimatedDigit extends StatelessWidget {
  const _AnimatedDigit({required this.char, required this.color});

  final String char;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 30,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInBack,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final inAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.5),
            end: Offset.zero,
          ).animate(animation);

          final outAnimation = Tween<Offset>(
            begin: const Offset(0.0, -0.5),
            end: Offset.zero,
          ).animate(animation);

          return ClipRect(
            child: SlideTransition(
              position: child.key == ValueKey(char)
                  ? inAnimation
                  : outAnimation,
              child: FadeTransition(opacity: animation, child: child),
            ),
          );
        },
        child: Text(
          char,
          key: ValueKey<String>(char),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            height: 1.0,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: color,
            fontSize: 22,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

enum ShimmerType {
  shining,
  pulse,
}

class ShimmerTag extends HookWidget {
  const ShimmerTag({
    super.key,
    required this.child,
    this.active = true,
    this.duration = const Duration(milliseconds: 1500),
    this.blendMode = BlendMode.srcIn,
    this.baseColor,
    this.highlightColor,
    this.type = ShimmerType.pulse,
  });

  final Widget child;
  final bool active;
  final Duration duration;
  final BlendMode blendMode;
  final Color? baseColor;
  final Color? highlightColor;
  final ShimmerType type;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;

    final ctrl = useAnimationController(duration: duration);
    useEffect(() {
      ctrl.repeat(reverse: type == ShimmerType.pulse);
      return null;
    }, [ctrl, type]);

    final Color finalBase = baseColor ?? Colors.white.withOpacity(0.08);
    // If no highlight is provided, calculate a brighter version
    final Color finalHighlight = highlightColor ?? 
        (baseColor != null 
            ? baseColor!.withValues(alpha: (baseColor!.a * 2.2).clamp(0.0, 1.0)) 
            : Colors.white.withOpacity(0.35));
    final Color finalGlow = Color.lerp(finalBase, finalHighlight, 0.3) ?? finalBase;

    if (type == ShimmerType.pulse) {
      final animation = useMemoized(
        () => ColorTween(begin: finalBase, end: finalHighlight).animate(
          CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
        ),
        [ctrl, finalBase, finalHighlight],
      );

      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              final color = animation.value ?? finalBase;
              return LinearGradient(
                colors: [color, color],
              ).createShader(bounds);
            },
            blendMode: blendMode,
            child: child,
          );
        },
        child: child,
      );
    } else {
      // Shining (sliding linear sweep) effect
      return AnimatedBuilder(
        animation: ctrl,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  finalBase,
                  finalBase,
                  finalGlow,
                  finalHighlight,
                  finalGlow,
                  finalBase,
                  finalBase,
                ],
                stops: const [
                  0.0,
                  0.38,
                  0.47,
                  0.5,
                  0.53,
                  0.62,
                  1.0,
                ],
                transform: _ShimmerTransform(ctrl.value),
              ).createShader(bounds);
            },
            blendMode: blendMode,
            child: child,
          );
        },
        child: child,
      );
    }
  }
}

class _ShimmerTransform extends GradientTransform {
  final double percent;
  const _ShimmerTransform(this.percent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (percent * 3 - 1.5), 0, 0);
  }
}

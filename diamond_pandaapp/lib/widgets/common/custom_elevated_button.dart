import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../utils/theme/theme.dart';
import 'custom_loading.dart';

class CustomElevatedButton extends HookWidget {
  const CustomElevatedButton({
    super.key,
    required this.text,
    this.icon,
    this.child,
    this.onTap,
    this.backgroundColor = AppTheme.primaryColor,
    this.contentColor = Colors.white,
    this.fontSize = 16,
    this.padding = const EdgeInsets.symmetric(vertical: 20),
    this.gradient,
  });

  final String text;
  final Widget? child;
  final Widget? icon;
  final Function()? onTap;
  final Color backgroundColor;
  final Color contentColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final isLoading = useState<bool>(false);
    final scale = useState<double>(1.0);

    final isDisabled = onTap == null;

    return isLoading.value
        ? Center(
            child: SizedBox(
              height: 40,
              width: 40,
              child: GlowLightingSpinner(
                size: 24,
                colors: [
                  backgroundColor.withValues(alpha: 0.2),
                  backgroundColor.withValues(alpha: 0.6),
                  backgroundColor,
                ],
              ),
            ),
          )
        : GestureDetector(
            onTapDown: (_) {
              if (!isDisabled) scale.value = 0.9;
            },
            onTapUp: (_) {
              if (!isDisabled) scale.value = 1.0;
            },
            onTapCancel: () {
              if (!isDisabled) scale.value = 1.0;
            },
            onTap: () async {
              if (isDisabled || isLoading.value) return;

              final result = onTap!();
              if (result is Future) {
                try {
                  isLoading.value = true;
                  await result;
                } finally {
                  isLoading.value = false;
                }
              }
            },
            child: AnimatedScale(
              scale: scale.value,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Container(
                width: double.infinity,
                padding: padding,
                decoration: ShapeDecoration(
                  gradient: isDisabled
                      ? null
                      : gradient ?? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFBD70), // Light warm gold (top)
                            Color(0xFFC58133), // Dark gold (bottom)
                          ],
                        ),
                  color: isDisabled ? AppTheme.disabledColor : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: 8),
                    ],
                    child ??
                        Text(
                          text.tr(),
                          style: Theme.of(context).textTheme.headlineMedium!
                              .copyWith(
                                color: isDisabled
                                    ? Colors.white70
                                    : contentColor,
                                fontWeight: FontWeight.w600,
                                fontSize: fontSize.sp,
                              ),
                        ),
                  ],
                ),
              ),
            ),
          );
  }
}

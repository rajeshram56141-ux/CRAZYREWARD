import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/theme/theme.dart';

class CustomTextFormField extends StatelessWidget {
  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.hintText,
    this.textInputAction = TextInputAction.next,
    this.textInputType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.readOnly = false,
    this.maxLines = 1,
    this.translate = true,
    this.bgColor = const Color(0xFF222226),
    this.textColor = Colors.white,
    this.borderColor,
    this.focusedBorderColor = const Color(0xFF9333EA),
    this.inputFormatters,
    this.autofillHints,
    this.enableSuggestions = true,
    this.autocorrect = true,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputAction? textInputAction;
  final TextInputType textInputType;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool? readOnly;
  final int? maxLines;
  final bool translate;
  final Color bgColor;
  final Color textColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool enableSuggestions;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: TextFormField(
        controller: controller,
        textInputAction: textInputAction,
        keyboardType: textInputType,
        inputFormatters: inputFormatters,
        autofillHints: autofillHints,
        enableSuggestions: enableSuggestions,
        autocorrect: autocorrect,
        readOnly: readOnly!,
        cursorColor: focusedBorderColor ?? AppTheme.primaryColor,
        maxLines: maxLines,
        style: GoogleFonts.outfit(
          color: textColor,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: translate ? hintText.tr() : hintText,
          hintStyle: GoogleFonts.outfit(
            color: textColor.withValues(alpha: 0.4),
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: prefixIcon != null
              ? Padding(
                  padding: EdgeInsets.only(left: 12.w, right: 8.w),
                  child: prefixIcon,
                )
              : null,
          suffixIcon: suffixIcon,

          // Background Style
          filled: true,
          fillColor: bgColor,
          contentPadding: EdgeInsets.symmetric(
            vertical: 13.h,
            horizontal: 16.w,
          ),

          // Borders Styling
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(
              color: borderColor ??
                  (bgColor == const Color(0xFF222226)
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFF1E293B)),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(
              color: focusedBorderColor ?? const Color(0xFF9333EA),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(color: AppTheme.errorColor, width: 1),
          ),

          // Error Style
          errorStyle: GoogleFonts.outfit(
            fontSize: 11.sp,
            color: AppTheme.errorColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

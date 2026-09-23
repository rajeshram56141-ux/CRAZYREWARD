import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.systemOverlayStyle,
    this.isDarkBackground = false,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool isDarkBackground;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && showBackButton) {
      effectiveLeading = GestureDetector(
        onTap: () => AutoRouter.of(context).maybePop(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDarkBackground ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDarkBackground ? Colors.white : const Color(0xFF1E1B4B),
            size: 18,
          ),
        ),
      );
    }

    return AppBar(
      systemOverlayStyle: systemOverlayStyle ?? SystemUiOverlayStyle.light,
      title: Text(
        title.tr(),
        style: Theme.of(context).appBarTheme.titleTextStyle,
      ),
      forceMaterialTransparency: true,
      leading: effectiveLeading,
      automaticallyImplyLeading: showBackButton,
      actions: actions,
    );
  }
}

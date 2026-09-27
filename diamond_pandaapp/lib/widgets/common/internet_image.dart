import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/theme/theme.dart';
import 'custom_loading.dart';

class AvatarInternetImage extends StatelessWidget {
  const AvatarInternetImage({
    super.key,
    required this.url,
    required this.size,
    this.borderColor = AppTheme.primaryColor,
    this.borderWidth = 0.6,
  });

  final String url;
  final double size;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || url == "null") {
      return Container(
        width: size.sp,
        height: size.sp,
        decoration: BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Icon(
          Icons.broken_image_rounded,
          size: (size / 2).sp,
          color: AppTheme.titleColor,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, imageProvider) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size.sp,
            height: size.sp,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white10,
              border: Border.all(color: borderColor, width: borderWidth),
              image: DecorationImage(image: imageProvider, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
      placeholder: (context, url) => Container(
        width: size.sp,
        height: size.sp,
        decoration: BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Center(
          child: SizedBox(
            width: (size / 2).sp,
            height: (size / 2).sp,
            child: Center(
              child: GlowLightingSpinner(size: (size / 2)),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: size.sp,
        height: size.sp,
        decoration: BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Icon(
          Icons.broken_image_rounded,
          size: (size / 2).sp,
          color: Colors.white,
        ),
      ),
    );
  }
}

class InternetImage extends StatelessWidget {
  const InternetImage({
    super.key,
    required this.url,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String url;
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final double finalWidth = (width ?? size ?? 50).sp;
    final double finalHeight = (height ?? size ?? 50).sp;

    final double iconSize =
        (finalWidth < finalHeight ? finalWidth : finalHeight) / 2;

    if (url.isEmpty || url == "null") {
      return _buildPlaceholder(finalWidth, finalHeight, iconSize);
    }

    if (url.toLowerCase().contains('.svg')) {
      return SvgPicture.network(
        url,
        width: finalWidth,
        height: finalHeight,
        fit: fit,
        placeholderBuilder: (context) => SizedBox(
          width: finalWidth,
          height: finalHeight,
          child: Center(
            child: GlowLightingSpinner(size: 20),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, imageProvider) => Container(
        width: finalWidth,
        height: finalHeight,
        decoration: BoxDecoration(
          image: DecorationImage(image: imageProvider, fit: fit),
        ),
      ),
      placeholder: (context, url) => SizedBox(
        width: finalWidth,
        height: finalHeight,
        child: Center(
          child: GlowLightingSpinner(size: 20),
        ),
      ),
      errorWidget: (context, url, error) =>
          _buildPlaceholder(finalWidth, finalHeight, iconSize),
    );
  }

  Widget _buildPlaceholder(double w, double h, double iSize) {
    return SizedBox(
      width: w,
      height: h,
      child: Icon(
        Icons.broken_image_rounded,
        size: iSize,
        color: Colors.white10,
      ),
    );
  }
}

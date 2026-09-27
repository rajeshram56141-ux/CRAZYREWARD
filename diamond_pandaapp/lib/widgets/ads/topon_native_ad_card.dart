import 'package:flutter/material.dart';
import 'package:topon_ad_plugin/topon_ad_plugin.dart';

import '../../utils/constant/constant.dart';

class ToponNativeAdCard extends StatefulWidget {
  final bool? isEnabled;
  final double? height;
  final EdgeInsetsGeometry? margin;

  const ToponNativeAdCard({
    super.key,
    this.isEnabled,
    this.height,
    this.margin,
  });

  @override
  State<ToponNativeAdCard> createState() => _ToponNativeAdCardState();
}

class _ToponNativeAdCardState extends State<ToponNativeAdCard> {
  bool _isAdLoaded = false;
  bool _adFailed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.isEnabled ?? AdKeys.isHomeNativeEnabled;
    if (!AdKeys.isAdsEnabled || !enabled || AdKeys.nativeKey.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (_adFailed) {
      return const SizedBox.shrink();
    }

    // Keep ToponNativeAdWidget in the tree so AndroidView initializes and loads
    // in the background. While _isAdLoaded is false, Offstage takes 0x0 space,
    // ensuring no empty white space or gap is shown before the ad is ready.
    return Offstage(
      offstage: !_isAdLoaded,
      child: Container(
        width: double.infinity,
        margin: widget.margin ?? EdgeInsets.zero,
        child: ToponNativeAdWidget(
          placementId: AdKeys.nativeKey.trim(),
          height: widget.height,
          onAdLoaded: () {
            if (mounted && !_isAdLoaded) {
              setState(() {
                _isAdLoaded = true;
                _adFailed = false;
              });
            }
          },
          onAdFailed: (error) {
            if (mounted) {
              setState(() {
                _adFailed = true;
                _isAdLoaded = false;
              });
            }
          },
        ),
      ),
    );
  }
}

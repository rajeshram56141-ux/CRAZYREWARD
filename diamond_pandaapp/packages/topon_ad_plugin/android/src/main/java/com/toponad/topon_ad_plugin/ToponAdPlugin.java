package com.toponad.topon_ad_plugin;

import android.app.Activity;
import android.content.Context;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;

import com.secmtp.sdk.banner.api.ATBannerListener;
import com.secmtp.sdk.banner.api.ATBannerView;
import com.secmtp.sdk.core.api.ATAdInfo;
import com.secmtp.sdk.core.api.AdError;
import com.secmtp.sdk.core.api.ATSDK;
import com.secmtp.sdk.nativead.api.ATNativeAdView;
import com.secmtp.sdk.nativead.api.ATNativeDislikeListener;
import com.secmtp.sdk.nativead.api.ATNativeEventListener;
import com.secmtp.sdk.nativead.api.ATNativeMaterial;
import com.secmtp.sdk.nativead.api.ATNativePrepareInfo;
import com.secmtp.sdk.rewardvideo.api.ATRewardVideoAd;
import com.secmtp.sdk.rewardvideo.api.ATRewardVideoListener;
import com.secmtp.sdk.interstitial.api.ATInterstitial;
import com.secmtp.sdk.interstitial.api.ATInterstitialListener;
import com.secmtp.sdk.nativead.api.ATNative;
import com.secmtp.sdk.nativead.api.NativeAd;
import com.secmtp.sdk.nativead.api.ATNativeNetworkListener;
import com.secmtp.sdk.splashad.api.ATSplashAd;
import com.secmtp.sdk.splashad.api.ATSplashAdEZListener;
import com.secmtp.sdk.splashad.api.ATSplashAdExtraInfo;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;

public class ToponAdPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
  private MethodChannel channel;
  private Context context;
  private Activity activity;
  private ATInterstitial interstitialAd;
  private ATSplashAd splashAd;
  private ATBannerView bannerView;
  private FrameLayout bannerContainer;
  private ATNative tuNative;
  private NativeAd nativeAd;
  private ATNativeAdView tuNativeAdView;
  private FrameLayout tuNativeContainer;
  private View tuNativeCtaView;
  private View tuNativeTitleView;
  private View tuNativeDescView;
  private View tuNativeIconView;
  private View tuNativeMainImageView;
  private ATRewardVideoAd rewardedVideoAd;

  private Result pendingInterstitialResult;
  private Result pendingRewardedResult;
  private Result pendingNativeResult;

  private static final String TAG = "ToponAdPlugin";

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), "topon_ad_plugin");
    channel.setMethodCallHandler(this);
    context = binding.getApplicationContext();

    binding.getPlatformViewRegistry().registerViewFactory(
        "topon_native_ad_view",
        new ToponNativeAdPlatformViewFactory(binding.getBinaryMessenger(), () -> activity)
    );
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "initSdk":
        initSdk(call, result);
        break;
      case "loadInterstitialAd":
        loadInterstitialAd(call, result);
        break;
      case "showInterstitial":
        showInterstitial(result);
        break;
      case "loadSplashAd":
        loadSplashAd(call, result);
        break;
      case "loadBannerAd":
        loadBannerAd(call, result);
        break;
      case "removeBannerAd":
        removeBannerAd(result);
        break;
      case "loadNativeAd":
        loadNativeAd(call, result);
        break;
      case "getNativeAdInfo":
        getNativeAdInfo(result);
        break;
      case "clickNativeAd":
        clickNativeAd(result);
        break;
      case "loadRewardedAd":
        loadRewardedAd(call, result);
        break;
      case "showRewardedAd":
        showRewardedAd(result);
        break;
      default:
        result.notImplemented();
    }
  }

  private void sendEventToDart(String method, Object arguments) {
    if (channel != null && activity != null) {
      activity.runOnUiThread(() -> channel.invokeMethod(method, arguments));
    }
  }

  private void initSdk(MethodCall call, Result result) {
    Map<String, Object> args = call.arguments();
    String appId = (String) args.get("appId");
    String appKey = (String) args.get("appKey");

    ATSDK.init(context, appId, appKey);
    result.success(true);
  }

  private void loadInterstitialAd(MethodCall call, Result result) {
    String placementId = call.argument("placementId");

    if (pendingInterstitialResult != null) {
      result.error("INTERSTITIAL_PENDING", "Interstitial ad is already loading or showing", null);
      return;
    }

    pendingInterstitialResult = result;

    interstitialAd = new ATInterstitial(activity, placementId);
    interstitialAd.setAdListener(new ATInterstitialListener() {
      @Override
      public void onInterstitialAdLoaded() {
        sendEventToDart("onInterstitialAdLoaded", null);
        if (pendingInterstitialResult != null) {
          pendingInterstitialResult.success(true);
          pendingInterstitialResult = null;
        }
      }

      @Override
      public void onInterstitialAdLoadFail(AdError adError) {
        sendEventToDart("onInterstitialAdLoadFail", adError.getFullErrorInfo());
        if (pendingInterstitialResult != null) {
          pendingInterstitialResult.success(false);
          pendingInterstitialResult = null;
        }
      }

      @Override
      public void onInterstitialAdClicked(ATAdInfo info) {
        sendEventToDart("onInterstitialAdClicked", info.getPlacementId());
      }

      @Override
      public void onInterstitialAdShow(ATAdInfo info) {
        sendEventToDart("onInterstitialAdShow", info.getPlacementId());
      }

      @Override
      public void onInterstitialAdClose(ATAdInfo info) {
        sendEventToDart("onInterstitialAdClose", info.getPlacementId());
      }

      @Override
      public void onInterstitialAdVideoStart(ATAdInfo info) {
        sendEventToDart("onInterstitialAdVideoStart", info.getPlacementId());
      }

      @Override
      public void onInterstitialAdVideoEnd(ATAdInfo info) {
        sendEventToDart("onInterstitialAdVideoEnd", info.getPlacementId());
      }

      @Override
      public void onInterstitialAdVideoError(AdError adError) {
        sendEventToDart("onInterstitialAdVideoError", adError.getFullErrorInfo());
      }
    });

    interstitialAd.load();
  }

  private void showInterstitial(Result result) {
    pendingInterstitialResult = null;
    if (interstitialAd != null && interstitialAd.isAdReady()) {
      interstitialAd.show(activity);
      result.success(true);
    } else {
      result.success(false);
    }
  }

  private void loadRewardedAd(MethodCall call, Result result) {
    String placementId = call.argument("placementId");

    if (pendingRewardedResult != null) {
      result.error("REWARDED_PENDING", "Rewarded ad is already loading or showing", null);
      return;
    }

    pendingRewardedResult = result;

    rewardedVideoAd = new ATRewardVideoAd(activity, placementId);
    rewardedVideoAd.setAdListener(new ATRewardVideoListener() {
      @Override
      public void onRewardedVideoAdLoaded() {
        sendEventToDart("onRewardedVideoAdLoaded", null);
        if (pendingRewardedResult != null) {
          pendingRewardedResult.success(true);
          pendingRewardedResult = null;
        }
      }

      @Override
      public void onRewardedVideoAdFailed(AdError adError) {
        sendEventToDart("onRewardedVideoAdFailed", adError.getFullErrorInfo());
        if (pendingRewardedResult != null) {
          pendingRewardedResult.success(false);
          pendingRewardedResult = null;
        }
      }

      @Override
      public void onRewardedVideoAdPlayStart(ATAdInfo adInfo) {
        sendEventToDart("onRewardedVideoAdPlayStart", adInfo.getPlacementId());
      }

      @Override
      public void onRewardedVideoAdPlayEnd(ATAdInfo adInfo) {
        sendEventToDart("onRewardedVideoAdPlayEnd", adInfo.getPlacementId());
      }

      @Override
      public void onRewardedVideoAdPlayFailed(AdError adError, ATAdInfo adInfo) {
        sendEventToDart("onRewardedVideoAdPlayFailed", adError.getFullErrorInfo());
      }

      @Override
      public void onRewardedVideoAdClosed(ATAdInfo adInfo) {
        sendEventToDart("onRewardedVideoAdClosed", adInfo.getPlacementId());
      }

      @Override
      public void onRewardedVideoAdPlayClicked(ATAdInfo adInfo) {
        sendEventToDart("onRewardedVideoAdPlayClicked", adInfo.getPlacementId());
      }

      @Override
      public void onReward(ATAdInfo adInfo) {
        sendEventToDart("onReward", adInfo.getPlacementId());
      }
    });

    rewardedVideoAd.load();
  }

  private void showRewardedAd(Result result) {
    pendingRewardedResult = null;
    if (rewardedVideoAd != null && rewardedVideoAd.isAdReady()) {
      rewardedVideoAd.show(activity);
      result.success(true);
    } else {
      result.success(false);
    }
  }

  private void loadSplashAd(MethodCall call, Result result) {
    String placementId = call.argument("placementId");

    splashAd = new ATSplashAd(context, placementId, new ATSplashAdEZListener() {
      @Override
      public void onAdLoaded() {
        sendEventToDart("onSplashAdLoaded", null);

        if (splashAd.isAdReady()) {
          activity.runOnUiThread(() -> {
            FrameLayout splashContainer = new FrameLayout(activity);
            splashContainer.setLayoutParams(new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
            ));

            ViewGroup decorView = (ViewGroup) activity.getWindow().getDecorView();
            decorView.addView(splashContainer);
            splashAd.show(activity, splashContainer);
          });
        } else {
          splashAd.loadAd();
        }
      }

      @Override
      public void onNoAdError(AdError adError) {
        sendEventToDart("onSplashAdError", adError.getFullErrorInfo());
      }

      @Override
      public void onAdShow(ATAdInfo entity) {
        sendEventToDart("onSplashAdShow", entity.getPlacementId());
      }

      @Override
      public void onAdClick(ATAdInfo entity) {
        sendEventToDart("onSplashAdClick", entity.getPlacementId());
      }

      @Override
      public void onAdDismiss(ATAdInfo entity, ATSplashAdExtraInfo extra) {
        sendEventToDart("onSplashAdDismiss", entity.getPlacementId());
      }
    });

    splashAd.loadAd();
    result.success(true);
  }

  private void loadBannerAd(MethodCall call, Result result) {
    String placementId = call.argument("placementId");
    String position = call.argument("position");

    if(bannerView == null){
      bannerView = new ATBannerView(activity);
      bannerView.setPlacementId(placementId);

      int width = activity.getResources().getDisplayMetrics().widthPixels;
      int height = ViewGroup.LayoutParams.WRAP_CONTENT;
      bannerView.setLayoutParams(new FrameLayout.LayoutParams(width, height));

      bannerView.setBannerAdListener(new ATBannerListener() {
        @Override
        public void onBannerLoaded() {
          sendEventToDart("onBannerLoaded", null);
        }

        @Override
        public void onBannerFailed(AdError adError) {
          sendEventToDart("onBannerFailed", adError.getFullErrorInfo());
        }

        @Override
        public void onBannerClicked(ATAdInfo tuAdInfo) {
          sendEventToDart("onBannerClicked", tuAdInfo.getPlacementId());
        }

        @Override
        public void onBannerShow(ATAdInfo tuAdInfo) {
          sendEventToDart("onBannerShow", tuAdInfo.getPlacementId());
        }

        @Override
        public void onBannerClose(ATAdInfo tuAdInfo) {
          sendEventToDart("onBannerClose", tuAdInfo.getPlacementId());
          if (bannerContainer != null) {
            bannerContainer.setVisibility(View.GONE);
          }
        }

        @Override
        public void onBannerAutoRefreshed(ATAdInfo tuAdInfo) {
          sendEventToDart("onBannerAutoRefreshed", tuAdInfo.getPlacementId());
        }

        @Override
        public void onBannerAutoRefreshFail(AdError adError) {
          sendEventToDart("onBannerAutoRefreshFail", adError.getFullErrorInfo());
        }
      });
    }

    activity.runOnUiThread(()-> {
      ViewGroup decorView = (ViewGroup) activity.getWindow().getDecorView();

      if (bannerContainer != null) {
        decorView.removeView(bannerContainer);
      }

      if(bannerView.getParent() != null){
        ((ViewGroup) bannerView.getParent()).removeView(bannerView);
      }

      bannerContainer = new FrameLayout(activity);
      FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
              ViewGroup.LayoutParams.MATCH_PARENT,
              ViewGroup.LayoutParams.WRAP_CONTENT
      );

      if("top".equalsIgnoreCase(position)){
        params.gravity = Gravity.TOP;
      }else{
        params.gravity = Gravity.BOTTOM;
      }

      bannerContainer.setLayoutParams(params);
      bannerContainer.addView(bannerView);
      decorView.addView(bannerContainer);
      bannerContainer.setVisibility(View.VISIBLE);
    });

    bannerView.loadAd();
    result.success(true);
  }

  private void removeBannerAd(Result result) {
    activity.runOnUiThread(() -> {
      if (bannerContainer != null) {
        ViewGroup decorView = (ViewGroup) activity.getWindow().getDecorView();
        decorView.removeView(bannerContainer);
        bannerContainer = null;
      }

      if (bannerView != null) {
        if (bannerView.getParent() != null) {
          ((ViewGroup) bannerView.getParent()).removeView(bannerView);
        }
        bannerView = null;
      }

      result.success(true);
    });
  }

  private String currentNativePlacementId;

  private void loadNativeAd(MethodCall call, Result result) {
    String placementId = call.argument("placementId");
    if (placementId == null || placementId.trim().isEmpty()) {
      result.error("INVALID_PLACEMENT", "Placement ID is null or empty", null);
      return;
    }

    // If ad is already loaded and ready in memory, return success immediately
    if (tuNative != null && placementId.equals(currentNativePlacementId)) {
      NativeAd existingAd = tuNative.getNativeAd();
      if (existingAd != null && existingAd.getAdMaterial() != null) {
        result.success(true);
        return;
      }
    }

    currentNativePlacementId = placementId;
    pendingNativeResult = result;

    Context ctx = activity != null ? activity : context;
    tuNative = new ATNative(ctx, placementId, new ATNativeNetworkListener() {
      @Override
      public void onNativeAdLoaded() {
        if (pendingNativeResult != null) {
          pendingNativeResult.success(true);
          pendingNativeResult = null;
        }
        sendEventToDart("onNativeAdLoaded", null);
      }

      @Override
      public void onNativeAdLoadFail(AdError adError) {
        if (pendingNativeResult != null) {
          pendingNativeResult.success(false);
          pendingNativeResult = null;
        }
        sendEventToDart("onNativeAdLoadFail", adError != null ? adError.getFullErrorInfo() : null);
      }
    });

    tuNative.makeAdRequest();
  }

  private void getNativeAdInfo(Result result) {
    if (activity == null) {
      result.error("NO_ACTIVITY", "Activity is null", null);
      return;
    }

    activity.runOnUiThread(() -> {
      try {
        nativeAd = tuNative != null ? tuNative.getNativeAd() : null;

        if (nativeAd != null && nativeAd.getAdMaterial() != null) {
          ATNativeMaterial material = (ATNativeMaterial) nativeAd.getAdMaterial();
          Map<String, Object> adInfo = buildAdInfo(material);

          if (tuNativeAdView == null) {
            tuNativeAdView = new ATNativeAdView(activity);
          }

          tuNativeAdView.removeAllViews();
          tuNativeContainer = new FrameLayout(activity);
          tuNativeCtaView = new View(activity);
          tuNativeTitleView = new View(activity);
          tuNativeDescView = new View(activity);
          tuNativeIconView = new View(activity);
          tuNativeMainImageView = new View(activity);

          tuNativeContainer.addView(tuNativeCtaView);
          tuNativeContainer.addView(tuNativeTitleView);
          tuNativeContainer.addView(tuNativeDescView);
          tuNativeContainer.addView(tuNativeIconView);
          tuNativeContainer.addView(tuNativeMainImageView);
          tuNativeAdView.addView(tuNativeContainer);

          ATNativePrepareInfo prepareInfo = new ATNativePrepareInfo();
          prepareInfo.setCtaView(tuNativeCtaView);
          prepareInfo.setTitleView(tuNativeTitleView);
          prepareInfo.setDescView(tuNativeDescView);
          prepareInfo.setIconView(tuNativeIconView);
          prepareInfo.setMainImageView(tuNativeMainImageView);

          List<View> clickViews = new ArrayList<>();
          clickViews.add(tuNativeCtaView);
          clickViews.add(tuNativeTitleView);
          clickViews.add(tuNativeDescView);
          clickViews.add(tuNativeIconView);
          clickViews.add(tuNativeMainImageView);
          clickViews.add(tuNativeContainer);
          clickViews.add(tuNativeAdView);
          prepareInfo.setClickViewList(clickViews);

          nativeAd.renderAdContainer(tuNativeAdView, tuNativeContainer);
          nativeAd.prepare(tuNativeAdView, prepareInfo);

          nativeAd.setNativeEventListener(new ATNativeEventListener() {
            @Override
            public void onAdImpressed(ATNativeAdView tuNativeAdView, ATAdInfo tuAdInfo) {
              sendEventToDart("onAdImpressed", tuAdInfo != null ? tuAdInfo.getPlacementId() : null);
            }

            @Override
            public void onAdClicked(ATNativeAdView tuNativeAdView, ATAdInfo tuAdInfo) {
              sendEventToDart("onAdClicked", tuAdInfo != null ? tuAdInfo.getPlacementId() : null);
            }

            @Override
            public void onAdVideoStart(ATNativeAdView tuNativeAdView) {
              sendEventToDart("onAdVideoStart", null);
            }

            @Override
            public void onAdVideoEnd(ATNativeAdView tuNativeAdView) {
              sendEventToDart("onAdVideoEnd", null);
            }

            @Override
            public void onAdVideoProgress(ATNativeAdView tuNativeAdView, int i) {
              sendEventToDart("onAdVideoProgress", i);
            }
          });

          nativeAd.setDislikeCallbackListener(new ATNativeDislikeListener() {
            @Override
            public void onAdCloseButtonClick(ATNativeAdView tuNativeAdView, ATAdInfo tuAdInfo) {
              sendEventToDart("onAdCloseButtonClick", tuAdInfo != null ? tuAdInfo.getPlacementId() : null);
            }
          });

          result.success(adInfo);
        } else {
          result.error("NATIVE_AD_NOT_READY", "Native ad not loaded yet", null);
        }
      } catch (Exception e) {
        Log.e(TAG, "getNativeAdInfo error: " + e.getMessage(), e);
        result.error("GET_INFO_ERROR", e.getMessage(), null);
      }
    });
  }

  private void clickNativeAd(Result result) {
    if (activity != null) {
      activity.runOnUiThread(() -> {
        try {
          boolean clicked = false;
          if (tuNativeCtaView != null) {
            clicked = tuNativeCtaView.performClick();
          }
          if (!clicked && tuNativeAdView != null) {
            clicked = tuNativeAdView.performClick();
          }
          if (!clicked && tuNativeContainer != null) {
            clicked = tuNativeContainer.performClick();
          }

          result.success(clicked);
        } catch (Exception e) {
          Log.e(TAG, "clickNativeAd error: " + e.getMessage(), e);
          result.error("CLICK_ERROR", e.getMessage(), null);
        }
      });
    } else {
      result.success(false);
    }
  }

  private Map<String, Object> buildAdInfo(ATNativeMaterial material) {
    Map<String, Object> adInfo = new HashMap<>();
    adInfo.put("title", material.getTitle());
    adInfo.put("description", material.getDescriptionText());
    adInfo.put("mainImageUrl", material.getMainImageUrl());
    adInfo.put("iconUrl", material.getIconImageUrl());
    adInfo.put("callToAction", material.getCallToActionText());
    adInfo.put("starRating", material.getStarRating());
    adInfo.put("adFrom", material.getAdFrom());
    adInfo.put("adChoiceIconUrl", material.getAdChoiceIconUrl());
    adInfo.put("videoUrl", material.getVideoUrl());
    adInfo.put("appPrice", material.getAppPrice());
    adInfo.put("appCommentNum", material.getAppCommentNum());
    adInfo.put("advertiserName", material.getAdvertiserName());
    adInfo.put("adType", material.getAdType());
    adInfo.put("domain", material.getDomain());
    adInfo.put("warning", material.getWarning());
    adInfo.put("downloadStatus", material.getDownloadStatus());
    adInfo.put("downloadProgress", material.getDownloadProgress());
    return adInfo;
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    activity = null;
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }
}

package com.toponad.topon_ad_plugin;

import android.app.Activity;
import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.text.TextUtils;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.secmtp.sdk.core.api.ATAdInfo;
import com.secmtp.sdk.core.api.AdError;
import com.secmtp.sdk.nativead.api.ATNative;
import com.secmtp.sdk.nativead.api.ATNativeAdView;
import com.secmtp.sdk.nativead.api.ATNativeDislikeListener;
import com.secmtp.sdk.nativead.api.ATNativeEventListener;
import com.secmtp.sdk.nativead.api.ATNativeImageView;
import com.secmtp.sdk.nativead.api.ATNativeMaterial;
import com.secmtp.sdk.nativead.api.ATNativeNetworkListener;
import com.secmtp.sdk.nativead.api.ATNativePrepareInfo;
import com.secmtp.sdk.nativead.api.NativeAd;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

public class ToponNativeAdPlatformView implements PlatformView, MethodChannel.MethodCallHandler {
    private static final String TAG = "ToponNativeAdView";

    private final Context context;
    private final Activity activity;
    private final MethodChannel methodChannel;
    private final FrameLayout rootContainer;
    private ATNativeAdView atNativeAdView;
    private ATNative atNative;
    private NativeAd nativeAd;
    private final String placementId;

    public ToponNativeAdPlatformView(
            @NonNull Context context,
            @Nullable Activity activity,
            @NonNull BinaryMessenger messenger,
            int id,
            @Nullable Map<String, Object> params
    ) {
        this.context = context;
        this.activity = activity;
        this.methodChannel = new MethodChannel(messenger, "topon_native_ad_view_" + id);
        this.methodChannel.setMethodCallHandler(this);

        Context ctx = activity != null ? activity : context;
        this.rootContainer = new FrameLayout(ctx);
        this.rootContainer.setClipChildren(false);
        this.rootContainer.setClipToPadding(false);
        this.rootContainer.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        String pId = "";
        if (params != null && params.containsKey("placementId")) {
            pId = (String) params.get("placementId");
        }
        this.placementId = pId;

        loadAndRenderAd();
    }

    private void safeRemoveFromParent(View view) {
        if (view != null && view.getParent() instanceof ViewGroup) {
            ((ViewGroup) view.getParent()).removeView(view);
        }
    }

    private void measureAndSendHeight(Context ctx) {
        if (atNativeAdView == null) return;
        int h = atNativeAdView.getHeight();
        if (h <= 0 && atNativeAdView.getChildCount() > 0) {
            View child = atNativeAdView.getChildAt(0);
            h = child.getHeight();
            if (h <= 0) {
                int widthPx = rootContainer.getWidth() > 0 ? rootContainer.getWidth() : ctx.getResources().getDisplayMetrics().widthPixels;
                int widthSpec = View.MeasureSpec.makeMeasureSpec(widthPx, View.MeasureSpec.EXACTLY);
                int heightSpec = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED);
                child.measure(widthSpec, heightSpec);
                h = child.getMeasuredHeight();
            }
        }
        if (h > 0) {
            float density = ctx.getResources().getDisplayMetrics().density;
            sendEvent("onAdHeightMeasured", (double) (h / density));
        }
    }

    private void loadAndRenderAd() {
        if (TextUtils.isEmpty(placementId)) {
            Log.e(TAG, "placementId is empty");
            return;
        }

        Activity act = activity;
        Context ctx = act != null ? act : context;

        atNative = new ATNative(ctx, placementId, new ATNativeNetworkListener() {
            @Override
            public void onNativeAdLoaded() {
                Log.d(TAG, "Native ad loaded callback received for: " + placementId);
                if (act != null) {
                    act.runOnUiThread(() -> renderNativeAd());
                } else {
                    rootContainer.post(() -> renderNativeAd());
                }
            }

            @Override
            public void onNativeAdLoadFail(AdError adError) {
                Log.e(TAG, "Native ad load fail: " + (adError != null ? adError.getFullErrorInfo() : "unknown"));
                sendEvent("onAdLoadFailed", adError != null ? adError.getFullErrorInfo() : "load failed");
            }
        });

        // Check if there is already a cached ready ad
        NativeAd readyAd = atNative.getNativeAd();
        if (readyAd != null) {
            this.nativeAd = readyAd;
            renderNativeAd();
        } else {
            atNative.makeAdRequest();
        }
    }

    private void renderNativeAd() {
        try {
            if (nativeAd == null && atNative != null) {
                nativeAd = atNative.getNativeAd();
            }

            if (nativeAd == null) {
                Log.w(TAG, "No native ad available to render");
                return;
            }

            Activity act = activity;
            Context ctx = act != null ? act : context;

            rootContainer.removeAllViews();

            if (atNativeAdView == null) {
                atNativeAdView = new ATNativeAdView(ctx);
            }
            atNativeAdView.removeAllViews();
            atNativeAdView.setClipChildren(false);
            atNativeAdView.setClipToPadding(false);
            atNativeAdView.setLayoutParams(new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
            ));

            // Set native event listeners
            nativeAd.setNativeEventListener(new ATNativeEventListener() {
                @Override
                public void onAdImpressed(ATNativeAdView view, ATAdInfo adInfo) {
                    Log.d(TAG, "onAdImpressed placement: " + (adInfo != null ? adInfo.getPlacementId() : ""));
                    sendEvent("onAdImpressed", adInfo != null ? adInfo.getPlacementId() : null);
                }

                @Override
                public void onAdClicked(ATNativeAdView view, ATAdInfo adInfo) {
                    Log.d(TAG, "onAdClicked placement: " + (adInfo != null ? adInfo.getPlacementId() : ""));
                    sendEvent("onAdClicked", adInfo != null ? adInfo.getPlacementId() : null);
                }

                @Override
                public void onAdVideoStart(ATNativeAdView view) {
                    sendEvent("onAdVideoStart", null);
                }

                @Override
                public void onAdVideoEnd(ATNativeAdView view) {
                    sendEvent("onAdVideoEnd", null);
                }

                @Override
                public void onAdVideoProgress(ATNativeAdView view, int progress) {
                    sendEvent("onAdVideoProgress", progress);
                }
            });

            nativeAd.setDislikeCallbackListener(new ATNativeDislikeListener() {
                @Override
                public void onAdCloseButtonClick(ATNativeAdView view, ATAdInfo adInfo) {
                    rootContainer.setVisibility(View.GONE);
                    sendEvent("onAdClosed", adInfo != null ? adInfo.getPlacementId() : null);
                }
            });

            // 1. Template / Express Rendering
            if (nativeAd.isNativeExpress()) {
                nativeAd.renderAdContainer(atNativeAdView, null);
                nativeAd.prepare(atNativeAdView, null);
            } else {
                // 2. Self-Rendering with 100% Policy Compliance
                buildAndPrepareSelfRenderLayout(ctx, nativeAd);
            }

            safeRemoveFromParent(atNativeAdView);
            rootContainer.addView(atNativeAdView);

            atNativeAdView.post(() -> measureAndSendHeight(ctx));

            atNativeAdView.addOnLayoutChangeListener((v, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> {
                int h = bottom - top;
                int oldH = oldBottom - oldTop;
                if (h > 0 && h != oldH) {
                    float density = ctx.getResources().getDisplayMetrics().density;
                    sendEvent("onAdHeightMeasured", (double) (h / density));
                }
            });

            sendEvent("onAdRenderSuccess", null);

        } catch (Exception e) {
            Log.e(TAG, "Error rendering native ad: " + e.getMessage(), e);
            sendEvent("onAdRenderError", e.getMessage());
        }
    }

    private void buildAndPrepareSelfRenderLayout(Context ctx, NativeAd ad) {
        ATNativeMaterial material = ad.getAdMaterial();
        if (material == null) return;

        int dp4 = dpToPx(ctx, 4);
        int dp6 = dpToPx(ctx, 6);
        int dp8 = dpToPx(ctx, 8);
        int dp10 = dpToPx(ctx, 10);
        int dp38 = dpToPx(ctx, 38);
        int dp110 = dpToPx(ctx, 110);
        int dp36 = dpToPx(ctx, 36);

        // Root Card Layout
        LinearLayout cardLayout = new LinearLayout(ctx);
        cardLayout.setOrientation(LinearLayout.VERTICAL);
        cardLayout.setClipChildren(false);
        cardLayout.setClipToPadding(false);
        cardLayout.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        // Card Styling
        GradientDrawable cardBg = new GradientDrawable();
        cardBg.setColor(Color.WHITE);
        cardBg.setCornerRadius(dpToPx(ctx, 14));
        cardBg.setStroke(dpToPx(ctx, 1.2f), Color.parseColor("#E9D5FF"));
        cardLayout.setBackground(cardBg);
        cardLayout.setPadding(dp8, dp8, dp8, dp8);

        // --- TOP ROW (Icon + Title/Advertiser + Ad Badge + Choice View) ---
        LinearLayout topRow = new LinearLayout(ctx);
        topRow.setOrientation(LinearLayout.HORIZONTAL);
        topRow.setGravity(Gravity.CENTER_VERTICAL);
        topRow.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        // Icon View
        FrameLayout iconContainer = new FrameLayout(ctx);
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(dp38, dp38);
        iconParams.setMarginEnd(dp8);
        iconContainer.setLayoutParams(iconParams);

        GradientDrawable iconBg = new GradientDrawable();
        iconBg.setColor(Color.parseColor("#F3E8FF"));
        iconBg.setCornerRadius(dpToPx(ctx, 10));
        iconContainer.setBackground(iconBg);
        iconContainer.setClipToOutline(true);

        View iconView = null;
        if (material.getAdIconView() != null) {
            iconView = material.getAdIconView();
            safeRemoveFromParent(iconView);
            iconContainer.addView(iconView, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
            ));
        } else if (!TextUtils.isEmpty(material.getIconImageUrl())) {
            ATNativeImageView nativeImageView = new ATNativeImageView(ctx);
            nativeImageView.setScaleType(ImageView.ScaleType.CENTER_CROP);
            nativeImageView.setImage(material.getIconImageUrl());
            iconContainer.addView(nativeImageView, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
            ));
            iconView = nativeImageView;
        }

        topRow.addView(iconContainer);

        // Title + Rating/Advertiser Column
        LinearLayout textCol = new LinearLayout(ctx);
        textCol.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams textColParams = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1.0f
        );
        textCol.setLayoutParams(textColParams);

        TextView titleView = new TextView(ctx);
        titleView.setText(material.getTitle() != null ? material.getTitle() : "Sponsored");
        titleView.setTextColor(Color.parseColor("#1E1B4B"));
        titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        titleView.setTypeface(null, Typeface.BOLD);
        titleView.setSingleLine(true);
        titleView.setEllipsize(TextUtils.TruncateAt.END);
        textCol.addView(titleView);

        String subText = "";
        if (material.getStarRating() != null && material.getStarRating() > 0) {
            subText = "★ " + String.format("%.1f", material.getStarRating());
        }
        if (!TextUtils.isEmpty(material.getAdvertiserName())) {
            if (!subText.isEmpty()) subText += " • ";
            subText += material.getAdvertiserName();
        }
        if (!subText.isEmpty()) {
            TextView subTextView = new TextView(ctx);
            subTextView.setText(subText);
            subTextView.setTextColor(Color.parseColor("#94A3B8"));
            subTextView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f);
            subTextView.setSingleLine(true);
            subTextView.setEllipsize(TextUtils.TruncateAt.END);
            textCol.addView(subTextView);
        }

        topRow.addView(textCol);

        // Right side: "Ad" badge
        LinearLayout badgeCol = new LinearLayout(ctx);
        badgeCol.setOrientation(LinearLayout.HORIZONTAL);
        badgeCol.setGravity(Gravity.CENTER_VERTICAL);
        badgeCol.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        TextView adBadge = new TextView(ctx);
        adBadge.setText("Ad");
        adBadge.setTextColor(Color.parseColor("#7C3AED"));
        adBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f);
        adBadge.setTypeface(null, Typeface.BOLD);
        GradientDrawable adBadgeBg = new GradientDrawable();
        adBadgeBg.setColor(Color.parseColor("#F3E8FF"));
        adBadgeBg.setCornerRadius(dpToPx(ctx, 4));
        adBadgeBg.setStroke(dpToPx(ctx, 0.8f), Color.parseColor("#D8B4FE"));
        adBadge.setBackground(adBadgeBg);
        adBadge.setPadding(dpToPx(ctx, 5), dpToPx(ctx, 2), dpToPx(ctx, 5), dpToPx(ctx, 2));
        badgeCol.addView(adBadge);

        topRow.addView(badgeCol);
        cardLayout.addView(topRow);

        // --- MAIN MEDIA / IMAGE VIEW ---
        FrameLayout mediaContainer = null;
        View mainImageView = null;

        if (material.getAdMediaView() != null) {
            mediaContainer = new FrameLayout(ctx);
            LinearLayout.LayoutParams mediaParams = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, dp110
            );
            mediaParams.setMargins(0, dp6, 0, 0);
            mediaContainer.setLayoutParams(mediaParams);

            GradientDrawable mediaBg = new GradientDrawable();
            mediaBg.setColor(Color.parseColor("#FAF5FF"));
            mediaBg.setCornerRadius(dpToPx(ctx, 10));
            mediaContainer.setBackground(mediaBg);
            mediaContainer.setClipToOutline(true);

            mainImageView = material.getAdMediaView();
            safeRemoveFromParent(mainImageView);
            mediaContainer.addView(mainImageView, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
            ));
            cardLayout.addView(mediaContainer);
        } else if (!TextUtils.isEmpty(material.getMainImageUrl())) {
            mediaContainer = new FrameLayout(ctx);
            LinearLayout.LayoutParams mediaParams = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, dp110
            );
            mediaParams.setMargins(0, dp6, 0, 0);
            mediaContainer.setLayoutParams(mediaParams);

            GradientDrawable mediaBg = new GradientDrawable();
            mediaBg.setColor(Color.parseColor("#FAF5FF"));
            mediaBg.setCornerRadius(dpToPx(ctx, 10));
            mediaContainer.setBackground(mediaBg);
            mediaContainer.setClipToOutline(true);

            ATNativeImageView nativeMainImg = new ATNativeImageView(ctx);
            nativeMainImg.setScaleType(ImageView.ScaleType.CENTER_CROP);
            nativeMainImg.setImage(material.getMainImageUrl());
            mediaContainer.addView(nativeMainImg, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
            ));
            mainImageView = nativeMainImg;
            cardLayout.addView(mediaContainer);
        }

        // --- DESCRIPTION TEXT ---
        TextView descView = null;
        if (!TextUtils.isEmpty(material.getDescriptionText())) {
            descView = new TextView(ctx);
            descView.setText(material.getDescriptionText());
            descView.setTextColor(Color.parseColor("#475569"));
            descView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
            descView.setMaxLines(1);
            descView.setEllipsize(TextUtils.TruncateAt.END);
            LinearLayout.LayoutParams descParams = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
            );
            descParams.setMargins(0, dp4, 0, 0);
            descView.setLayoutParams(descParams);
            cardLayout.addView(descView);
        }

        // --- BIND ALL PREPARE INFO ---
        ATNativePrepareInfo prepareInfo = new ATNativePrepareInfo();

        // Domain / Warning / AdFrom (Compliance for Yandex & others)
        if (!TextUtils.isEmpty(material.getDomain())) {
            TextView domainView = new TextView(ctx);
            domainView.setText(material.getDomain());
            domainView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
            domainView.setTextColor(Color.parseColor("#94A3B8"));
            cardLayout.addView(domainView);
            prepareInfo.setDomainView(domainView);
        }
        if (!TextUtils.isEmpty(material.getWarning())) {
            TextView warningView = new TextView(ctx);
            warningView.setText(material.getWarning());
            warningView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
            warningView.setTextColor(Color.parseColor("#94A3B8"));
            cardLayout.addView(warningView);
            prepareInfo.setWarningView(warningView);
        }
        if (!TextUtils.isEmpty(material.getAdFrom())) {
            TextView adFromView = new TextView(ctx);
            adFromView.setText(material.getAdFrom());
            adFromView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f);
            adFromView.setTextColor(Color.parseColor("#94A3B8"));
            cardLayout.addView(adFromView);
            prepareInfo.setAdFromView(adFromView);
        }

        // --- CALL TO ACTION (CTA) BUTTON (Always at Bottom) ---
        TextView ctaButton = new TextView(ctx);
        String ctaText = material.getCallToActionText();
        ctaButton.setText(!TextUtils.isEmpty(ctaText) ? ctaText : "Open");
        ctaButton.setTextColor(Color.WHITE);
        ctaButton.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        ctaButton.setTypeface(null, Typeface.BOLD);
        ctaButton.setGravity(Gravity.CENTER);

        GradientDrawable ctaBg = new GradientDrawable();
        ctaBg.setColor(Color.parseColor("#7C3AED"));
        ctaBg.setCornerRadius(dpToPx(ctx, 10));
        ctaButton.setBackground(ctaBg);

        LinearLayout.LayoutParams ctaParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp36
        );
        ctaParams.setMargins(0, dp6, 0, 0);
        ctaButton.setLayoutParams(ctaParams);
        cardLayout.addView(ctaButton);

        prepareInfo.setTitleView(titleView);
        if (iconView != null) prepareInfo.setIconView(iconView);
        if (mainImageView != null) prepareInfo.setMainImageView(mainImageView);
        if (descView != null) prepareInfo.setDescView(descView);
        prepareInfo.setCtaView(ctaButton);

        // Choice view params for Google AdChoices (!) & Meta logo
        FrameLayout.LayoutParams choiceParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
        );
        choiceParams.gravity = Gravity.TOP | Gravity.END;
        prepareInfo.setChoiceViewLayoutParams(choiceParams);

        // Register Real Clickable Views (CTA, Title, Media, Icon)
        List<View> clickViews = new ArrayList<>();
        clickViews.add(ctaButton);
        clickViews.add(titleView);
        if (iconContainer != null) clickViews.add(iconContainer);
        if (mediaContainer != null) clickViews.add(mediaContainer);
        prepareInfo.setClickViewList(clickViews);

        // Render & Prepare container
        safeRemoveFromParent(cardLayout);
        ad.renderAdContainer(atNativeAdView, cardLayout);
        ad.prepare(atNativeAdView, prepareInfo);
    }

    private void sendEvent(String method, Object arguments) {
        Activity act = activity;
        if (act != null) {
            act.runOnUiThread(() -> methodChannel.invokeMethod(method, arguments));
        } else {
            rootContainer.post(() -> methodChannel.invokeMethod(method, arguments));
        }
    }

    private int dpToPx(Context context, float dp) {
        return (int) TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                dp,
                context.getResources().getDisplayMetrics()
        );
    }

    @Nullable
    @Override
    public View getView() {
        return rootContainer;
    }

    @Override
    public void dispose() {
        if (atNativeAdView != null) {
            atNativeAdView.removeAllViews();
            atNativeAdView = null;
        }
        if (rootContainer != null) {
            rootContainer.removeAllViews();
        }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if ("reloadAd".equals(call.method)) {
            loadAndRenderAd();
            result.success(true);
        } else {
            result.notImplemented();
        }
    }
}

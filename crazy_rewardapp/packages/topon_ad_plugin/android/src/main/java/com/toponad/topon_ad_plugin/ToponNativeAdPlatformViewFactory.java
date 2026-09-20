package com.toponad.topon_ad_plugin;

import android.app.Activity;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

public class ToponNativeAdPlatformViewFactory extends PlatformViewFactory {
    private final BinaryMessenger messenger;
    private final ActivityProvider activityProvider;

    public interface ActivityProvider {
        Activity getActivity();
    }

    public ToponNativeAdPlatformViewFactory(
            @NonNull BinaryMessenger messenger,
            @NonNull ActivityProvider activityProvider
    ) {
        super(StandardMessageCodec.INSTANCE);
        this.messenger = messenger;
        this.activityProvider = activityProvider;
    }

    @NonNull
    @Override
    @SuppressWarnings("unchecked")
    public PlatformView create(@NonNull Context context, int viewId, @Nullable Object args) {
        Map<String, Object> params = null;
        if (args instanceof Map) {
            params = (Map<String, Object>) args;
        }
        Activity activity = activityProvider != null ? activityProvider.getActivity() : null;
        return new ToponNativeAdPlatformView(context, activity, messenger, viewId, params);
    }
}
